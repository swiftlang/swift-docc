/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
private import Markdown

/// A reference resolver that launches and interactively communicates with another process or service to resolve links.
///
/// If your external reference resolver or an external symbol resolver is implemented in another executable, you can use this object
/// to communicate between DocC and the `docc` executable.
///
/// ## Launching and responding to requests
///
/// When creating an out-of-process resolver using ``init(processLocation:errorOutputHandler:)`` to communicate with another executable;
/// DocC launches your link resolver executable and declares _its_ own ``Capabilities`` as a raw value passed via the `--capabilities` option.
/// Your link resolver executable is expected to respond with a ``ResponseV2/identifierAndCapabilities(_:_:)`` message that declares:
/// - The documentation bundle identifier that the executable can to resolve links for.
/// - The capabilities that the resolver supports.
///
/// After this "handshake" your link resolver executable is expected to wait for ``RequestV2`` messages from DocC and respond with exactly one ``ResponseV2`` per message.
/// A visual representation of this flow of execution can be seen in the diagram below:
///
///         DocC                link resolver executable
///         ┌─┐                              ╎
///         │ ├─────────── Launch ──────────▶┴┐
///         │ │        --capabilities       │ │
///         │ │                             │ │
///         │ ◀───────── Handshake ─────────┤ │
///         │ │  { "identifier"   : ... ,   │ │
///         │ │    "capabilities" : ... }   │ │
///     ┏ loop ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
///     ┃   │ │                             │ │   ┃
///     ┃   │ ├────────── Request ──────────▶ │   ┃
///     ┃   │ │  { "link"   : ... }  OR     │ │   ┃
///     ┃   │ │  { "symbol" : ... }         │ │   ┃
///     ┃   │ │                             │ │   ┃
///     ┃   │ ◀────────── Response ─────────┤ │   ┃
///     ┃   │ │  { "resolved" : ... }  OR   │ │   ┃
///     ┃   │ │  { "failure"  : ... }       │ │   ┃
///     ┃   │ │                             │ │   ┃
///     ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
///         │ │                             └─┘
///         │ │                              ╎
///
/// ## Interacting with a Convert Service
///
/// When creating an out-of-process resolver using ``init(bundleID:server:convertRequestIdentifier:)`` to communicate with another process using a ``ConvertService``;
/// DocC sends that service `"resolve-reference"` messages with a``OutOfProcessReferenceResolver/Request`` payload and expects a `"resolved-reference-response"` responses with a ``OutOfProcessReferenceResolver/Response`` payload.
///
/// Because the ``ConvertService`` messages are _implicitly_ tied to these outdated—and no longer recommended—request and response types, the richness of its responses is limited.
///
/// - Note: when interacting with a ``ConvertService`` your service also needs to handle "asset" requests (``OutOfProcessReferenceResolver/Request/asset(_:)`` and responses that (``OutOfProcessReferenceResolver/Response/asset(_:)``) that link resolver executables don't need to handle.
///
/// ## Topics
///
/// ### Messages
///
/// Requests that DocC sends to your link resolver executable and the responses that it should send back.
///
/// - ``RequestV2``
/// - ``ResponseV2``
///
/// ### Finding common capabilities
///
/// Ways that your link resolver executable can signal any optional capabilities that it supports.
///
/// - ``ResponseV2/identifierAndCapabilities(_:_:)``
/// - ``Capabilities``
///
/// ### Deprecated messages
///
/// - ``Request``
/// - ``Response``
///
/// ## See Also
/// - ``DocumentationContext/externalDocumentationSources``
/// - ``DocumentationContext/globalExternalSymbolResolver``
public class OutOfProcessReferenceResolver: ExternalDocumentationSource, GlobalExternalSymbolResolver {
    private var implementation: any _Implementation
    
    /// The bundle identifier for the reference resolver in the other process.
    public var bundleID: DocumentationBundle.Identifier {
        implementation.bundleID
    }
    
    // This variable is used below for the `ConvertServiceFallbackResolver` conformance.
    private var assetCache: [AssetReference: DataAsset] = [:]
    
