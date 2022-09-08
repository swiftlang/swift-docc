/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

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
/// - ``DocumentationContext/externalReferenceResolvers``
/// - ``DocumentationContext/fallbackReferenceResolvers``
/// - ``DocumentationContext/externalSymbolResolver``
/// - ``Request``
/// - ``Response``
public class OutOfProcessReferenceResolver: ExternalReferenceResolver, FallbackReferenceResolver, ExternalSymbolResolver, FallbackAssetResolver {
    
    private let externalLinkResolvingClient: ExternalLinkResolving
    
    /// The bundle identifier for the reference resolver in the other process.
    public let bundleIdentifier: String
    /// The bundle identifier to use for symbol references.
    ///
    ///
    private let symbolBundleIdentifier = "com.externally.resolved.symbol"
    
    /// Creates a new reference resolver that interacts with another executable.
    ///
    /// Initializing the resolver will also launch the other executable. The other executable will remain running for the lifetime of this object.
    ///
    /// - Parameters:
    ///   - processLocation: The location of the other executable.
    ///   - errorOutputHandler: A callback to process error messages from the other executable.
    /// - Throws:
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
        
        self.bundleIdentifier = decodedBundleIdentifier
        self.externalLinkResolvingClient = longRunningProcess
    }

    /// Creates a new reference resolver that interacts with a documentation service.
    ///
    /// The documentation service is expected to be able to handle messages of kind "resolve-reference".
    ///
    /// - Parameters:
    ///   - bundleIdentifier: The bundle identifier the server can resolve references for.
    ///   - server: The server to send link resolution requests to.
    public init(bundleIdentifier: String, server: DocumentationServer, convertRequestIdentifier: String?) throws {
        self.bundleIdentifier = bundleIdentifier
        self.externalLinkResolvingClient = LongRunningService(
            server: server, convertRequestIdentifier: convertRequestIdentifier)
    }
    
    // MARK: External Reference Resolver
    
    /// Attempts to resolve an unresolved reference using a reference resolver in another process.
    ///
    /// - Note: The other reference resolver methods expect to only be passed resolved references that are returned from this method.
    ///
    /// - Parameters:
    ///   - reference: The unresolved reference.
    ///   - sourceLanguage: The source language of the reference (in case the reference exists in multiple languages)
    /// - Returns: The resolved reference for the topic, or information about why the other process failed to resolve the reference.
    public func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
        switch reference {
        case .resolved(let resolved):
            return resolved
            
        case let .unresolved(unresolvedReference):
            guard let bundleIdentifier = unresolvedReference.bundleIdentifier else {
                fatalError("""
                    Attempted to resolve a local reference externally: \(unresolvedReference.description.singleQuoted).
                    DocC should never pass a reference to an external resolver unless it matches that resolver's bundle identifier.
                    """)
            }
            do {
                guard let unresolvedTopicURL = unresolvedReference.topicURL.components.url else {
                    // Return the unresolved reference if the underlying URL is not valid
                    return .failure(unresolvedReference, errorMessage: "URL \(unresolvedReference.topicURL.absoluteString.singleQuoted) is not valid.")
                }
                let metadata = try resolveInformationForTopicURL(unresolvedTopicURL)
                // Don't do anything with this URL. The external URL will be resolved during conversion to render nodes
                return .success(
                    ResolvedTopicReference(
                        bundleIdentifier: bundleIdentifier,
                        path: unresolvedReference.path,
                        fragment: unresolvedReference.fragment,
                        sourceLanguages: sourceLanguages(for: metadata)
                    )
                )
            } catch let error {
                return .failure(unresolvedReference, errorMessage: error.localizedDescription)
            }
        }
    }
    
    /// Creates a new documentation node for the external reference by calling a reference resolver in another process.
    ///
    /// - Important: The resolver can only return information about references that it itself resolved. Passing a reference
    ///   that this resolver didn't resolve is considered a programming error and will raise a fatal error.
    ///
    /// - Precondition: The `reference` was previously resolved by this resolver.
    ///
    /// - Parameter reference: The external reference that this resolver previously resolved.
    /// - Returns: A node with the documentation content for the referenced topic.
    public func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
        guard let resolvedInformation = referenceCache[reference.url] else {
            fatalError("A topic reference that has already been resolved should always exist in the cache.")
        }
        
        let maybeSymbol = OutOfProcessReferenceResolver.symbolSemantic(
            kind: resolvedInformation.kind,
            language: resolvedInformation.language,
            title: resolvedInformation.title,
            abstract: resolvedInformation.abstract,
            declarationFragments: resolvedInformation.declarationFragments,
            platforms: resolvedInformation.platforms,
            variants: resolvedInformation.variants
        )
        
        let name: DocumentationNode.Name
        if maybeSymbol != nil {
            name = .symbol(declaration: .init([.plain(resolvedInformation.title)]))
        } else {
            name = .conceptual(title: resolvedInformation.title)
        }
        
        return DocumentationNode(
            reference: reference,
            kind: resolvedInformation.kind,
            sourceLanguage: resolvedInformation.language,
            availableSourceLanguages: sourceLanguages(for: resolvedInformation),
            name: name,
            markup: Document(parsing: resolvedInformation.abstract, options: []),
            semantic: maybeSymbol,
            platformNames: resolvedInformation.platformNames
        )
    }
    
    /// Returns the web URL for the external topic.
    ///
    /// Some links may add query parameters, for example to link to a specific language variant of the topic.
    ///
    /// - Important: The resolver can only return information about references that it itself resolved. Passing a reference
    ///   that this resolver didn't resolve is considered a programming error and will raise a fatal error.
    ///
    /// - Precondition: The `reference` was previously resolved by this resolver.
    ///
    /// - Parameter reference: The external reference that this resolver previously resolved.
    /// - Returns: The web URL for the resolved external reference.
    public func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
        guard let resolvedInformation = referenceCache[reference.url] else {
            fatalError("A topic reference that has already been resolved should always exist in the cache.")
        }
        return resolvedInformation.url
    }
    
    // MARK: Fallback Reference Resolver
    
    public func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) throws -> DocumentationNode? {
        hasResolvedReference(reference) ? try entity(with: reference) : nil
    }
    
    public func urlForResolvedReferenceIfPreviouslyResolved(_ reference: ResolvedTopicReference) -> URL? {
        hasResolvedReference(reference) ? urlForResolvedReference(reference) : nil
    }
    
    private func hasResolvedReference(_ reference: ResolvedTopicReference) -> Bool {
        referenceCache.keys.contains(reference.url)
    }
    
    // MARK: External Symbol Resolver
    
    /// Creates a documentation node with a subset of the documentation content for the external symbol based on its precise identifier.
    ///
    /// The precise identifier is assumed to be valid and to exist since it either comes from a trusted source, like a symbol graph file, or was
    /// returned from the external symbol resolver or an authored symbol reference.
    ///
    /// - Parameter preciseIdentifier: The precise identifier for an external symbol.
    /// - Returns: A sparse documentation node with basic information about the symbol.
    /// - Throws: If no external symbol has this precise identifier.
    public func symbolEntity(withPreciseIdentifier preciseIdentifier: String) throws -> DocumentationNode {
        let resolvedInformation = try resolveInformationForSymbolIdentifier(preciseIdentifier)
        
        // Construct a resolved reference for this symbol. It uses a known bundle identifier and the symbol's precise identifier so that the
        // already resolved information can be looked up when determining the URL for this symbol.
        let reference = ResolvedTopicReference(
            bundleIdentifier: symbolBundleIdentifier,
            path: "/" + preciseIdentifier,
            sourceLanguages: sourceLanguages(for: resolvedInformation)
        )
        
        let symbol = OutOfProcessReferenceResolver.symbolSemantic(
            kind: resolvedInformation.kind,
            language: resolvedInformation.language,
            title: resolvedInformation.title,
            abstract: resolvedInformation.abstract,
            declarationFragments: resolvedInformation.declarationFragments,
            platforms: resolvedInformation.platforms,
            variants: resolvedInformation.variants
        )! // This entity was resolved from a symbol USR and is known to be a symbol.
        
        return DocumentationNode(
            reference: reference,
            kind: resolvedInformation.kind,
            sourceLanguage: resolvedInformation.language,
            availableSourceLanguages: sourceLanguages(for: resolvedInformation),
            name: .symbol(declaration: .init([.plain(resolvedInformation.title)])),
            markup: Document(parsing: resolvedInformation.abstract, options: [.parseBlockDirectives, .parseSymbolLinks]),
            semantic: symbol,
            platformNames: resolvedInformation.platformNames
        )
    }
    
    /// Returns the web URL for the external symbol.
    ///
    /// Some links may add query parameters, for example to link to a specific language variant of the topic.
    ///
    /// - Important: The resolver can only return information about symbol references that it itself resolved. Passing a reference
    ///   that this resolver didn't resolve is considered a programming error and will raise a fatal error.
    ///
    /// - Precondition: The `reference` was previously resolved by this resolver.
    ///
    /// - Parameter reference:The external symbol reference that this resolver previously resolved.
    /// - Returns: The web URL for the resolved external symbol.
    public func urlForResolvedSymbol(reference: ResolvedTopicReference) -> URL? {
        guard reference.bundleIdentifier == symbolBundleIdentifier, let preciseIdentifier = reference.pathComponents.last else {
            return nil
        }
        guard let resolvedInformation = symbolCache[preciseIdentifier] else {
            // Any non-symbol reference would return `nil` above.
            // Any symbol reference would come from a resolved symbol entity, so it will always exist in the cache.
            fatalError("A symbol reference that has already been resolved should always exist in the cache.")
        }
        return resolvedInformation.url
    }
    
    /// Attempts to find the precise identifier for an authored symbol reference.
    ///
    /// The symbol resolver assumes that the precise identifier is valid and exist when creating a symbol node. You should pass authored
    /// symbol references to this method to check if they exist before creating a documentation node for that symbol.
    ///
    /// - Parameter reference: An authored reference to an external symbol.
    /// - Returns: The precise identifier of the referenced symbol, or `nil` if the reference is not for a resolved external symbol.
    public func preciseIdentifier(forExternalSymbolReference reference: TopicReference) -> String? {
        let url: URL
        switch reference {
        case .unresolved(let unresolved), .resolved(.failure(let unresolved, _)):
            guard unresolved.bundleIdentifier == symbolBundleIdentifier else { return nil }
            url = unresolved.topicURL.url
        case .resolved(.success(let resolved)):
            guard resolved.bundleIdentifier == symbolBundleIdentifier else { return nil }
            url = resolved.url
        }
        
        return url.pathComponents.last
    }
    
    // MARK: Fallback Asset Resolver
    
    public func resolve(assetNamed assetName: String, bundleIdentifier: String) -> DataAsset? {
        do {
            return try resolveInformationForAsset(named: assetName, bundleIdentifier: bundleIdentifier)
        } catch {
            return nil
        }
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
             referenceCache[topicURL] = resolvedInformation
             return resolvedInformation
            
        default:
            throw Error.unexpectedResponse(response: response, requestDescription: "topic URL")
        }
    }
    
    /// Makes a call to the other process to resolve information about a symbol based on its precise identifier.
    func resolveInformationForSymbolIdentifier(_ preciseIdentifier: String) throws -> ResolvedInformation {
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
            throw Error.unexpectedResponse(response: response, requestDescription: "topic URL")
        }
    }
    
    func resolveInformationForAsset(named assetName: String, bundleIdentifier: String) throws -> DataAsset {
        let assetReference = AssetReference(assetName: assetName, bundleIdentifier: bundleIdentifier)
        if let asset = assetCache[assetReference] {
            return asset
        }
        
        let response = try externalLinkResolvingClient.sendAndWait(
            request: Request.asset(
                AssetReference(assetName: assetName, bundleIdentifier: bundleIdentifier)
            )
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
    
    private func sourceLanguages(for resolvedInformation: ResolvedInformation) -> Set<SourceLanguage> {
        if !resolvedInformation.availableLanguages.isEmpty {
            return resolvedInformation.availableLanguages
        }
        
        // Fall back to the `language` property if `availableLanguages` is empty.
        return [resolvedInformation.language]
    }
}

private protocol ExternalLinkResolving {
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response
}

private class LongRunningService: ExternalLinkResolving {
    var client: ExternalReferenceResolverServiceClient
    var convertRequestIdentifier: String?
    
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
    
    #if os(macOS) || os(Linux) || os(Android)
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
    private let errorReadSource: DispatchSourceRead
        
    func sendAndWait<Request: Codable & CustomStringConvertible, Response: Codable>(request: Request?) throws -> Response {
        if let request = request {
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
        case unableToDecodeResponseFromClient(Data, Swift.Error)
        /// Unable to encode the request to send to the external reference resolver.
        case unableToEncodeRequestToClient(requestDescription: String)
        /// The "request" message has an invalid type (neither 'topic' nor 'symbol').
        case unknownTypeOfRequest
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

extension OutOfProcessReferenceResolver {
    
    // MARK: Request & Response
    
    /// A request message to send to the external link resolver.
    ///
    /// This can either be a request to resolve a topic URL or to resolve a symbol based on its precise identifier.
    public enum Request: Codable, CustomStringConvertible {
        /// A request to resolve a topic URL
        case topic(URL)
        /// A request to resolve a symbol based on its precise identifier.
        case symbol(String)
        /// A request to resolve an asset.
        case asset(AssetReference)
        
        private enum CodingKeys: CodingKey {
            case topic
            case symbol
            case asset
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .topic(let url):
                try container.encode(url, forKey: .topic)
            case .symbol(let identifier):
                try container.encode(identifier, forKey: .symbol)
            case .asset(let assetReference):
                try container.encode(assetReference, forKey: .asset)
            }
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch container.allKeys.first {
            case .topic?:
                self = .topic(try container.decode(URL.self, forKey: .topic))
            case .symbol?:
                self = .symbol(try container.decode(String.self, forKey: .symbol))
            case .asset?:
                self = .asset(try container.decode(AssetReference.self, forKey: .asset))
            case nil:
                throw OutOfProcessReferenceResolver.Error.unknownTypeOfRequest
            }
        }
        
        /// A plain text representation of the request message.
        public var description: String {
            switch self {
            case .topic(let url):
                return "topic: \(url.absoluteString.singleQuoted)"
            case .symbol(let identifier):
                return "symbol: \(identifier.singleQuoted)"
            case .asset(let asset):
                return "asset with name: \(asset.assetName), bundle identifier: \(asset.bundleIdentifier)"
            }
        }
    }

    /// A response message from the external link resolver.
    public enum Response: Codable {
        /// A bundle identifier response.
        ///
        /// This message should only be sent once, after the external link resolver has launched.
        case bundleIdentifier(String)
        /// The error message of the problem that the external link resolver encountered while resolving the requested topic or symbol.
        case errorMessage(String)
        /// A response with the resolved information about the requested topic or symbol.
        case resolvedInformation(ResolvedInformation)
        /// A response with information about the resolved asset.
        case asset(DataAsset)
        
        enum CodingKeys: String, CodingKey {
            case bundleIdentifier
            case errorMessage
            case resolvedInformation
            case asset
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            switch container.allKeys.first {
            case .bundleIdentifier?:
                self = .bundleIdentifier(try container.decode(String.self, forKey: .bundleIdentifier))
            case .errorMessage?:
                self = .errorMessage(try container.decode(String.self, forKey: .errorMessage))
            case .resolvedInformation?:
                self = .resolvedInformation(try container.decode(ResolvedInformation.self, forKey: .resolvedInformation))
            case .asset?:
                self = .asset(try container.decode(DataAsset.self, forKey: .asset))
            case nil:
                throw OutOfProcessReferenceResolver.Error.invalidResponseKindFromClient
            }
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .bundleIdentifier(let bundleIdentifier):
                try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
            case .errorMessage(let errorMessage):
                try container.encode(errorMessage, forKey: .errorMessage)
            case .resolvedInformation(let resolvedInformation):
                try container.encode(resolvedInformation, forKey: .resolvedInformation)
            case .asset(let assetReference):
                try container.encode(assetReference, forKey: .asset)
            }
        }
    }
    
    // MARK: Resolved Information
    
    /// A type used to transfer information about a resolved reference to DocC from from a reference resolver in another executable.
    public struct ResolvedInformation: Codable {
        /// Information about the resolved kind.
        public let kind: DocumentationNode.Kind
        /// Information about the resolved URL.
        public let url: URL
        /// Information about the resolved title.
        public let title: String // DocumentationNode.Name
        /// Information about the resolved abstract.
        public let abstract: String // Markup
        /// Information about the resolved language.
        public let language: SourceLanguage
        /// Information about the languages where the resolved node is available.
        public let availableLanguages: Set<SourceLanguage>
        /// Information about the platforms and their versions where the resolved node is available, if any.
        public let platforms: [PlatformAvailability]?
        /// Information about the resolved declaration fragments, if any.
        public let declarationFragments: DeclarationFragments?
        
        // We use the real types here because they're Codable and don't have public member-wise initializers.
        
        /// Platform availability for a resolved symbol reference.
        public typealias PlatformAvailability = AvailabilityRenderItem
        
        /// The declaration fragments for a resolved symbol reference.
        public typealias DeclarationFragments = SymbolGraph.Symbol.DeclarationFragments
        
        /// The platform names, derived from the platform availability.
        public var platformNames: Set<String>? {
            return platforms.map { platforms in Set(platforms.compactMap { $0.name }) }
        }
        
        /// The variants of content (kind, url, title, abstract, language, declaration) for this resolver information.
        public let variants: [Variant]?
        
        /// Creates a new resolved information value with all its values.
        ///
        /// - Parameters:
        ///   - kind: The resolved kind.
        ///   - url: The resolved URL.
        ///   - title: The resolved title
        ///   - abstract: The resolved (plain text) abstract.
        ///   - language: The resolved language.
        ///   - availableLanguages: The languages where the resolved node is available.
        ///   - platforms: The platforms and their versions where the resolved node is available, if any.
        ///   - declarationFragments: The resolved declaration fragments, if any.
        ///   - variants: The variants of content for this resolver information.
        public init(
            kind: DocumentationNode.Kind,
            url: URL,
            title: String,
            abstract: String,
            language: SourceLanguage,
            availableLanguages: Set<SourceLanguage>,
            platforms: [PlatformAvailability]?,
            declarationFragments: DeclarationFragments?,
            variants: [Variant]? = nil
        ) {
            self.kind = kind
            self.url = url
            self.title = title
            self.abstract = abstract
            self.language = language
            self.availableLanguages = availableLanguages
            self.platforms = platforms
            self.declarationFragments = declarationFragments
            self.variants = variants
        }
        
        /// A variant of content for the resolved information.
        ///
        /// - Note: All properties except for ``traits`` are optional. If a property is `nil` it means that the value is the same as the resolved information's value.
        public struct Variant: Codable {
            /// The traits of the variant.
            public let traits: [RenderNode.Variant.Trait]
            
            /// A wrapper for variant values that can either be specified, meaning the variant has a custom value, or not, meaning the variant has the same value as the resolved information.
            ///
            /// This alias is used to make the property declarations more explicit while at the same time offering the convenient syntax of optionals.
            public typealias VariantValue = Optional
            
            /// The kind of the variant or `nil` if the kind is the same as the resolved information.
            public let kind: VariantValue<DocumentationNode.Kind>
            /// The url of the variant or `nil` if the url is the same as the resolved information.
            public let url: VariantValue<URL>
            /// The title of the variant or `nil` if the title is the same as the resolved information.
            public let title: VariantValue<String>
            /// The abstract of the variant or `nil` if the abstract is the same as the resolved information.
            public let abstract: VariantValue<String>
            /// The language of the variant or `nil` if the language is the same as the resolved information.
            public let language: VariantValue<SourceLanguage>
            /// The declaration fragments of the variant or `nil` if the declaration is the same as the resolved information.
            ///
            /// If the resolver information has a declaration but the variant doesn't, this property will be `Optional.some(nil)`.
            public let declarationFragments: VariantValue<DeclarationFragments?>
        }
    }
    
    /// Creates a new symbol semantic from the resolved kind, title, declaration, and platform information, iff the kind is a symbol.
    ///
    /// - Parameters:
    ///   - kind: The kind of the resolved node.
    ///   - language: The source language for the resolved node.
    ///   - title: The title of the resolved node.
    ///   - abstract: The abstract of the resolved node.
    ///   - declarationFragments: The declaration fragments, if any, from the resolved node.
    ///   - platforms: The platform availability information, if any, from the resolved node.
    ///   - variants: The content variants for the resolved node.
    /// - Returns: A new symbol semantic, or `nil` if the kind is not a symbol.
    private static func symbolSemantic(
        kind: DocumentationNode.Kind,
        language: SourceLanguage,
        title: String,
        abstract: String?,
        declarationFragments: ResolvedInformation.DeclarationFragments?,
        platforms: [ResolvedInformation.PlatformAvailability]?,
        variants: [ResolvedInformation.Variant]?
    ) -> Symbol? {
        guard kind.isSymbol else {
            return nil
        }
        
        // The symbol semantic is created in three steps.
        
        // First, compute the common availability for all variants.
        let availability = platforms.map { platforms in
            return SymbolGraph.Symbol.Availability(availability: platforms.map {
                let domain = $0.name.map { name in
                    return SymbolGraph.Symbol.Availability.Domain(
                        rawValue: name == "Mac Catalyst" ? SymbolGraph.Symbol.Availability.Domain.macCatalyst : name
                    )
                }
                
                // Only the `domain` and `introducedVersion` matter for external symbols. This information is used to determine if the symbol
                // is currently in beta or not, which displays a beta indicator next to the symbols title and abstract where it is curated.
                return SymbolGraph.Symbol.Availability.AvailabilityItem(
                    domain: domain,
                    introducedVersion: $0.introduced.flatMap { SymbolGraph.SemanticVersion(string: $0) },
                    deprecatedVersion: $0.deprecated.flatMap { SymbolGraph.SemanticVersion(string: $0) },
                    obsoletedVersion: $0.obsoleted.flatMap { SymbolGraph.SemanticVersion(string: $0) },
                    message: nil,
                    renamed: $0.renamed,
                    isUnconditionallyDeprecated: $0.unconditionallyDeprecated ?? false,
                    isUnconditionallyUnavailable: $0.unconditionallyUnavailable ?? false,
                    willEventuallyBeDeprecated: false // This information isn't used anywhere since this node doesn't have its own page, it's just referenced from other pages.
                )
            })
        }
        
        // Second, create data variants values with the main resolved information, as values for the main language variant trait.
        let mainTrait = DocumentationDataVariantsTrait(interfaceLanguage: language.id)
        var kindVariants = [mainTrait: symbolKind(forNodeKind: kind)]
        var titleVariants = [mainTrait: title]
        var subHeadingVariants = [DocumentationDataVariantsTrait: [SymbolGraph.Symbol.DeclarationFragments.Fragment]]()
        subHeadingVariants[mainTrait] = declarationFragments?.declarationFragments
        var abstractVariants = [DocumentationDataVariantsTrait: AbstractSection]()
        abstractVariants[mainTrait] = abstract.map { AbstractSection(paragraph: Paragraph([Text($0)])) }
        
        // Third, add additional values for each variant's resolved information.
        for variant in variants ?? [] {
            guard case .interfaceLanguage(let language) = variant.traits.first else { continue }
            let trait = DocumentationDataVariantsTrait(interfaceLanguage: language)
            
            if let variantKind = variant.kind {
                kindVariants[trait] = symbolKind(forNodeKind: variantKind)
            }
            if let variantTitle = variant.title {
                titleVariants[trait] = variantTitle
            }
            if let variantAbstract = variant.abstract {
                abstractVariants[trait] = AbstractSection(paragraph: Paragraph([Text(variantAbstract)]))
            }
            if let variantDeclarationFragments = variant.declarationFragments {
                // The declaration fragments is an optional value. If the resolved information contains an explicit `nil` value we set that as the variant value.
                // This behavior enables a symbol's variant to not have a declaration when the main symbol does have a declaration.
                subHeadingVariants[trait] = variantDeclarationFragments?.declarationFragments
            }
        }
        
        return Symbol(
            kindVariants: .init(values: kindVariants),
            titleVariants:  .init(values: titleVariants),
            subHeadingVariants: .init(values: subHeadingVariants),
            navigatorVariants: .empty,
            roleHeadingVariants: .init(values: [:], defaultVariantValue: ""), // This information isn't used anywhere since this node doesn't have its own page, it's just referenced from other pages.
            platformNameVariants: .empty,
            moduleReference: ResolvedTopicReference(bundleIdentifier: "", path: "", sourceLanguage: language), // This information isn't used anywhere since the `urlForResolvedReference(reference:)` specifies the URL for this node.
            externalIDVariants: .empty,
            accessLevelVariants: .empty,
            availabilityVariants: .init(values: [:], defaultVariantValue: availability),
            deprecatedSummaryVariants: .empty,
            mixinsVariants: .empty,
            abstractSectionVariants: .init(values: abstractVariants),
            discussionVariants: .empty,
            topicsVariants: .empty,
            seeAlsoVariants: .empty,
            returnsSectionVariants: .empty,
            parametersSectionVariants: .empty,
            redirectsVariants: .empty
        )
    }
}
