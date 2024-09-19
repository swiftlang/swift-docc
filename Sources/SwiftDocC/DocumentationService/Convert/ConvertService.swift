/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A service that converts documentation.
///
/// This service accepts in-memory documentation data with a ``ConvertRequest`` and returns the conversion's build products
/// such as the produced render nodes.
public struct ConvertService: DocumentationService {
    /// The message type that this service accepts.
    public static let convertMessageType: DocumentationServer.MessageType = "convert"

    /// The message type that this service responds with when the requested conversion was successful.
    public static
    let convertResponseMessageType: DocumentationServer.MessageType = "convert-response"

    /// The message type that this service responds with when the requested conversion failed.
    public static
    let convertResponseErrorMessageType: DocumentationServer.MessageType = "convert-response-error"

    public static var handlingTypes = [convertMessageType]
    
    /// Converter that can be injected from a test.
    var converter: DocumentationConverterProtocol?
    
    /// A peer server that can be used for resolving links.
    var linkResolvingServer: DocumentationServer?

    private let allowArbitraryCatalogDirectories: Bool

    /// Creates a conversion service, which converts in-memory documentation data.
    public init(linkResolvingServer: DocumentationServer? = nil, allowArbitraryCatalogDirectories: Bool) {
        self.linkResolvingServer = linkResolvingServer
        self.allowArbitraryCatalogDirectories = allowArbitraryCatalogDirectories
    }
    
    init(
        converter: DocumentationConverterProtocol?,
        linkResolvingServer: DocumentationServer?
    ) {
        self.converter = converter
        self.linkResolvingServer = linkResolvingServer
        self.allowArbitraryCatalogDirectories = false
    }
    
    public func process(
        _ message: DocumentationServer.Message,
        completion: @escaping (DocumentationServer.Message) -> ()
    ) {

        let conversionResult = retrievePayload(message)
            .flatMap(decodeRequest)
            .flatMap(convert)
            .flatMap(encodeResponse)

        switch conversionResult {
        case .success(let response):
            completion(
                DocumentationServer.Message(
                    type: Self.convertResponseMessageType,
                    identifier: "\(message.identifier)-response",
                    payload: response
                )
            )
            
        case .failure(let error):
            completion(
                DocumentationServer.Message(
                    type: Self.convertResponseErrorMessageType,
                    identifier: "\(message.identifier)-response-error",

                    // Force trying because encoding known messages should never fail.
                    payload: try! JSONEncoder().encode(error)
                )
            )
        }
    }

    /// Attempts to retrieve the payload from the given message, returning a failure if the payload is missing.
    ///
    /// - Returns: A result with the message's payload if present, otherwise a ``ConvertServiceError/missingPayload``
    /// failure.
    private func retrievePayload(
        _ message: DocumentationServer.Message
    ) -> Result<(payload: Data, messageIdentifier: String), ConvertServiceError> {
        message.payload.map { .success(($0, message.identifier)) } ?? .failure(.missingPayload())
    }

    /// Attempts to decode the given request, returning a failure if decoding failed.
    ///
    /// - Returns: A result with the decoded request if the decoding succeeded, otherwise a
    /// ``ConvertServiceError/invalidRequest`` failure.
    private func decodeRequest(
        data: Data,
        messageIdentifier: String
    ) -> Result<(request: ConvertRequest, messageIdentifier: String), ConvertServiceError> {
        Result {
            return (try JSONDecoder().decode(ConvertRequest.self, from: data), messageIdentifier)
        }.mapErrorToConvertServiceError {
            .invalidRequest(underlyingError: $0.localizedDescription)
        }
    }