    /// Creates a new reference resolver that interacts with another executable.
    ///
    /// Initializing the resolver will also launch the other executable. The other executable will remain running for the lifetime of this object.
    /// This and the rest of the communication between DocC and the link resolver executable is described in <doc:OutOfProcessReferenceResolver#Launching-and-responding-to-requests>
    ///
    /// - Parameters:
    ///   - processLocation: The location of the other executable.
    ///   - errorOutputHandler: A callback to process error messages from the other executable.
    /// - Throws: If the other executable failed to launch.
    public init(processLocation: URL, errorOutputHandler: @escaping (String) -> Void) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: processLocation.path) else {
            throw Error.missingResolverAt(processLocation)
        }
        guard fileManager.isExecutableFile(atPath: processLocation.path) else {
            throw Error.resolverNotExecutable(processLocation)
        }
        
        let longRunningProcess = try LongRunningProcess(location: processLocation, errorOutputHandler: errorOutputHandler)
        
        guard let handshake: InitialHandshakeMessage = try? longRunningProcess.readInitialHandshakeMessage() else {
            throw Error.invalidBundleIdentifierOutputFromExecutable(processLocation)
        }
        
        // This private type and protocol exist to silence deprecation warnings
        self.implementation = (_ImplementationProvider() as (any _ImplementationProviding)).makeImplementation(for: handshake, longRunningProcess: longRunningProcess)
    }
    
    /// Creates a new reference resolver that interacts with a documentation service.
    ///
    /// The documentation service is expected to be able to handle messages of kind "resolve-reference".
    ///
    /// - Parameters:
    ///   - bundleID: The bundle identifier the server can resolve references for.
    ///   - server: The server to send link resolution requests to.
    ///   - convertRequestIdentifier: The identifier that the resolver will use for convert requests that it sends to the server.
    public init(bundleID: DocumentationBundle.Identifier, server: DocumentationServer, convertRequestIdentifier: String?) throws {
        self.implementation = (_ImplementationProvider() as any _ImplementationProviding).makeImplementation(
            for: .init(identifier: bundleID, capabilities: nil /* always use the V1 implementation */),
            longRunningProcess: LongRunningService(server: server, convertRequestIdentifier: convertRequestIdentifier)
        )
    }
    
    fileprivate struct InitialHandshakeMessage: Decodable {
        var identifier: DocumentationBundle.Identifier
        var capabilities: Capabilities? // The old V1 handshake didn't include this but the V2 requires it.
        
        init(identifier: DocumentationBundle.Identifier, capabilities: OutOfProcessReferenceResolver.Capabilities?) {
            self.identifier = identifier
            self.capabilities = capabilities
        }
        
        private enum CodingKeys: CodingKey {
            case bundleIdentifier  // Legacy V1 handshake
            case identifier, capabilities // V2 handshake
        }
        
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            guard container.contains(.identifier) || container.contains(.bundleIdentifier) else {
                throw DecodingError.keyNotFound(CodingKeys.identifier, .init(codingPath: decoder.codingPath, debugDescription: """
                    Initial handshake message includes neither a '\(CodingKeys.identifier.stringValue)' key nor a '\(CodingKeys.bundleIdentifier.stringValue)' key. 
                    """))
            }
            
            self.identifier = try container.decodeIfPresent(DocumentationBundle.Identifier.self, forKey: .identifier)
            ?? container.decode(DocumentationBundle.Identifier.self, forKey: .bundleIdentifier)
            
            self.capabilities = try container.decodeIfPresent(Capabilities.self, forKey: .capabilities)
        }
    }
    
    // MARK: External Reference Resolver
    
    public func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
        implementation.resolve(reference)
    }
    
    @_spi(ExternalLinks)  // LinkResolver.ExternalEntity isn't stable API yet
    public func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
        implementation.entity(with: reference)
    }
    
    @_spi(ExternalLinks)  // LinkResolver.ExternalEntity isn't stable API yet
    public func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
        implementation.symbolReferenceAndEntity(withPreciseIdentifier: preciseIdentifier)
    }
}

// MARK: Implementations

private protocol _Implementation: ExternalDocumentationSource, GlobalExternalSymbolResolver {
    var bundleID: DocumentationBundle.Identifier { get }
    var longRunningProcess: any ExternalLinkResolving { get }
    
    //
    func resolve(unresolvedReference: UnresolvedTopicReference) throws -> TopicReferenceResolutionResult
}

