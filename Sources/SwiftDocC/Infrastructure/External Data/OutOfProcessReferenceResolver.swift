/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
/// - ``ExternalDocumentationSource``
/// - ``GlobalExternalSymbolResolver``
/// - ``DocumentationContext/externalDocumentationSources``
/// - ``DocumentationContext/globalExternalSymbolResolver``
/// - ``Request``
/// - ``Response``
public class OutOfProcessReferenceResolver: ExternalDocumentationSource, GlobalExternalSymbolResolver {
    private let externalLinkResolvingClient: ExternalLinkResolving
    
    /// The bundle identifier for the reference resolver in the other process.
    public let bundleIdentifier: String
    
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
    ///   - convertRequestIdentifier: The identifier that the resolver will use for convert requests that it sends to the server.
    public init(bundleIdentifier: String, server: DocumentationServer, convertRequestIdentifier: String?) throws {
        self.bundleIdentifier = bundleIdentifier
        self.externalLinkResolvingClient = LongRunningService(
            server: server, convertRequestIdentifier: convertRequestIdentifier)
    }
    
    // MARK: External Reference Resolver
    
    public func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
        switch reference {
        case .resolved(let resolved):
            return resolved
            
        case let .unresolved(unresolvedReference):
            guard unresolvedReference.bundleIdentifier == bundleIdentifier else {
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
            bundleIdentifier: "com.externally.resolved.symbol",
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
            // The resolved information only stores the plain text abstract https://github.com/apple/swift-docc/issues/802
            abstract: [.text(resolvedInformation.abstract)],
            url: resolvedInformation.url.path,
            kind: kind,
            role: role,
            fragments: resolvedInformation.declarationFragments?.declarationFragments.map { DeclarationRenderSection.Token(fragment: $0, identifier: nil) },
            isBeta: (resolvedInformation.platforms ?? []).contains(where: { $0.isBeta == true }),
            isDeprecated: (resolvedInformation.platforms ?? []).contains(where: { $0.deprecated != nil }),
            titleStyle: resolvedInformation.kind.isSymbol ? .symbol : .title,
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
        
        return LinkResolver.ExternalEntity(topicRenderReference: renderReference, renderReferenceDependencies: dependencies, sourceLanguages: resolvedInformation.availableLanguages)
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
            bundleIdentifier: bundleIdentifier,
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
        case unableToDecodeResponseFromClient(Data, Swift.Error)
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
        // This type is duplicating the information from LinkDestinationSummary with some minor differences.
        // Changes generally need to be made in both places. It would be good to replace this with LinkDestinationSummary.
        // FIXME: https://github.com/apple/swift-docc/issues/802
        
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
        
        /// Images that are used to represent the summarized element.
        public var topicImages: [TopicImage]?
                
        /// References used in the content of the summarized element.
        public var references: [RenderReference]?
        
        /// The variants of content (kind, url, title, abstract, language, declaration) for this resolver information.
        public var variants: [Variant]?
        
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
        ///   - topicImages: Images that are used to represent the summarized element.
        ///   - references: References used in the content of the summarized element.
        ///   - variants: The variants of content for this resolver information.
        public init(
            kind: DocumentationNode.Kind,
            url: URL,
            title: String,
            abstract: String,
            language: SourceLanguage,
            availableLanguages: Set<SourceLanguage>,
            platforms: [PlatformAvailability]? = nil,
            declarationFragments: DeclarationFragments? = nil,
            topicImages: [TopicImage]? = nil,
            references: [RenderReference]? = nil,
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
            self.topicImages = topicImages
            self.references = references
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
            
            /// Creates a new resolved information variant with the values that are different from the resolved information values.
            ///
            /// - Parameters:
            ///   - traits: The traits of the variant.
            ///   - kind: The resolved kind.
            ///   - url: The resolved URL.
            ///   - title: The resolved title
            ///   - abstract: The resolved (plain text) abstract.
            ///   - language: The resolved language.
            ///   - declarationFragments: The resolved declaration fragments, if any.
            public init(
                traits: [RenderNode.Variant.Trait],
                kind: VariantValue<DocumentationNode.Kind> = nil,
                url: VariantValue<URL> = nil,
                title: VariantValue<String> = nil,
                abstract: VariantValue<String> = nil,
                language: VariantValue<SourceLanguage> = nil,
                declarationFragments: VariantValue<DeclarationFragments?> = nil
            ) {
                self.traits = traits
                self.kind = kind
                self.url = url
                self.title = title
                self.abstract = abstract
                self.language = language
                self.declarationFragments = declarationFragments
            }
        }
    }
}

extension OutOfProcessReferenceResolver.ResolvedInformation {
    enum CodingKeys: CodingKey {
        case kind
        case url
        case title
        case abstract
        case language
        case availableLanguages
        case platforms
        case declarationFragments
        case topicImages
        case references
        case variants
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        kind = try container.decode(DocumentationNode.Kind.self, forKey: .kind)
        url = try container.decode(URL.self, forKey: .url)
        title = try container.decode(String.self, forKey: .title)
        abstract = try container.decode(String.self, forKey: .abstract)
        language = try container.decode(SourceLanguage.self, forKey: .language)
        availableLanguages = try container.decode(Set<SourceLanguage>.self, forKey: .availableLanguages)
        platforms = try container.decodeIfPresent([OutOfProcessReferenceResolver.ResolvedInformation.PlatformAvailability].self, forKey: .platforms)
        declarationFragments = try container.decodeIfPresent(OutOfProcessReferenceResolver.ResolvedInformation.DeclarationFragments.self, forKey: .declarationFragments)
        topicImages = try container.decodeIfPresent([TopicImage].self, forKey: .topicImages)
        references = try container.decodeIfPresent([CodableRenderReference].self, forKey: .references).map { decodedReferences in
            decodedReferences.map(\.reference)
        }
        variants = try container.decodeIfPresent([OutOfProcessReferenceResolver.ResolvedInformation.Variant].self, forKey: .variants)
        
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.kind, forKey: .kind)
        try container.encode(self.url, forKey: .url)
        try container.encode(self.title, forKey: .title)
        try container.encode(self.abstract, forKey: .abstract)
        try container.encode(self.language, forKey: .language)
        try container.encode(self.availableLanguages, forKey: .availableLanguages)
        try container.encodeIfPresent(self.platforms, forKey: .platforms)
        try container.encodeIfPresent(self.declarationFragments, forKey: .declarationFragments)
        try container.encodeIfPresent(self.topicImages, forKey: .topicImages)
        try container.encodeIfPresent(references?.map { CodableRenderReference($0) }, forKey: .references)
        try container.encodeIfPresent(self.variants, forKey: .variants)
    }
}

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
        let assetReference = AssetReference(assetName: assetName, bundleIdentifier: bundleIdentifier)
        if let asset = assetCache[assetReference] {
            return asset
        }
        
        let response = try externalLinkResolvingClient.sendAndWait(
            request: Request.asset(AssetReference(assetName: assetName, bundleIdentifier: bundleIdentifier))
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