    /// Attempts to process the given convert request, returning a failure if the conversion failed.
    ///
    /// - Returns: A result with the produced render nodes if the conversion was successful, otherwise a
    /// ``ConvertServiceError/conversionError`` failure.
    private func convert(
        request: ConvertRequest,
        messageIdentifier: String
    ) -> Result<([RenderNode], RenderReferenceStore?), ConvertServiceError> {
        Result {
            // Update DocC's current feature flags based on the ones provided
            // in the request.
            FeatureFlags.current = request.featureFlags
            
            // Set up the documentation context.

            let workspace = DocumentationWorkspace()
            
            let provider: DocumentationWorkspaceDataProvider
            if let bundleLocation = request.bundleLocation {
                // If an on-disk bundle is provided, convert it.
                // Additional symbol graphs and markup are ignored for now.
                provider = try LocalFileSystemDataProvider(
                    rootURL: bundleLocation,
                    allowArbitraryCatalogDirectories: allowArbitraryCatalogDirectories
                )
            } else {
                // Otherwise, convert the in-memory content.
                var inMemoryProvider = InMemoryContentDataProvider()
                
                inMemoryProvider.registerBundle(
                    info: request.bundleInfo,
                    symbolGraphs: request.symbolGraphs,
                    markupFiles: request.markupFiles,
                    tutorialFiles: request.tutorialFiles,
                    miscResourceURLs: request.miscResourceURLs
                )
                
                provider = inMemoryProvider
            }
            
            var configuration = DocumentationContext.Configuration()
            
            configuration.convertServiceConfiguration.knownDisambiguatedSymbolPathComponents = request.knownDisambiguatedSymbolPathComponents
            
            // Enable support for generating documentation for standalone articles and tutorials.
            configuration.convertServiceConfiguration.allowsRegisteringArticlesWithoutTechnologyRoot = true
            configuration.convertServiceConfiguration.considerDocumentationExtensionsThatDoNotMatchSymbolsAsResolved = true
            
            configuration.convertServiceConfiguration.symbolGraphTransformer = { symbolGraph in
                for (symbolIdentifier, overridingDocumentationComment) in request.overridingDocumentationComments ?? [:] {
                    symbolGraph.symbols[symbolIdentifier]?.docComment = SymbolGraph.LineList(
                        overridingDocumentationComment.map(SymbolGraph.LineList.Line.init(_:))
                    )
                }
            }
            
            if let linkResolvingServer {
                let resolver = try OutOfProcessReferenceResolver(
                    bundleIdentifier: request.bundleInfo.identifier,
                    server: linkResolvingServer,
                    convertRequestIdentifier: messageIdentifier
                )
                
                configuration.convertServiceConfiguration.fallbackResolver = resolver
                configuration.externalDocumentationConfiguration.globalSymbolResolver = resolver
            }
            
            let context = try DocumentationContext(dataProvider: workspace, configuration: configuration)
            
            var converter = try self.converter ?? DocumentationConverter(
                documentationBundleURL: request.bundleLocation ?? URL(fileURLWithPath: "/"),
                emitDigest: false,
                documentationCoverageOptions: .noCoverage,
                currentPlatforms: nil,
                workspace: workspace,
                context: context,
                dataProvider: provider,
                externalIDsToConvert: request.externalIDsToConvert,
                documentPathsToConvert: request.documentPathsToConvert,
                bundleDiscoveryOptions: BundleDiscoveryOptions(
                    fallbackInfo: request.bundleInfo,
                    additionalSymbolGraphFiles: []
                ),
                emitSymbolSourceFileURIs: request.emitSymbolSourceFileURIs,
                emitSymbolAccessLevels: true,
                symbolIdentifiersWithExpandedDocumentation: request.symbolIdentifiersWithExpandedDocumentation
            )

            // Run the conversion.

            let outputConsumer = OutputConsumer()
            let (_, conversionProblems) = try converter.convert(outputConsumer: outputConsumer)

            guard conversionProblems.isEmpty else {
                throw ConvertServiceError.conversionError(
                    underlyingError: DiagnosticConsoleWriter.formattedDescription(for: conversionProblems))
            }
            
            let references: RenderReferenceStore?
            if request.includeRenderReferenceStore == true {
                // Create a reference store and filter non-linkable references.
                references = outputConsumer.renderReferenceStore
                    .map {
                        var store = referenceStore(for: context, baseReferenceStore: $0)
                        store.topics = store.topics.filter({ pair in
                            // Filter non-linkable nodes that do belong to the topic graph.
                            guard let node = context.topicGraph.nodeWithReference(pair.key) else {
                                return true
                            }
                            return context.topicGraph.isLinkable(node.reference)
                        })
                        return store
                    }
            } else {
                references = nil
            }
            
            return (outputConsumer.renderNodes.sync({ $0 }), references)
        }.mapErrorToConvertServiceError {
            .conversionError(underlyingError: $0.localizedDescription)
        }
    }