private extension _Implementation {
    // Avoid some common boilerplate between implementations.
    func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
        switch reference {
            case .resolved(let resolved):
                return resolved
                
            case let .unresolved(unresolvedReference):
                guard unresolvedReference.bundleID == bundleID else {
                    fatalError("""
                    Attempted to resolve a local reference externally: \(unresolvedReference.description.singleQuoted).
                    DocC should never pass a reference to an external resolver unless it matches that resolver's bundle identifier.
                    """)
                }
                do {
                    // This is where each implementation differs
                    return try resolve(unresolvedReference: unresolvedReference)
                } catch let error {
                    return .failure(unresolvedReference, TopicReferenceResolutionErrorInfo(error))
                }
        }
    }
}

// This private protocol allows the out-of-process resolver to create ImplementationV1 without deprecation warnings
private protocol _ImplementationProviding {
    func makeImplementation(for handshake: OutOfProcessReferenceResolver.InitialHandshakeMessage, longRunningProcess: any ExternalLinkResolving) -> any _Implementation
}

private extension OutOfProcessReferenceResolver {
    // A concrete type with a deprecated implementation that can be cast to `_ImplementationProviding` to avoid deprecation warnings.
    struct _ImplementationProvider: _ImplementationProviding {
        @available(*, deprecated) // The V1 implementation is built around several now-deprecated types. This deprecation silences those depreciation warnings.
        func makeImplementation(for handshake: OutOfProcessReferenceResolver.InitialHandshakeMessage, longRunningProcess: any ExternalLinkResolving) -> any _Implementation {
            if let capabilities = handshake.capabilities {
                return ImplementationV2(longRunningProcess: longRunningProcess, bundleID: handshake.identifier, executableCapabilities: capabilities)
            } else {
                return ImplementationV1(longRunningProcess: longRunningProcess, bundleID: handshake.identifier)
            }
        }
    }
}

// MARK: Version 1 (deprecated)

extension OutOfProcessReferenceResolver {
    /// The original—no longer recommended—version of the out-of-process resolver implementation.
    ///
    /// This implementation uses ``Request`` and ``Response`` which aren't extensible and have restrictions on the details of the response payloads.
    @available(*, deprecated) // The V1 implementation is built around several now-deprecated types. This deprecation silences those depreciation warnings.
    private final class ImplementationV1: _Implementation {
        let bundleID: DocumentationBundle.Identifier
        let longRunningProcess: any ExternalLinkResolving
        
        init(longRunningProcess: any ExternalLinkResolving, bundleID: DocumentationBundle.Identifier) {
            self.longRunningProcess = longRunningProcess
            self.bundleID = bundleID
        }
        
        // This is fileprivate so that the ConvertService conformance below can access it.
        fileprivate private(set) var referenceCache: [URL: ResolvedInformation] = [:]
        private var symbolCache: [String: ResolvedInformation] = [:]
        
        func resolve(unresolvedReference: UnresolvedTopicReference) throws -> TopicReferenceResolutionResult {
            guard let unresolvedTopicURL = unresolvedReference.topicURL.components.url else {
                // Return the unresolved reference if the underlying URL is not valid
                return .failure(unresolvedReference, TopicReferenceResolutionErrorInfo("URL \(unresolvedReference.topicURL.absoluteString.singleQuoted) is not valid."))
            }
            let resolvedInformation = try resolveInformationForTopicURL(unresolvedTopicURL)
            return .success( resolvedReference(for: resolvedInformation) )
        }
        
        func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
            guard let resolvedInformation = referenceCache[reference.url] else {
                fatalError("A topic reference that has already been resolved should always exist in the cache.")
            }
            return makeEntity(with: resolvedInformation, reference: reference.absoluteString)
        }
        
        func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
            guard let resolvedInformation = try? resolveInformationForSymbolIdentifier(preciseIdentifier) else { return nil }
            
