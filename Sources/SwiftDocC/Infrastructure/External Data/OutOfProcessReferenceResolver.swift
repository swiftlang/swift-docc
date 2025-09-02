/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// A reference resolver that launches and interactively communicates with another process or service to resolve links.
///
/// If your external reference resolver or an external symbol resolver is implemented in another executable, you can use this object
/// to communicate between DocC and the `docc` executable.
///
/// The launched executable is expected to follow the flow outlined below, sending ``OutOfProcessReferenceResolver/Request``
/// and ``OutOfProcessReferenceResolver/Response`` values back and forth:
///
///               │
///      1        ▼
///     ┌──────────────────┐
///     │ Output bundle ID │
///     └──────────────────┘
///               │
///      2        ▼
///     ┌──────────────────┐
///     │  Wait for input  │◀───┐
///     └──────────────────┘    │
///               │             │
///      3        ▼             │ repeat
///     ┌──────────────────┐    │
///     │ Output resolved  │    │
///     │   information    │────┘
///     └──────────────────┘
///
/// When resolving against a server, the server is expected to be able to handle messages of type "resolve-reference" with a
/// ``OutOfProcessReferenceResolver/Request`` payload and respond with messages of type "resolved-reference-response"
/// with a ``OutOfProcessReferenceResolver/Response`` payload.
///
/// ## See Also
/// - ``ExternalDocumentationSource``
/// - ``GlobalExternalSymbolResolver``
/// - ``DocumentationContext/externalDocumentationSources``
/// - ``DocumentationContext/globalExternalSymbolResolver``
/// - ``Request``
/// - ``Response``
public class OutOfProcessReferenceResolver: ExternalDocumentationSource, GlobalExternalSymbolResolver {
    private let externalLinkResolvingClient: any ExternalLinkResolving
    
    /// The bundle identifier for the reference resolver in the other process.
    public let bundleID: DocumentationBundle.Identifier
    
    /// Creates a new reference resolver that interacts with another executable.
    ///
    /// Initializing the resolver will also launch the other executable. The other executable will remain running for the lifetime of this object.
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
        
        guard case let .bundleIdentifier(decodedBundleIdentifier) = try longRunningProcess.sendAndWait(request: nil as Request?) as Response else {
            throw Error.invalidBundleIdentifierOutputFromExecutable(processLocation)
        }
        
        self.bundleID = .init(rawValue: decodedBundleIdentifier)
        self.externalLinkResolvingClient = longRunningProcess
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
        self.bundleID = bundleID
        self.externalLinkResolvingClient = LongRunningService(
            server: server, convertRequestIdentifier: convertRequestIdentifier)
    }
    
    // MARK: External Reference Resolver
    
    public func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
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
                guard let unresolvedTopicURL = unresolvedReference.topicURL.components.url else {
                    // Return the unresolved reference if the underlying URL is not valid
                    return .failure(unresolvedReference, TopicReferenceResolutionErrorInfo("URL \(unresolvedReference.topicURL.absoluteString.singleQuoted) is not valid."))
                }
                let resolvedInformation = try resolveInformationForTopicURL(unresolvedTopicURL)
                return .success( resolvedReference(for: resolvedInformation) )
            } catch let error {
                return .failure(unresolvedReference, TopicReferenceResolutionErrorInfo(error))
            }
        }
    }
    
    @_spi(ExternalLinks)  // LinkResolver.ExternalEntity isn't stable API yet
    public func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
        guard let resolvedInformation = referenceCache[reference.url] else {
            fatalError("A topic reference that has already been resolved should always exist in the cache.")
        }
        return makeEntity(with: resolvedInformation, reference: reference.absoluteString)
    }
    
    @_spi(ExternalLinks)  // LinkResolver.ExternalEntity isn't stable API yet
    public func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
        guard let resolvedInformation = try? resolveInformationForSymbolIdentifier(preciseIdentifier) else { return nil }
        
        let reference = ResolvedTopicReference(
            bundleID: "com.externally.resolved.symbol",
            path: "/\(preciseIdentifier)",
            sourceLanguages: sourceLanguages(for: resolvedInformation)
        )
        let entity =  makeEntity(with: resolvedInformation, reference: reference.absoluteString)
        return (reference, entity)
    }
    
    private func makeEntity(with resolvedInformation: ResolvedInformation, reference: String) -> LinkResolver.ExternalEntity {
        let (kind, role) = DocumentationContentRenderer.renderKindAndRole(resolvedInformation.kind, semantic: nil)
        
        var renderReference = TopicRenderReference(
            identifier: .init(reference),
            title: resolvedInformation.title,
            // The resolved information only stores the plain text abstract https://github.com/swiftlang/swift-docc/issues/802
            abstract: [.text(resolvedInformation.abstract)],
            url: resolvedInformation.url.path,
            kind: kind,
            role: role,
            fragments: resolvedInformation.declarationFragments?.declarationFragments.map { DeclarationRenderSection.Token(fragment: $0, identifier: nil) },
            isBeta: resolvedInformation.isBeta,
            isDeprecated: (resolvedInformation.platforms ?? []).contains(where: { $0.deprecated != nil }),
            images: resolvedInformation.topicImages ?? []
        )
        for variant in resolvedInformation.variants ?? [] {
            if let title = variant.title {
                renderReference.titleVariants.variants.append(
                    .init(traits: variant.traits, patch: [.replace(value: title)])
                )
            }
            if let abstract = variant.abstract {
                renderReference.abstractVariants.variants.append(
                    .init(traits: variant.traits, patch: [.replace(value: [.text(abstract)])])
                )
            }
            if let declarationFragments = variant.declarationFragments {
                renderReference.fragmentsVariants.variants.append(
                    .init(traits: variant.traits, patch: [.replace(value: declarationFragments?.declarationFragments.map { DeclarationRenderSection.Token(fragment: $0, identifier: nil) })])
                )
            }
        }
        let dependencies = RenderReferenceDependencies(
            topicReferences: [],
            linkReferences: (resolvedInformation.references ?? []).compactMap { $0 as? LinkReference },
            imageReferences: (resolvedInformation.references ?? []).compactMap { $0 as? ImageReference }
        )
        
        return LinkResolver.ExternalEntity(
            topicRenderReference: renderReference,
            renderReferenceDependencies: dependencies,
            sourceLanguages: resolvedInformation.availableLanguages,
            symbolKind: DocumentationNode.symbolKind(for: resolvedInformation.kind)
        )
    }
    
    // MARK: Implementation
    
    private var referenceCache: [URL: ResolvedInformation] = [:]
    private var symbolCache: [String: ResolvedInformation] = [:]
    private var assetCache: [AssetReference: DataAsset] = [:]
    
    /// Makes a call to the other process to resolve information about a page based on its URL.
    func resolveInformationForTopicURL(_ topicURL: URL) throws -> ResolvedInformation {
        if let cachedInformation = referenceCache[topicURL] {
            return cachedInformation
        }
        
        let response: Response = try externalLinkResolvingClient.sendAndWait(request: Request.topic(topicURL))
        
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
        
        let response: Response = try externalLinkResolvingClient.sendAndWait(request: Request.symbol(preciseIdentifier))
        
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
}