    /// Encodes a conversion response to send to the client.
    ///
    /// - Parameter renderNodes: The render nodes that were produced as part of the conversion.
    private func encodeResponse(
        renderNodes: [RenderNode],
        renderReferenceStore: RenderReferenceStore?
    ) -> Result<Data, ConvertServiceError> {
        Result {
            let encoder = JSONEncoder()

            return try encoder.encode(
                try ConvertResponse(
                    renderNodes: renderNodes.map(encoder.encode),
                    renderReferenceStore: renderReferenceStore.map(encoder.encode)
                )
            )
        }.mapErrorToConvertServiceError {
            .invalidResponseMessage(underlyingError: $0.localizedDescription)
        }
    }
    
    /// Takes a base reference store and adds uncurated article references and documentation extensions.
    ///
    /// Uncurated article references and documentation extensions are not included in the reference store the converter produces by default.
    private func referenceStore(
        for context: DocumentationContext,
        baseReferenceStore: RenderReferenceStore?
    ) -> RenderReferenceStore {
        let uncuratedArticles = context.uncuratedArticles.map { ($0, isDocumentationExtensionContent: false) }
        let uncuratedDocumentationExtensions = context.uncuratedDocumentationExtensions.map { ($0, isDocumentationExtensionContent: true) }
        let topicContent = (uncuratedArticles + uncuratedDocumentationExtensions)
            .compactMap { (value, isDocumentationExtensionContent) -> (ResolvedTopicReference, RenderReferenceStore.TopicContent)? in
                let (topicReference, article) = value
                
                guard let bundle = context.bundle(identifier: topicReference.bundleIdentifier) else { return nil }
                let renderer = DocumentationContentRenderer(documentationContext: context, bundle: bundle)
                
                let documentationNodeKind: DocumentationNode.Kind = isDocumentationExtensionContent ? .unknownSymbol : .article
                let overridingDocumentationNode = DocumentationContext.documentationNodeAndTitle(for: article, kind: documentationNodeKind, in: bundle)?.node
                var dependencies = RenderReferenceDependencies()
                let renderReference = renderer.renderReference(for: topicReference, with: overridingDocumentationNode, dependencies: &dependencies)
                
                return (
                    topicReference,
                    RenderReferenceStore.TopicContent(
                        renderReference: renderReference,
                        canonicalPath: nil,
                        taskGroups: nil,
                        source: article.source,
                        isDocumentationExtensionContent: isDocumentationExtensionContent,
                        renderReferenceDependencies: dependencies
                    )
                )
            }

        var baseStore = baseReferenceStore ?? RenderReferenceStore()
        baseStore.topics.merge(topicContent, uniquingKeysWith: { old, _ in
            // Prioritize content that was in the base store, it might be more accurate.
            return old
        })
        return baseStore
    }
}

extension Result {
    /// Returns a new result, mapping any failure value using the given transformation if the error is not a conversion error.
    ///
    /// If the error value is a ``ConvertServiceError``, it is returned as-is. If it's not, the given transformation is called on the
    /// error.
    ///
    /// - Parameter transform: A closure that takes the failure value of the instance.
    func mapErrorToConvertServiceError(
        _ transform: (Error) -> ConvertServiceError
    ) -> Result<Success, ConvertServiceError> {
        mapError { error in
            switch error {
            case let error as ConvertServiceError: return error
            default: return transform(error)
            }
        }
    }
}

private extension SymbolGraph.LineList.Line {
    /// Creates a line given a convert request line.
    init(_ line: ConvertRequest.Line) {
        self.init(
            text: line.text,
            range: line.sourceRange.map { sourceRange in
                SymbolGraph.LineList.SourceRange(
                    start: SymbolGraph.LineList.SourceRange.Position(
                        line: sourceRange.start.line,
                        character: sourceRange.start.character
                    ),
                    end: SymbolGraph.LineList.SourceRange.Position(
                        line: sourceRange.end.line,
                        character: sourceRange.end.character
                    )
                )
            }
        )
    }
}