            let reference = ResolvedTopicReference(
                bundleID: "com.externally.resolved.symbol",
                path: "/\(preciseIdentifier)",
                sourceLanguages: sourceLanguages(for: resolvedInformation)
            )
            let entity =  makeEntity(with: resolvedInformation, reference: reference.absoluteString)
            return (reference, entity)
        }
        
        /// Makes a call to the other process to resolve information about a page based on its URL.
        private func resolveInformationForTopicURL(_ topicURL: URL) throws -> ResolvedInformation {
            if let cachedInformation = referenceCache[topicURL] {
                return cachedInformation
            }
            
            let response: Response = try longRunningProcess.sendAndWait(request: Request.topic(topicURL))
            
            switch response {
                case .bundleIdentifier:
                    throw Error.executableSentBundleIdentifierAgain
                    
                case .errorMessage(let errorMessage):
                    throw Error.forwardedErrorFromClient(errorMessage: errorMessage)
                    
                case .resolvedInformation(let resolvedInformation):
                    // Cache the information for the resolved reference, that's what's will be used when returning the entity later.
                    let resolvedReference = resolvedReference(for: resolvedInformation)
                    referenceCache[resolvedReference.url] = resolvedInformation
                    return resolvedInformation
                    
                default:
                    throw Error.unexpectedResponse(response: response, requestDescription: "topic URL")
            }
        }
        
        /// Makes a call to the other process to resolve information about a symbol based on its precise identifier.
        private func resolveInformationForSymbolIdentifier(_ preciseIdentifier: String) throws -> ResolvedInformation {
            if let cachedInformation = symbolCache[preciseIdentifier] {
                return cachedInformation
            }
            
            let response: Response = try longRunningProcess.sendAndWait(request: Request.symbol(preciseIdentifier))
            
            switch response {
                case .bundleIdentifier:
                    throw Error.executableSentBundleIdentifierAgain
                    
                case .errorMessage(let errorMessage):
                    throw Error.forwardedErrorFromClient(errorMessage: errorMessage)
                    
                case .resolvedInformation(let resolvedInformation):
                    symbolCache[preciseIdentifier] = resolvedInformation
                    return resolvedInformation
                    
                default:
                    throw Error.unexpectedResponse(response: response, requestDescription: "symbol ID")
            }
        }
        
        private func resolvedReference(for resolvedInformation: ResolvedInformation) -> ResolvedTopicReference {
            return ResolvedTopicReference(
                bundleID: bundleID,
                path: resolvedInformation.url.path,
                fragment: resolvedInformation.url.fragment,
                sourceLanguages: sourceLanguages(for: resolvedInformation)
            )
        }
        
        private func sourceLanguages(for resolvedInformation: ResolvedInformation) -> Set<SourceLanguage> {
            // It is expected that the available languages contains the main language
            return resolvedInformation.availableLanguages.union(CollectionOfOne(resolvedInformation.language))
        }
        
        private func makeEntity(with resolvedInformation: ResolvedInformation, reference: String) -> LinkResolver.ExternalEntity {
            return LinkResolver.ExternalEntity(
                kind: resolvedInformation.kind,
                language: resolvedInformation.language,
                relativePresentationURL: resolvedInformation.url.withoutHostAndPortAndScheme(),
                referenceURL: URL(string: reference)!,
                title: resolvedInformation.title,
                // The resolved information only stores the plain text abstract and can't be changed. Use the version 2 communication protocol to support rich abstracts.
                abstract: [.text(resolvedInformation.abstract)],
                availableLanguages: resolvedInformation.availableLanguages,
                platforms: resolvedInformation.platforms,
                taskGroups: nil,
                usr: nil,
                declarationFragments: resolvedInformation.declarationFragments?.declarationFragments.map { .init(fragment: $0, identifier: nil) },
                redirects: nil,
                topicImages: resolvedInformation.topicImages,
                references: resolvedInformation.references,
                variants: (resolvedInformation.variants ?? []).map { variant in
                    .init(
                        traits: variant.traits,
                        kind: variant.kind,
                        language: variant.language,
                        relativePresentationURL: variant.url?.withoutHostAndPortAndScheme(),
                        title: variant.title,
                        abstract: variant.abstract.map { [.text($0)] },
                        taskGroups: nil,
                        usr: nil,
                        declarationFragments: variant.declarationFragments.map { fragments in
                            fragments?.declarationFragments.map { .init(fragment: $0, identifier: nil) }
                        }
                    )
                }
            )
        }
    }
}

// MARK: Version 2

extension OutOfProcessReferenceResolver {
    private final class ImplementationV2: _Implementation {
        let longRunningProcess: any ExternalLinkResolving
        let bundleID: DocumentationBundle.Identifier
        let executableCapabilities: Capabilities
        
        init(
            longRunningProcess: any ExternalLinkResolving,
            bundleID: DocumentationBundle.Identifier,
            executableCapabilities: Capabilities
        ) {
            self.longRunningProcess = longRunningProcess
            self.bundleID = bundleID
            self.executableCapabilities = executableCapabilities
        }
        