private protocol ExternalLinkResolving {
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response
}

private class LongRunningService: ExternalLinkResolving {
    var client: ExternalReferenceResolverServiceClient
    
    init(server: DocumentationServer, convertRequestIdentifier: String?) {
        self.client = ExternalReferenceResolverServiceClient(
            server: server, convertRequestIdentifier: convertRequestIdentifier)
    }
    
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response {
        let responseData = try client.sendAndWait(request)
        return try JSONDecoder().decode(Response.self, from: responseData)
    }
}

/// An object sends codable requests to another process and reads codable responses.
///
/// This private class is only used by the ``OutOfProcessReferenceResolver`` and shouldn't be used for general communication with other processes.
private class LongRunningProcess: ExternalLinkResolving {
    
    #if os(macOS) || os(Linux) || os(Android) || os(FreeBSD)
    private let process: Process
    
    init(location: URL, errorOutputHandler: @escaping (String) -> Void) throws {
        let process = Process()
        process.executableURL = location
        
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
        
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response {
        if let request {
            guard let requestString = String(data: try JSONEncoder().encode(request), encoding: .utf8)?.appending("\n"),
                  let requestData = requestString.data(using: .utf8)
            else {
                throw OutOfProcessReferenceResolver.Error.unableToEncodeRequestToClient(requestDescription: request.description)
            }
            input.fileHandleForWriting.write(requestData)
        }
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
                if case DecodingError.dataCorrupted = error,     // If the data wasn't valid JSON, read more data and try to decode it again.
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
    
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response {
        fatalError("Cannot call sendAndWait in non macOS/Linux platform.")
    }
    
    #endif
}

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
        case unexpectedResponse(response: Response, requestDescription: String)
        
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
    public func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity? {
        guard referenceCache.keys.contains(reference.url) else { return nil }
        
        var entity = entity(with: reference)
        // The entity response doesn't include the assets that it references.
        // Before returning the entity, make sure that its references assets are included among the image dependencies.
        for image in entity.topicRenderReference.images {
            if let asset = resolve(assetNamed: image.identifier.identifier) {
                entity.renderReferenceDependencies.imageReferences.append(ImageReference(identifier: image.identifier, imageAsset: asset))
            }
        }
        return entity
    }
    
    func resolve(assetNamed assetName: String) -> DataAsset? {
        return try? resolveInformationForAsset(named: assetName)
    }
    
    func resolveInformationForAsset(named assetName: String) throws -> DataAsset {
        let assetReference = AssetReference(assetName: assetName, bundleID: bundleID)
        if let asset = assetCache[assetReference] {
            return asset
        }
        
        let response = try externalLinkResolvingClient.sendAndWait(
            request: Request.asset(AssetReference(assetName: assetName, bundleID: bundleID))
        ) as Response
        
        switch response {
        case .asset(let asset):
            assetCache[assetReference] = asset
            return asset
        case .errorMessage(let errorMessage):
            throw Error.forwardedErrorFromClient(errorMessage: errorMessage)
        default:
            throw Error.unexpectedResponse(response: response, requestDescription: "asset")
        }
    }
}