        private var linkCache: [String /* either a USR or an absolute UnresolvedTopicReference */: LinkDestinationSummary] = [:]
        
        func resolve(unresolvedReference: UnresolvedTopicReference) throws -> TopicReferenceResolutionResult {
            let unresolvedReferenceString = unresolvedReference.topicURL.absoluteString
            if let cachedSummary = linkCache[unresolvedReferenceString] {
                return .success( makeReference(for: cachedSummary) )
            }
            
            let linkString = String(
                unresolvedReferenceString.dropFirst(6) // "doc://"
                    .drop(while: { $0 != "/" })        // the known identifier (host component)
            )
            let response: ResponseV2 = try longRunningProcess.sendAndWait(request: RequestV2.link(linkString))
            
            switch response {
                case .identifierAndCapabilities:
                    throw Error.executableSentBundleIdentifierAgain
                    
                case .failure(let diagnosticMessage):
                    let prefixLength = 2 /* for "//" */ + bundleID.rawValue.utf8.count
                    let solutions: [Solution] = (diagnosticMessage.solutions ?? []).map {
                        Solution(summary: $0.summary, replacements: $0.replacement.map { replacement in
                            [Replacement(
                                // The replacement ranges are relative to the link itself.
                                // To replace only the path and fragment portion of the link, we create a range from 0 to the relative link string length, both offset by the bundle ID length
                                range: SourceLocation(line: 0, column: prefixLength, source: nil) ..< SourceLocation(line: 0, column: linkString.utf8.count + prefixLength, source: nil),
                                replacement: replacement
                            )]
                        } ?? [])
                    }
                    return .failure(
                        unresolvedReference,
                        TopicReferenceResolutionErrorInfo(diagnosticMessage.summary, solutions: solutions)
                    )
                    
                case .resolved(let linkSummary):
                    // Cache the information for the original authored link
                    linkCache[unresolvedReferenceString] = linkSummary
                    // Cache the information for the resolved reference. That's what's will be used when returning the entity later.
                    let reference = makeReference(for: linkSummary)
                    linkCache[reference.absoluteString] = linkSummary
                    if let usr = linkSummary.usr {
                        // If the page is a symbol, cache its information for the USR as well.
                        linkCache[usr] = linkSummary
                    }
                    return .success(reference)
                    
                default:
                    throw Error.unexpectedResponse(response: response, requestDescription: "topic link")
            }
        }
        
        func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
            guard let linkSummary = linkCache[reference.url.standardized.absoluteString] else {
                fatalError("A topic reference that has already been resolved should always exist in the cache.")
            }
            return linkSummary
        }
        
        func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
            if let cachedSummary = linkCache[preciseIdentifier] {
                return (makeReference(for: cachedSummary), cachedSummary)
            }
            
            guard case ResponseV2.resolved(let linkSummary)? = try? longRunningProcess.sendAndWait(request: RequestV2.symbol(preciseIdentifier)) else {
                return nil
            }
            
            // Cache the information for the USR
            linkCache[preciseIdentifier] = linkSummary
            
            // Cache the information for the resolved reference.
            let reference = makeReference(for: linkSummary)
            linkCache[reference.absoluteString] = linkSummary
            
            return (reference, linkSummary)
        }
        
        private func makeReference(for linkSummary: LinkDestinationSummary) -> ResolvedTopicReference {
            ResolvedTopicReference(
                bundleID: linkSummary.referenceURL.host.map { .init(rawValue: $0) } ?? "unknown",
                path: linkSummary.referenceURL.path,
                fragment: linkSummary.referenceURL.fragment,
                sourceLanguages: linkSummary.availableLanguages
            )
        }
    }
}

// MARK: Cross process communication

private protocol ExternalLinkResolving {
    func sendAndWait<Request: Codable, Response: Codable>(request: Request) throws -> Response
}

private class LongRunningService: ExternalLinkResolving {
    var client: ExternalReferenceResolverServiceClient
    
    init(server: DocumentationServer, convertRequestIdentifier: String?) {
        self.client = ExternalReferenceResolverServiceClient(
            server: server, convertRequestIdentifier: convertRequestIdentifier)
    }
    
    func sendAndWait<Request: Codable, Response: Codable>(request: Request) throws -> Response {
        let responseData = try client.sendAndWait(request)
        return try JSONDecoder().decode(Response.self, from: responseData)
    }
}

/// An object sends codable requests to another process and reads codable responses.
///
/// This private class is only used by the ``OutOfProcessReferenceResolver`` and shouldn't be used for general communication with other processes.
private class LongRunningProcess: ExternalLinkResolving {
    
    #if os(macOS) || os(Linux) || os(Android) || os(FreeBSD) || os(OpenBSD)
    private let process: Process
    
    init(location: URL, errorOutputHandler: @escaping (String) -> Void) throws {
        let process = Process()
        process.executableURL = location
        process.arguments = ["--capabilities", "\(OutOfProcessReferenceResolver.Capabilities().rawValue)"]
        
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errorOutput
        
        try process.run()
        
        let errorReadSource = DispatchSource.makeReadSource(fileDescriptor: errorOutput.fileHandleForReading.fileDescriptor, queue: .main)
        errorReadSource.setEventHandler { [errorOutput] in
            let data = errorOutput.fileHandleForReading.availableData
            let errorMessage = String(data: data, encoding: .utf8)
            ?? "<\(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .memory)) of non-utf8 data>"
            
            errorOutputHandler(errorMessage)
        }
        errorReadSource.resume()
        self.errorReadSource = errorReadSource
        
        self.process = process
    }
    deinit {
        process.terminate()
        errorReadSource.cancel()
    }
    
    private let input = Pipe()
    private let output = Pipe()
    private let errorOutput = Pipe()
    private let errorReadSource: any DispatchSourceRead
    
    func readInitialHandshakeMessage<Response: Decodable>() throws -> Response {
        return try _readResponse()
    }
    
    func sendAndWait<Request: Codable, Response: Codable>(request: Request) throws -> Response {
        // Send
        guard let requestString = String(data: try JSONEncoder().encode(request), encoding: .utf8)?.appending("\n"),
              let requestData = requestString.data(using: .utf8)
        else {
            throw OutOfProcessReferenceResolver.Error.unableToEncodeRequestToClient(requestDescription: "\(request)")
        }
        input.fileHandleForWriting.write(requestData)
        
        // Receive
        return try _readResponse()
    }
    
    private func _readResponse<Response: Decodable>() throws -> Response {
        var response = output.fileHandleForReading.availableData
        guard !response.isEmpty else {
            throw OutOfProcessReferenceResolver.Error.processDidExit(code: Int(process.terminationStatus))
        }
        
        // It's not guaranteed that the full response will be available all at once.
        while true {
            // If a pipe is empty, checking `availableData` will block until there is new data to read.
            do {
                // To avoid blocking forever we check if the response can be decoded after each chunk of data.
                return try JSONDecoder().decode(Response.self, from: response)
            } catch {
                if case DecodingError.dataCorrupted = error,    // If the data wasn't valid JSON, read more data and try to decode it again.
                   response.count.isMultiple(of: Int(PIPE_BUF)) // To reduce the risk of deadlocking, check that bytes so far is a multiple of the pipe buffer size.
                {
                    let moreResponseData = output.fileHandleForReading.availableData
                    guard !moreResponseData.isEmpty else {
                        throw OutOfProcessReferenceResolver.Error.processDidExit(code: Int(process.terminationStatus))
                    }
                    response += moreResponseData
                    continue
                }
                
                // Other errors are re-thrown as wrapped errors.
                throw OutOfProcessReferenceResolver.Error.unableToDecodeResponseFromClient(response, error)
            }
        }
    }
    
    #else
        
    init(location: URL, errorOutputHandler: @escaping (String) -> Void) {
        fatalError("Cannot initialize an out of process resolver outside of macOS or Linux platforms.")
    }
    
    func readInitialHandshakeMessage<Response: Decodable>() throws -> Response {
        fatalError("Cannot call sendAndWait in non macOS/Linux platform.")
    }
    
    func sendAndWait<Request: Codable, Response: Codable>(request: Request) throws -> Response {
        fatalError("Cannot call sendAndWait in non macOS/Linux platform.")
    }
    
    #endif
}

// MARK: Error

extension OutOfProcessReferenceResolver {
    /// Errors that may occur when communicating with an external reference resolver.
    enum Error: Swift.Error, DescribedError {
        // Setup
        
        /// No file exists at the specified location.
        case missingResolverAt(URL)
        /// The file at the specified location is not an executable.
        case resolverNotExecutable(URL)
        /// The other process exited unexpectedly while docc was still running.
        case processDidExit(code: Int)
        /// The other process didn't send a bundle identifier as its first message.
        case invalidBundleIdentifierOutputFromExecutable(URL)
        
        // Loop
        
        /// The other process sent a bundle identifier again, after it was already received.
        case executableSentBundleIdentifierAgain
        /// A wrapped error message from the external link resolver.
        case forwardedErrorFromClient(errorMessage: String)
        /// Unable to determine the kind of message received.
        case invalidResponseKindFromClient
        /// Unable to decode the response from external reference resolver.
        case unableToDecodeResponseFromClient(Data, any Swift.Error)
        /// Unable to encode the request to send to the external reference resolver.
        case unableToEncodeRequestToClient(requestDescription: String)
        /// The request type was not known (neither 'topic' nor 'symbol').
        case unknownTypeOfRequest
        /// Received an unknown type of response to sent request.
        case unexpectedResponse(response: Any, requestDescription: String)
        
        /// A plain text representation of the error message.
        var errorDescription: String {
            switch self {
            // Setup
            case .missingResolverAt(let url):
                return "No file exist at '\(url.path)'."
            case .resolverNotExecutable(let url):
                return "File at at '\(url.path)' is not executable."
            case .processDidExit(let code):
                return "Link resolver process did exit unexpectedly while docc was still running. Exit code '\(code)'."
            case .invalidBundleIdentifierOutputFromExecutable(let resolverLocation):
                return "Expected bundle identifier output from '\(resolverLocation.lastPathComponent)'."
            // Loop
            case .executableSentBundleIdentifierAgain:
                return "Executable sent bundle identifier message again, after it was already received."
            case .forwardedErrorFromClient(let errorMessage):
                return errorMessage
            case .invalidResponseKindFromClient:
                return "Unable to determine message. Expected either 'bundleIdentifier', 'errorMessage', 'resolvedInformation', or 'resolvedSymbolInformationResponse'."
            case .unableToDecodeResponseFromClient(let response, let error):
                let responseString = String(data: response, encoding: .utf8) ?? "<non uft-8 data>"
                return "Unable to decode response:\n\(responseString)\nError: \(error)"
            case .unableToEncodeRequestToClient(let requestDescription):
                return "Unable to encode request for \(requestDescription)."
            case .unknownTypeOfRequest:
                return "Unable to decode request. Type of request is unknown (neither 'topic' nor 'symbol')."
            case .unexpectedResponse(let response, let requestDescription):
                return "Received unexpected response '\(response)' for request: \(requestDescription)."
            }
        }
    }
}

// MARK: Convert Service

extension OutOfProcessReferenceResolver: ConvertServiceFallbackResolver {
    @_spi(ExternalLinks)
    @available(*, deprecated, message: "The ConvertService is implicitly reliant on the deprecated `Request` and `Response` types.")
    public func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity? {
        guard let implementation = implementation as? ImplementationV1 else {
            assertionFailure("ConvertServiceFallbackResolver expects V1 requests and responses")
            return nil
        }
        
        guard implementation.referenceCache.keys.contains(reference.url) else { return nil }
        
        var entity = entity(with: reference)
        // The entity response doesn't include the assets that it references.
        // Before returning the entity, make sure that its references assets are included among the image dependencies.
        var references = entity.references ?? []
        
        for image in entity.topicImages ?? [] {
            if let asset = resolve(assetNamed: image.identifier.identifier) {
                references.append(ImageReference(identifier: image.identifier, imageAsset: asset))
            }
        }
        if !references.isEmpty {
            entity.references = references
        }
        
        return entity
    }
    
    @available(*, deprecated, message: "The ConvertService is implicitly reliant on the deprecated `Request` and `Response` types.")
    func resolve(assetNamed assetName: String) -> DataAsset? {
        let assetReference = AssetReference(assetName: assetName, bundleID: bundleID)
        if let asset = assetCache[assetReference] {
            return asset
        }
        
        guard case .asset(let asset)? = try? implementation.longRunningProcess.sendAndWait(request: Request.asset(assetReference)) as Response else {
            return nil
        }
        return asset
    }
}
