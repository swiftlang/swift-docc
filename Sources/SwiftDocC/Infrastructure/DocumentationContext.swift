/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
import Markdown
import SymbolKit

/// A type that provides information about documentation bundles and their content.
@available(*, deprecated, message: "Pass the context its inputs at initialization instead. This deprecated API will be removed after 6.2 is released")
public protocol DocumentationContextDataProvider {
    /// An object to notify when bundles are added or removed.
    var delegate: (any DocumentationContextDataProviderDelegate)? { get set }

    /// The documentation bundles that this data provider provides.
    var bundles: [BundleIdentifier: DocumentationBundle] { get }

    /// Returns the data for the specified `url` in the provided `bundle`.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to read.
    ///   - bundle: The bundle that the file is a part of.
    ///
    /// - Throws: When the file cannot be found in the workspace.
    func contentsOfURL(_ url: URL, in bundle: DocumentationBundle) throws -> Data
}

/// An object that responds to changes in available documentation bundles for a specific provider.
@available(*, deprecated, message: "Pass the context its inputs at initialization instead. This deprecated API will be removed after 6.2 is released")
public protocol DocumentationContextDataProviderDelegate: AnyObject {

    /// Called when the `dataProvider` has added a new documentation bundle to its list of `bundles`.
    ///
    /// - Parameters:
    ///   - dataProvider: The provider that added this bundle.
    ///   - bundle: The bundle that was added.
    ///
    /// - Note: This method is called after the `dataProvider` has been added the bundle to its `bundles` property.
    func dataProvider(_ dataProvider: any DocumentationContextDataProvider, didAddBundle bundle:  DocumentationBundle) throws

    /// Called when the `dataProvider` has removed a documentation bundle from its list of `bundles`.
    ///
    /// - Parameters:
    ///   - dataProvider: The provider that removed this bundle.
    ///   - bundle: The bundle that was removed.
    ///
    /// - Note: This method is called after the `dataProvider` has been removed the bundle from its `bundles` property.
    func dataProvider(_ dataProvider: any DocumentationContextDataProvider, didRemoveBundle bundle:  DocumentationBundle) throws
}

/// Documentation bundles use a string value as a unique identifier.
///
/// This value is typically a reverse host name, for example: `com.<organization-name>.<product-name>`.
///
/// Documentation links may include the bundle identifier---as a host component of the URL---to reference content in a specific documentation bundle.
@available(*, deprecated, renamed: "DocumentationBundle.Identifier", message: "Use 'DocumentationBundle.Identifier' instead. This deprecated API will be removed after 6.2 is released")
public typealias BundleIdentifier = String

/// The documentation context manages the in-memory model for the built documentation.
///
/// A ``DocumentationWorkspace`` discovers serialized documentation bundles from a variety of sources (files on disk, databases, or web services), provides them to the `DocumentationContext`,
/// and notifies the context when bundles are added or removed using the ``DocumentationContextDataProviderDelegate`` protocol.
///
/// When a documentation bundle is registered with the context, all of its content is loaded into memory and relationships between documentation entities are built. When this is done, the context can be queried
/// about documentation entities, resources, and relationships between entities.
///
/// ## Topics
///
/// ### Getting documentation resources
///
/// - ``entity(with:)``
/// - ``resource(with:trait:)``
///
/// ### Getting documentation relationships
///
/// - ``children(of:kind:)``
/// - ``parents(of:)``
///
public class DocumentationContext {
    private let signposter = ConvertActionConverter.signposter

    /// An error that's encountered while interacting with a ``SwiftDocC/DocumentationContext``.
    public enum ContextError: DescribedError {
        /// The node couldn't be found in the documentation context.
        case notFound(URL)

        /// The file wasn't UTF-8 encoded.
        case utf8StringDecodingFailed(url: URL)

        /// We allow a symbol declaration with no OS (for REST & Plist symbols)
        /// but if such a declaration is found the symbol can have only one declaration.
        case unexpectedEmptyPlatformName(String)

        /// The bundle registration operation is cancelled externally.
        case registrationDisabled

        public var errorDescription: String {
            switch self {
                case .notFound(let url):
                    return "Couldn't find the requested node '\(url)' in the documentation context."
                case .utf8StringDecodingFailed(let url):
                    return "The file at '\(url)' could not be read because it was not valid UTF-8."
                case .unexpectedEmptyPlatformName(let symbolIdentifier):
                    return "Declaration without operating system name for symbol \(symbolIdentifier) cannot be merged with more declarations with operating system name for the same symbol"
                case .registrationDisabled:
                    return "The bundle registration operation is cancelled externally."
            }
        }
    }

    /// A class that resolves documentation links by orchestrating calls to other link resolver implementations.
    public var linkResolver: LinkResolver

    private enum _Provider {
        @available(*, deprecated, message: "Use 'DataProvider' instead. This deprecated API will be removed after 6.2 is released")
        case legacy(any DocumentationContextDataProvider)
        case new(any DataProvider)
    }
    private var dataProvider: _Provider

    /// The provider of documentation bundles for this context.
    @available(*, deprecated, message: "Use 'DataProvider' instead. This deprecated API will be removed after 6.2 is released")
    private var _legacyDataProvider: (any DocumentationContextDataProvider)! {
        get {
            switch dataProvider {
            case .legacy(let legacyDataProvider):
                legacyDataProvider
            case .new:
                nil
            }
        }
        set {
            dataProvider = .legacy(newValue)
        }
    }

    func contentsOfURL(_ url: URL, in bundle: DocumentationBundle) throws -> Data {
        switch dataProvider {
        case .legacy(let legacyDataProvider):
            return try legacyDataProvider.contentsOfURL(url, in: bundle)
        case .new(let dataProvider):
            assert(self.bundle?.id == bundle.id, "New code shouldn't pass unknown bundle identifiers to 'DocumentationContext.bundle(identifier:)'.")
            return try dataProvider.contents(of: url)
        }
    }

    /// The documentation bundle that is registered with the context.
    var bundle: DocumentationBundle?

    /// A collection of configuration for this context.
    public package(set) var configuration: Configuration {
        get { _configuration }
        @available(*, deprecated, message: "Pass a configuration at initialization. This property will become read-only after Swift 6.2 is released.")
        set { _configuration = newValue }
    }
    // Having a deprecated setter above requires a computed property.
    private var _configuration: Configuration

    /// The graph of all the documentation content and their relationships to each other.
    ///
    /// > Important: The topic graph has no awareness of source language specific edges.
    var topicGraph = TopicGraph()

    /// User-provided global options for this documentation conversion.
    var options: Options?

    /// The set of all manually curated references if `shouldStoreManuallyCuratedReferences` was true at the time of processing and has remained `true` since.. Nil if curation has not been processed yet.
    public private(set) var manuallyCuratedReferences: Set<ResolvedTopicReference>?

    @available(*, deprecated, renamed: "tutorialTableOfContentsReferences", message: "Use 'tutorialTableOfContentsReferences' This deprecated API will be removed after 6.2 is released")
    public var rootTechnologies: [ResolvedTopicReference] {
        tutorialTableOfContentsReferences
    }

    /// The tutorial table-of-contents nodes in the topic graph.
    public var tutorialTableOfContentsReferences: [ResolvedTopicReference] {
        return topicGraph.nodes.values.compactMap { node in
            guard node.kind == .tutorialTableOfContents && parents(of: node.reference).isEmpty else {
                return nil
            }
            return node.reference
        }
    }

    /// The root module nodes of the Topic Graph.
    ///
    /// This property is initialized during the registration of a documentation bundle.
    public private(set) var rootModules: [ResolvedTopicReference]!

    /// The topic reference of the root module, if it's the only registered module.
    var soleRootModuleReference: ResolvedTopicReference? {
        guard rootModules.count > 1 else {
            return rootModules.first
        }
        // There are multiple "root modules" but some may be "virtual".
        // Removing those may leave only one root module left.
        let nonVirtualModules = rootModules.filter {
            topicGraph.nodes[$0]?.isVirtual ?? false
        }
        return nonVirtualModules.count == 1 ? nonVirtualModules.first : nil
    }

    typealias LocalCache = ContentCache<DocumentationNode>
    typealias ExternalCache = ContentCache<LinkResolver.ExternalEntity>

    /// Map of document URLs to topic references.
    var documentLocationMap = BidirectionalMap<URL, ResolvedTopicReference>()
    /// A storage of already created documentation nodes for the local documentation content.
    ///
    /// The documentation cache is built up incrementally as local content is registered with the documentation context.
    ///
    /// First, the context adds all symbols, with both their references and symbol IDs for lookup. The ``SymbolGraphRelationshipsBuilder`` looks up documentation
    /// nodes by their symbol's ID when it builds up in-memory relationships between symbols. Later, the context adds articles and other conceptual content with only their
    /// references for lookup.
    var documentationCache = LocalCache()
    /// The asset managers for each documentation bundle, keyed by the bundle's identifier.
    var assetManagers = [DocumentationBundle.Identifier: DataAssetManager]()
    /// A list of non-topic links that can be resolved.
    var nodeAnchorSections = [ResolvedTopicReference: AnchorSection]()

    /// A storage of externally resolved content.
    ///
    /// The external cache is built up in two steps;
    /// - While the context processes the local symbols, a ``GlobalExternalSymbolResolver`` or ``ExternalPathHierarchyResolver`` may add entities
    ///   for any external symbols that are referenced by a relationship or by a declaration token identifier in the local symbol graph files.
    /// - Before the context finishes registering content, a ``ExternalDocumentationSource`` or ``ExternalPathHierarchyResolver`` may add entities
    ///   for any external links in the local content that the external source or external resolver could successfully resolve.
    var externalCache = ExternalCache()

    /// Returns the local or external reference for a known symbol ID.
    func localOrExternalReference(symbolID: String) -> ResolvedTopicReference? {
        documentationCache.reference(symbolID: symbolID) ?? externalCache.reference(symbolID: symbolID)
    }

    /// A list of all the problems that was encountered while registering and processing the documentation bundles in this context.
    public var problems: [Problem] {
        return diagnosticEngine.problems
    }

    /// The engine that collects problems encountered while registering and processing the documentation bundles in this context.
    public var diagnosticEngine: DiagnosticEngine

    /// All the link references that have been resolved from external sources, either successfully or not.
    ///
    /// The unsuccessful links are tracked so that the context doesn't attempt to re-resolve the unsuccessful links during rendering which runs concurrently for each page.
    var externallyResolvedLinks = [ValidatedURL: TopicReferenceResolutionResult]()

    /// A temporary structure to hold a semantic value that hasn't yet had its links resolved.
    ///
    /// These temporary values are only expected to exist while the documentation is being built. Once the documentation bundles have been fully registered and the topic graph
    /// has been built, the documentation context shouldn't hold any semantic result values anymore.
    struct SemanticResult<S: Semantic> {
        /// The ``Semantic`` value with unresolved links.
        var value: S

        /// The source of the document that produces the ``value``.
        var source: URL

        /// The Topic Graph node for this value.
        var topicGraphNode: TopicGraph.Node
    }

    /// Temporary storage for articles before they are curated and moved to the documentation cache.
    ///
    /// This storage is only used while the documentation context is being built. Once the documentation bundles have been fully registered and the topic graph
    /// has been built, this list of uncurated articles will be empty.
    ///
    /// The key to lookup an article is the reference to the article itself.
    var uncuratedArticles = [ResolvedTopicReference: SemanticResult<Article>]()

    /// Temporary storage for documentation extension files before they are curated and moved to the documentation cache.
    ///
    /// This storage is only used while the documentation context is being built. Once the documentation bundles have been fully registered and the topic graph
    /// has been built, this list of uncurated documentation extensions will be empty.
    ///
    /// The key to lookup a documentation extension file is the symbol reference from its title (level 1 heading).
    var uncuratedDocumentationExtensions = [ResolvedTopicReference: SemanticResult<Article>]()

    /// Mentions of symbols within articles.
    var articleSymbolMentions = ArticleSymbolMentions()

    /// Initializes a documentation context with a given `dataProvider` and registers all the documentation bundles that it provides.
    ///
    /// - Parameters:
    ///   - dataProvider: The data provider to register bundles from.
    ///   - diagnosticEngine: The pre-configured engine that will collect problems encountered during compilation.
    ///   - configuration: A collection of configuration for the created context.
    /// - Throws: If an error is encountered while registering a documentation bundle.
    @available(*, deprecated, message: "Pass the context its inputs at initialization instead. This deprecated API will be removed after 6.2 is released")
    public init(
        dataProvider: any DocumentationContextDataProvider,
        diagnosticEngine: DiagnosticEngine = .init(),
        configuration: Configuration = .init()
    ) throws {
        self.dataProvider = .legacy(dataProvider)
        self.diagnosticEngine = diagnosticEngine
        self._configuration = configuration
        self.linkResolver = LinkResolver(dataProvider: FileManager.default)

        _legacyDataProvider.delegate = self

        for bundle in dataProvider.bundles.values {
            try register(bundle)
        }
    }

    /// Initializes a documentation context with a given `bundle`.
    ///
    /// - Parameters:
    ///   - bundle: The bundle to register with the context.
    ///   - fileManager: The file manager that the context uses to read files from the bundle.
    ///   - diagnosticEngine: The pre-configured engine that will collect problems encountered during compilation.
    ///   - configuration: A collection of configuration for the created context.
    /// - Throws: If an error is encountered while registering a documentation bundle.
    package init(
        bundle: DocumentationBundle,
        dataProvider: any DataProvider,
        diagnosticEngine: DiagnosticEngine = .init(),
        configuration: Configuration = .init()
    ) throws {
        self.bundle = bundle
        self.dataProvider = .new(dataProvider)
        self.diagnosticEngine = diagnosticEngine
        self._configuration = configuration
        self.linkResolver = LinkResolver(dataProvider: dataProvider)

        ResolvedTopicReference.enableReferenceCaching(for: bundle.id)
        try register(bundle)
    }

    /// Respond to a new `bundle` being added to the `dataProvider` by registering it.
    ///
    /// - Parameters:
    ///   - dataProvider: The provider that added this bundle.
    ///   - bundle: The bundle that was added.
    @available(*, deprecated, message: "Pass the context its inputs at initialization instead. This deprecated API will be removed after 6.2 is released")
    public func dataProvider(_ dataProvider: any DocumentationContextDataProvider, didAddBundle bundle: DocumentationBundle) throws {
        try benchmark(wrap: Benchmark.Duration(id: "bundle-registration")) {
            // Enable reference caching for this documentation bundle.
            ResolvedTopicReference.enableReferenceCaching(for: bundle.id)

            try self.register(bundle)
        }
    }

    /// Respond to a new `bundle` being removed from the `dataProvider` by unregistering it.
    ///
    /// - Parameters:
    ///   - dataProvider: The provider that removed this bundle.
    ///   - bundle: The bundle that was removed.
    @available(*, deprecated, message: "Pass the context its inputs at initialization instead. This deprecated API will be removed after 6.2 is released")
    public func dataProvider(_ dataProvider: any DocumentationContextDataProvider, didRemoveBundle bundle: DocumentationBundle) throws {
        linkResolver.localResolver?.unregisterBundle(identifier: bundle.id)

        // Purge the reference cache for this bundle and disable reference caching for
        // this bundle moving forward.
        ResolvedTopicReference.purgePool(for: bundle.id)

        unregister(bundle)
    }

    /// The documentation bundles that are currently registered with the context.
    @available(*, deprecated, message: "Use 'bundle' instead. This deprecated API will be removed after 6.2 is released")
    public var registeredBundles: some Collection<DocumentationBundle> {
        _registeredBundles
    }

    /// Returns the `DocumentationBundle` with the given `identifier` if it's registered with the context, otherwise `nil`.
    @available(*, deprecated, message: "Use 'bundle' instead. This deprecated API will be removed after 6.2 is released")
    public func bundle(identifier: String) -> DocumentationBundle? {
        _bundle(identifier: identifier)
    }

    // Remove these  when removing `registeredBundles` and `bundle(identifier:)`.
    // These exist so that internal code that need to be compatible with legacy data providers can access the bundles without deprecation warnings.
    var _registeredBundles: [DocumentationBundle] {
        switch dataProvider {
        case .legacy(let legacyDataProvider):
            Array(legacyDataProvider.bundles.values)
        case .new:
            bundle.map { [$0] } ?? []
        }
    }

    func _bundle(identifier: String) -> DocumentationBundle? {
        switch dataProvider {
        case .legacy(let legacyDataProvider):
            return legacyDataProvider.bundles[identifier]
        case .new:
            assert(bundle?.id.rawValue == identifier, "New code shouldn't pass unknown bundle identifiers to 'DocumentationContext.bundle(identifier:)'.")
            return bundle?.id.rawValue == identifier ? bundle : nil
        }
    }

    /// Perform semantic analysis on a given `document` at a given `source` location and append any problems found to `problems`.
    ///
    /// - Parameters:
    ///   - document: The document to analyze.
    ///   - source: The location of the document.
    ///   - bundle: The bundle that the document belongs to.
    ///   - problems: A mutable collection of problems to update with any problem encountered during the semantic analysis.
    /// - Returns: The result of the semantic analysis.
    private func analyze(_ document: Document, at source: URL, in bundle: DocumentationBundle, engine: DiagnosticEngine) -> Semantic? {
        var analyzer = SemanticAnalyzer(source: source, bundle: bundle)
        let result = analyzer.visit(document)
        engine.emit(analyzer.problems)
        return result
    }

    /// Perform global analysis of compiled Markup
    ///
    /// Global analysis differs from semantic analysis in that no transformation is expected to occur. The
    /// analyses performed in this method don't transform documents, they only inspect them.
    ///
    /// Global checks are generally not expected to be run on tutorials or tutorial articles. The structure of
    /// tutorial content is very different from the expected structure of most documentation. If a checker is
    /// only checking content, it can probably be run on all types of documentation without issue. If the
    /// checker needs to check (or makes assumptions about) structure, it should probably be run only on
    /// non-tutorial content. If tutorial-related docs need to be checked or analyzed in some way (such as
    /// checking for the existence of a child directive), a semantic analyzer is probably the better solution.
    /// Tutorial content is highly structured and will be parsed into models that can be analyzed in a
    /// type-safe manner.
    ///
    /// - Parameters:
    ///   - document: The document to analyze.
    ///   - source: The location of the document.
    private func check(_ document: Document, at source: URL) {
        var checker = CompositeChecker([
            AbstractContainsFormattedTextOnly(sourceFile: source).any(),
            DuplicateTopicsSections(sourceFile: source).any(),
            InvalidAdditionalTitle(sourceFile: source).any(),
            MissingAbstract(sourceFile: source).any(),
            NonOverviewHeadingChecker(sourceFile: source).any(),
            SeeAlsoInTopicsHeadingChecker(sourceFile: source).any(),
        ])
        checker.visit(document)
        diagnosticEngine.emit(checker.problems)
    }

    /// A cache of plain string module names, keyed by the module node reference.
    private var moduleNameCache: [ResolvedTopicReference: (displayName: String, symbolName: String)] = [:]

    /// Find the known plain string module name for a given module reference.
    ///
    /// - Note: Looking up module names requires that the module names have been pre-resolved. This happens automatically at the end of bundle registration.
    ///
    /// - Parameter moduleReference: The module reference to find the module name for.
    /// - Returns: The plain string name for the referenced module.
    func moduleName(forModuleReference moduleReference: ResolvedTopicReference) -> (displayName: String, symbolName: String) {
        if let name = moduleNameCache[moduleReference] {
            return name
        }
        // If no name is found it's considered a programmer error; either that the names haven't been resolved yet
        // or that the passed argument isn't a reference to a known module.
        if moduleNameCache.isEmpty {
            fatalError("Incorrect use of API: '\(#function)' requires that bundles have finished registering.")
        }
        fatalError("Incorrect use of API: '\(#function)' can only be used with known module references")
    }

    /// Attempts to resolve the module names of all root modules.
    ///
    /// This allows the module names to quickly be looked up using ``moduleName(forModuleReference:)``
    func preResolveModuleNames() {
        for reference in rootModules {
            if let node = try? entity(with: reference) {
                // A module node should always have a symbol.
                // Remove the fallback value and force unwrap `node.symbol` on the main branch: https://github.com/swiftlang/swift-docc/issues/249
                moduleNameCache[reference] = (node.name.plainText, node.symbol?.names.title ?? reference.lastPathComponent)
            }
        }
    }

    /// Attempts to resolve links external to the given bundle.
    ///
    /// The link resolution results are collected in ``externallyResolvedLinks``.
    ///
    /// - Parameters:
    ///   - references: A list of references to local nodes to visit to collect links.
    ///   - localBundleID: The local bundle ID, used to identify and skip absolute fully qualified local links.
    private func preResolveExternalLinks(references: [ResolvedTopicReference], localBundleID: DocumentationBundle.Identifier) {
        preResolveExternalLinks(semanticObjects: references.compactMap({ reference -> ReferencedSemanticObject? in
            guard let node = try? entity(with: reference), let semantic = node.semantic else { return nil }
            return (reference: reference, semantic: semantic)
        }), localBundleID: localBundleID)
    }

    /// A tuple of a semantic object and its reference in the topic graph.
    private typealias ReferencedSemanticObject = (reference: ResolvedTopicReference, semantic: Semantic)

    /// Converts a semantic result to a referenced semantic object by removing the generic constraint.
    private func referencedSemanticObject(from: SemanticResult<some Semantic>) -> ReferencedSemanticObject {
        return (reference: from.topicGraphNode.reference, semantic: from.value)
    }

    /// Attempts to resolve links external to the given bundle by visiting the given list of semantic objects.
    ///
    /// The resolved references are collected in ``externallyResolvedLinks``.
    ///
    /// - Parameters:
    ///   - semanticObjects: A list of semantic objects to visit to collect links.
    ///   - localBundleID: The local bundle ID, used to identify and skip absolute fully qualified local links.
    private func preResolveExternalLinks(semanticObjects: [ReferencedSemanticObject], localBundleID: DocumentationBundle.Identifier) {
        // If there are no external resolvers added we will not resolve any links.
        guard !configuration.externalDocumentationConfiguration.sources.isEmpty else { return }

        let collectedExternalLinks = Synchronized([DocumentationBundle.Identifier: Set<UnresolvedTopicReference>]())
        semanticObjects.concurrentPerform { _, semantic in
            autoreleasepool {
                // Walk the node and extract external link references.
                var externalLinksCollector = ExternalReferenceWalker(localBundleID: localBundleID)
                externalLinksCollector.visit(semantic)

                // Avoid any synchronization overhead if there are no references to add.
                guard !externalLinksCollector.collectedExternalReferences.isEmpty else { return }

                // Add the link pairs to `collectedExternalLinks`.
                collectedExternalLinks.sync {
                    for (bundleID, collectedLinks) in externalLinksCollector.collectedExternalReferences {
                        $0[bundleID, default: []].formUnion(collectedLinks)
                    }
                }
            }
        }

        for (bundleID, collectedLinks) in collectedExternalLinks.sync({ $0 }) {
            guard let externalResolver = configuration.externalDocumentationConfiguration.sources[bundleID] else {
                continue
            }
            for externalLink in collectedLinks {
                let unresolvedURL = externalLink.topicURL
                let result = externalResolver.resolve(.unresolved(externalLink))
                externallyResolvedLinks[unresolvedURL] = result

                if case .success(let resolvedReference) = result {
                    // Add the resolved entity to the documentation cache.
                    if let externallyResolvedNode = externalEntity(with: resolvedReference) {
                        externalCache[resolvedReference] = externallyResolvedNode
                    }
                    if unresolvedURL.absoluteString != resolvedReference.absoluteString,
                       let resolvedURL = ValidatedURL(resolvedReference.url) {
                        // If the resolved reference has a different URL than the authored link, cache both URLs so we can resolve both unresolved and resolved references.
                        //
                        // The two main examples when this would happen are:
                        // - when resolving a redirected article and the authored link was the old URL
                        // - when resolving a symbol with multiple language representations and the authored link wasn't the canonical URL
                        externallyResolvedLinks[resolvedURL] = result
                    }
                }
            }
        }
    }

    /// A resolved documentation node along with any relevant problems.
    private typealias LinkResolveResult = (reference: ResolvedTopicReference, node: DocumentationNode, problems: [Problem])

    /**
     Attempt to resolve links in curation-only documentation, converting any ``TopicReferences`` from `.unresolved` to `.resolved` where possible.
     */
    private func resolveLinks(curatedReferences: Set<ResolvedTopicReference>, bundle: DocumentationBundle) {
        let signpostHandle = signposter.beginInterval("Resolve links", id: signposter.makeSignpostID())
        defer {
            signposter.endInterval("Resolve links", signpostHandle)
        }

        let references = Array(curatedReferences)
        let results = Synchronized<[LinkResolveResult]>([])
        results.sync({ $0.reserveCapacity(references.count) })

        func inheritsDocumentationFromOtherModule(_ documentationNode: DocumentationNode, symbolOriginReference: ResolvedTopicReference) -> Bool {
            // Check that this symbol only has documentation from an in-source documentation comment
            guard documentationNode.docChunks.count == 1,
                  case .sourceCode = documentationNode.docChunks.first?.source
            else {
                return false
            }

            // Check that that documentation comment is inherited from a symbol belonging to another module
            guard let symbolSemantic = documentationNode.semantic as? Symbol,
                  let originSymbolSemantic = documentationCache[symbolOriginReference]?.semantic as? Symbol
            else {
                return false
            }
            return symbolSemantic.moduleReference != originSymbolSemantic.moduleReference
        }

        let resolveNodeWithReference: (ResolvedTopicReference) -> Void = { [unowned self] reference in
            guard var documentationNode = try? entity(with: reference),
                  documentationNode.semantic is Article || documentationNode.semantic is Symbol
            else {
                return
            }

            let symbolOriginReference = (documentationNode.semantic as? Symbol)?.origin.flatMap { origin in
                documentationCache.reference(symbolID: origin.identifier)
            }
            // Check if we should skip resolving links for inherited documentation from other modules.
            if !configuration.externalMetadata.inheritDocs,
                let symbolOriginReference,
                inheritsDocumentationFromOtherModule(documentationNode, symbolOriginReference: symbolOriginReference)
            {
                // Don't resolve any links for this symbol.
                return
            }

            var resolver = ReferenceResolver(context: self, bundle: bundle, rootReference: reference, inheritanceParentReference: symbolOriginReference)

            // Update the node with the markup that contains resolved references instead of authored links.
            documentationNode.semantic = autoreleasepool {
                // We use an autorelease pool to release used memory as soon as possible, since the resolver will copy each semantic value
                // to rewrite it and replace the authored links with resolved reference strings instead.
                resolver.visit(documentationNode.semantic)
            }

            // Also resolve the node's alternate representations. This isn't part of the node's 'semantic' value (resolved above).
            if let alternateRepresentations = documentationNode.metadata?.alternateRepresentations {
                for alternateRepresentation in alternateRepresentations {
                    let resolutionResult = resolver.resolve(
                        alternateRepresentation.reference,
                        in: bundle.rootReference,
                        range: alternateRepresentation.originalMarkup.range,
                        severity: .warning
                    )
                    alternateRepresentation.reference = .resolved(resolutionResult)
                }
            }

            let problems: [Problem]
            if documentationNode.semantic is Article {
                // Diagnostics for articles have correct source ranges and don't need to be modified.
                problems = resolver.problems
            } else {
                // Diagnostics for in-source documentation comments need to be offset based on the start location of the comment in the source file.

                // Get the source location
                let inSourceDocumentationCommentInfo = documentationNode.inSourceDocumentationChunk

                // Post-process and filter out unwanted diagnostics (for example from inherited documentation comments)
                problems = resolver.problems.compactMap { problem in
                    guard let source = problem.diagnostic.source else {
                        // Ignore any diagnostic without a source location. These can't be meaningfully presented to the user.
                        return nil
                    }

                    if source == inSourceDocumentationCommentInfo?.url, let offset = inSourceDocumentationCommentInfo?.offset {
                        // Diagnostics from an in-source documentation comment need to be offset based on the location of that documentation comment.
                        var modifiedProblem = problem
                        modifiedProblem.offsetWithRange(offset)
                        return modifiedProblem
                    }

                    // Diagnostics from documentation extension files have correct source ranges and don't need to be modified.
                    return problem
                }
            }

            // Also resolve the node's page images. This isn't part of the node's 'semantic' value (resolved above).
            let pageImageProblems = documentationNode.metadata?.pageImages.compactMap { pageImage in
                return resolver.resolve(
                    resource: pageImage.source,
                    range: pageImage.originalMarkup.range,
                    severity: .warning
                )
            } ?? []

            let result: LinkResolveResult = (reference: reference, node: documentationNode, problems: problems + pageImageProblems)
            results.sync({ $0.append(result) })
        }

        // Resolve links concurrently if there are no external resolvers.
        references.concurrentPerform { reference -> Void in
            resolveNodeWithReference(reference)
        }

        for result in results.sync({ $0 }) {
            documentationCache[result.reference] = result.node

            if FeatureFlags.current.isMentionedInEnabled {
                // Record symbol links as symbol "mentions" for automatic cross references
                // on rendered symbol documentation.
                if let article = result.node.semantic as? Article,
                   case .article = DocumentationContentRenderer.roleForArticle(article, nodeKind: result.node.kind)
                {
                    for markup in article.abstractSection?.content ?? [] {
                        var mentions = SymbolLinkCollector(context: self, article: result.node.reference, baseWeight: 2)
                        mentions.visit(markup)
                    }
                    for markup in article.discussion?.content ?? [] {
                        var mentions = SymbolLinkCollector(context: self, article: result.node.reference, baseWeight: 1)
                        mentions.visit(markup)
                    }
                }
            }

            assert(
                // If this is a symbol, verify that the reference exist in the in the symbolIndex
                result.node.symbol.map { documentationCache.reference(symbolID: $0.identifier.precise) == result.reference }
                ?? true, // Nothing to check for non-symbols
                "Previous versions stored symbolIndex and documentationCache separately and updated both. This assert verifies that that's no longer necessary."
            )
            diagnosticEngine.emit(result.problems)
        }

        mergeFallbackLinkResolutionResults()
    }

    /// Attempt to resolve links in imported documentation, converting any ``TopicReferences`` from `.unresolved` to `.resolved` where possible.
    ///
    /// This function is passed pages that haven't been added to the topic graph yet. Calling this function will load the documentation entity for each of these pages
    /// and add nodes and relationships for some in-page semantics the `topicGraph`. After calling this function, these pages should be accessed by looking them
    /// up in the context, not from the arrays that was passed as arguments.
    ///
    /// - Parameters:
    ///   - tutorialTableOfContentsResults: The list of temporary 'tutorial table-of-contents' pages.
    ///   - tutorials: The list of temporary 'tutorial' pages.
    ///   - tutorialArticles: The list of temporary 'tutorialArticle' pages.
    ///   - bundle: The bundle to resolve links against.
    private func resolveLinks(
        tutorialTableOfContents tutorialTableOfContentsResults: [SemanticResult<TutorialTableOfContents>],
        tutorials: [SemanticResult<Tutorial>],
        tutorialArticles: [SemanticResult<TutorialArticle>],
        bundle: DocumentationBundle
    ) {
        let signpostHandle = signposter.beginInterval("Resolve links", id: signposter.makeSignpostID())
        defer {
            signposter.endInterval("Resolve links", signpostHandle)
        }

        let sourceLanguages = soleRootModuleReference.map { self.sourceLanguages(for: $0) } ?? [.swift]

        // Tutorial table-of-contents

        for tableOfContentsResult in tutorialTableOfContentsResults {
            autoreleasepool {
                let url = tableOfContentsResult.source
                var resolver = ReferenceResolver(context: self, bundle: bundle)
                let tableOfContents = resolver.visit(tableOfContentsResult.value) as! TutorialTableOfContents
                diagnosticEngine.emit(resolver.problems)

                // Add to document map
                documentLocationMap[url] = tableOfContentsResult.topicGraphNode.reference

                let tableOfContentsReference = tableOfContentsResult.topicGraphNode.reference.withSourceLanguages(sourceLanguages)

                let tutorialTableOfContentsNode = DocumentationNode(
                    reference: tableOfContentsReference,
                    kind: .tutorialTableOfContents,
                    sourceLanguage: Self.defaultLanguage(in: sourceLanguages),
                    availableSourceLanguages: sourceLanguages,
                    name: .conceptual(title: tableOfContents.intro.title),
                    markup: tableOfContents.originalMarkup,
                    semantic: tableOfContents
                )
                documentationCache[tableOfContentsReference] = tutorialTableOfContentsNode

                // Update the reference in the topic graph with the table-of-contents page's available languages.
                topicGraph.updateReference(
                    tableOfContentsResult.topicGraphNode.reference,
                    newReference: tableOfContentsReference
                )

                let anonymousVolumeName = "$volume"

                for volume in tableOfContents.volumes {
                    // Graph node: Volume
                    let volumeReference = tutorialTableOfContentsNode.reference.appendingPath(volume.name ?? anonymousVolumeName)
                    let volumeNode = TopicGraph.Node(reference: volumeReference, kind: .volume, source: .file(url: url), title: volume.name ?? anonymousVolumeName)
                    topicGraph.addNode(volumeNode)

                    // Graph edge: Tutorial table-of-contents -> Volume
                    topicGraph.addEdge(from: tableOfContentsResult.topicGraphNode, to: volumeNode)

                    for chapter in volume.chapters {
                        // Graph node: Module
                        let baseNodeReference: ResolvedTopicReference
                        if volume.name == nil {
                            baseNodeReference = tutorialTableOfContentsNode.reference
                        } else {
                            baseNodeReference = volumeNode.reference
                        }

                        let chapterReference = baseNodeReference.appendingPath(chapter.name)
                        let chapterNode = TopicGraph.Node(reference: chapterReference, kind: .chapter, source: .file(url: url), title: chapter.name)
                        topicGraph.addNode(chapterNode)

                        // Graph edge: Volume -> Chapter
                        topicGraph.addEdge(from: volumeNode, to: chapterNode)

                        for tutorialReference in chapter.topicReferences {
                            guard case let .resolved(.success(tutorialReference)) = tutorialReference.topic,
                                let tutorialNode = topicGraph.nodeWithReference(tutorialReference) else {
                                    continue
                            }
                            // Graph edge: Chapter -> Tutorial | TutorialArticle
                            topicGraph.addEdge(from: chapterNode, to: tutorialNode)
                        }
                    }
                }
            }
        }

        // Tutorials

        for tutorialResult in tutorials {
            autoreleasepool {
                let url = tutorialResult.source
                let unresolvedTutorial = tutorialResult.value
                var resolver = ReferenceResolver(context: self, bundle: bundle)
                let tutorial = resolver.visit(unresolvedTutorial) as! Tutorial
                diagnosticEngine.emit(resolver.problems)

                // Add to document map
                documentLocationMap[url] = tutorialResult.topicGraphNode.reference

                let tutorialReference = tutorialResult.topicGraphNode.reference.withSourceLanguages(sourceLanguages)

                let tutorialNode = DocumentationNode(
                    reference: tutorialReference,
                    kind: .tutorial,
                    sourceLanguage: Self.defaultLanguage(in: sourceLanguages),
                    availableSourceLanguages: sourceLanguages,
                    name: .conceptual(title: tutorial.intro.title),
                    markup: tutorial.originalMarkup,
                    semantic: tutorial
                )
                documentationCache[tutorialReference] = tutorialNode

                // Update the reference in the topic graph with the tutorial's available languages.
                topicGraph.updateReference(
                    tutorialResult.topicGraphNode.reference,
                    newReference: tutorialReference
                )
            }
        }

        // Tutorial Articles

        for articleResult in tutorialArticles {
            autoreleasepool {
                let url = articleResult.source
                let unresolvedTutorialArticle = articleResult.value
                var resolver = ReferenceResolver(context: self, bundle: bundle)
                let article = resolver.visit(unresolvedTutorialArticle) as! TutorialArticle
                diagnosticEngine.emit(resolver.problems)

                // Add to document map
                documentLocationMap[url] = articleResult.topicGraphNode.reference

                let articleReference = articleResult.topicGraphNode.reference.withSourceLanguages(sourceLanguages)

                let articleNode = DocumentationNode(
                    reference: articleReference,
                    kind: .tutorialArticle,
                    sourceLanguage: Self.defaultLanguage(in: sourceLanguages),
                    availableSourceLanguages: sourceLanguages,
                    name: .conceptual(title: article.title ?? ""),
                    markup: article.originalMarkup,
                    semantic: article
                )
                documentationCache[articleReference] = articleNode

                // Update the reference in the topic graph with the article's available languages.
                topicGraph.updateReference(
                    articleResult.topicGraphNode.reference,
                    newReference: articleReference
                )
            }
        }

        // Articles are resolved in a separate pass
    }

    private func registerDocuments(from bundle: DocumentationBundle) throws -> (
        tutorialTableOfContentsResults: [SemanticResult<TutorialTableOfContents>],
        tutorials: [SemanticResult<Tutorial>],
        tutorialArticles: [SemanticResult<TutorialArticle>],
        articles: [SemanticResult<Article>],
        documentationExtensions: [SemanticResult<Article>]
    ) {
        // First, try to understand the basic structure of the document by
        // analyzing it and putting references in as "unresolved".
        var tutorialTableOfContentsResults = [SemanticResult<TutorialTableOfContents>]()
        var tutorials = [SemanticResult<Tutorial>]()
        var tutorialArticles = [SemanticResult<TutorialArticle>]()
        var articles = [SemanticResult<Article>]()
        var documentationExtensions = [SemanticResult<Article>]()

        var references: [ResolvedTopicReference: URL] = [:]

        let decodeError = Synchronized<(any Error)?>(nil)

        // Load and analyze documents concurrently
        let analyzedDocuments: [(URL, Semantic)] = bundle.markupURLs.concurrentPerform { url, results in
            guard decodeError.sync({ $0 == nil }) else { return }

            do {
                let data = try contentsOfURL(url, in: bundle)
                let source = String(decoding: data, as: UTF8.self)
                let document = Document(parsing: source, source: url, options: [.parseBlockDirectives, .parseSymbolLinks])

                // Check for non-inclusive language in all types of docs if that diagnostic severity is required.
                if configuration.externalMetadata.diagnosticLevel >= NonInclusiveLanguageChecker.severity {
                    var langChecker = NonInclusiveLanguageChecker(sourceFile: url)
                    langChecker.visit(document)
                    diagnosticEngine.emit(langChecker.problems)
                }

                guard let analyzed = analyze(document, at: url, in: bundle, engine: diagnosticEngine) else {
                    return
                }

                // Only check non-tutorial documents from markup.
                if analyzed is Article {
                    check(document, at: url)
                }

                results.append((url, analyzed))
            } catch {
                decodeError.sync({ $0 = error })
            }
        }

        // Rethrow the decoding error if decoding failed.
        if let error = decodeError.sync({ $0 }) {
            throw error
        }

        // to preserve the order of documents by url
        let analyzedDocumentsSorted = analyzedDocuments.sorted(by: \.0.absoluteString)

        for analyzedDocument in analyzedDocumentsSorted {
            // Store the references we encounter to ensure they're unique. The file name is currently the only part of the URL considered for the topic reference, so collisions may occur.
            let (url, analyzed) = analyzedDocument

            let path = NodeURLGenerator.pathForSemantic(analyzed, source: url, bundle: bundle)
            let reference = ResolvedTopicReference(bundleID: bundle.id, path: path, sourceLanguage: .swift)

            // Since documentation extensions' filenames have no impact on the URL of pages, there is no need to enforce unique filenames for them.
            // At this point we consider all articles with an H1 containing link a "documentation extension."
            let isDocumentationExtension = (analyzed as? Article)?.title?.child(at: 0) is (any AnyLink)

            if let firstFoundAtURL = references[reference], !isDocumentationExtension {
                let problem = Problem(
                    diagnostic: Diagnostic(
                        source: url,
                        severity: .warning,
                        range: nil,
                        identifier: "org.swift.docc.DuplicateReference",
                        summary: """
                        Redeclaration of '\(firstFoundAtURL.lastPathComponent)'; this file will be skipped
                        """,
                        explanation: """
                        This content was already declared at '\(firstFoundAtURL)'
                        """
                    ),
                    possibleSolutions: []
                )
                diagnosticEngine.emit(problem)
                continue
            }

            if !isDocumentationExtension {
                references[reference] = url
            }

            /*
             Add all topic graph nodes up front before resolution starts, because
             there may be circular linking.
             */
            if let tableOfContents = analyzed as? TutorialTableOfContents {
                let topicGraphNode = TopicGraph.Node(reference: reference, kind: .tutorialTableOfContents, source: .file(url: url), title: tableOfContents.intro.title)
                topicGraph.addNode(topicGraphNode)
                let result = SemanticResult(value: tableOfContents, source: url, topicGraphNode: topicGraphNode)
                tutorialTableOfContentsResults.append(result)
            } else if let tutorial = analyzed as? Tutorial {
                let topicGraphNode = TopicGraph.Node(reference: reference, kind: .tutorial, source: .file(url: url), title: tutorial.title ?? "")
                topicGraph.addNode(topicGraphNode)
                let result = SemanticResult(value: tutorial, source: url, topicGraphNode: topicGraphNode)
                tutorials.append(result)

                insertLandmarks(tutorial.landmarks, from: topicGraphNode, source: url)
            } else if let tutorialArticle = analyzed as? TutorialArticle {
                let topicGraphNode = TopicGraph.Node(reference: reference, kind: .tutorialArticle, source: .file(url: url), title: tutorialArticle.title ?? "")
                topicGraph.addNode(topicGraphNode)
                let result = SemanticResult(value: tutorialArticle, source: url, topicGraphNode: topicGraphNode)
                tutorialArticles.append(result)

                insertLandmarks(tutorialArticle.landmarks, from: topicGraphNode, source: url)
            } else if let article = analyzed as? Article {

                // Here we create a topic graph node with the prepared data but we don't add it to the topic graph just yet
                // because we don't know where in the hierarchy the article belongs, we will add it later when crawling the manual curation via Topics task groups.
                let topicGraphNode = TopicGraph.Node(reference: reference, kind: .article, source: .file(url: url), title: article.title!.plainText)
                let result = SemanticResult(value: article, source: url, topicGraphNode: topicGraphNode)

                // Separate articles that look like documentation extension files from other articles, so that the documentation extension files can be matched up with a symbol.
                // Some links might not resolve in the final documentation hierarchy and we will emit warnings for those later on when we finalize the bundle discovery phase.
                if isDocumentationExtension {
                    documentationExtensions.append(result)

                    // Warn for an incorrect root page metadata directive.
                    if let technologyRoot = result.value.metadata?.technologyRoot {
                        let diagnostic = Diagnostic(source: url, severity: .warning, range: article.metadata?.technologyRoot?.originalMarkup.range, identifier: "org.swift.docc.UnexpectedTechnologyRoot", summary: "Documentation extension files can't become technology roots.")
                        let solutions: [Solution]
                        if let range = technologyRoot.originalMarkup.range {
                            solutions = [
                                Solution(summary: "Remove the TechnologyRoot directive", replacements: [Replacement(range: range, replacement: "")])
                            ]
                        } else {
                            solutions = []
                        }
                        diagnosticEngine.emit(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
                    }
                } else {
                    precondition(uncuratedArticles[result.topicGraphNode.reference] == nil, "Article references are unique.")
                    uncuratedArticles[result.topicGraphNode.reference] = result
                    articles.append(result)
                }
            } else {
                let topLevelDirectives = BlockDirective.topLevelDirectiveNames
                    .map { $0.singleQuoted }
                    .list(finalConjunction: .or)
                let explanation = """
                    File contains unexpected markup at top level. Expected only one of \(topLevelDirectives) directives at the top level
                    """
                let zeroLocation = SourceLocation(line: 1, column: 1, source: nil)
                let diagnostic = Diagnostic(source: url, severity: .warning, range: zeroLocation..<zeroLocation, identifier: "org.swift.docc.UnexpectedTopLevelMarkup", summary: explanation)
                let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
                diagnosticEngine.emit(problem)
            }
        }

        return (tutorialTableOfContentsResults, tutorials, tutorialArticles, articles, documentationExtensions)
    }

    private func insertLandmarks(_ landmarks: some Sequence<any Landmark>, from topicGraphNode: TopicGraph.Node, source url: URL) {
        for landmark in landmarks {
            guard let range = landmark.range else {
                continue
            }

            let landmarkReference = topicGraphNode.reference.withFragment(landmark.title)

            // Graph node: Landmark
            let landmarkTopicGraphNode = TopicGraph.Node(reference: landmarkReference, kind: .onPageLandmark, source: .range(range, url: url), title: landmark.title)
            topicGraph.addNode(landmarkTopicGraphNode)

            // Graph edge: Topic -> Landmark
            topicGraph.addEdge(from: topicGraphNode, to: landmarkTopicGraphNode)

            documentationCache[landmarkReference] = DocumentationNode(reference: landmarkReference, kind: .onPageLandmark, sourceLanguage: .swift, name: .conceptual(title: landmark.title), markup: landmark.markup, semantic: nil)
        }
    }

    /// A lookup of resolved references based on the reference's absolute string.
    private(set) var referenceIndex = [String: ResolvedTopicReference]()

    private func nodeWithInitializedContent(
        reference: ResolvedTopicReference,
        match foundDocumentationExtension: DocumentationContext.SemanticResult<Article>?,
        bundle: DocumentationBundle
    ) -> DocumentationNode {
        guard var updatedNode = documentationCache[reference] else {
            fatalError("A topic reference that has already been resolved should always exist in the cache.")
        }

        // Pull a matched article out of the cache and attach content to the symbol
        updatedNode.initializeSymbolContent(
            documentationExtension: foundDocumentationExtension?.value,
            engine: diagnosticEngine,
            bundle: bundle
        )

        // After merging the documentation extension into the symbol, warn about deprecation summary for non-deprecated symbols.
        if let foundDocumentationExtension,
            foundDocumentationExtension.value.deprecationSummary != nil,
            (updatedNode.semantic as? Symbol)?.isDeprecated == false,
            let articleMarkup = foundDocumentationExtension.value.markup,
            let symbol = updatedNode.unifiedSymbol?.documentedSymbol
        {
            let directive = articleMarkup.children.mapFirst { child -> BlockDirective? in
                guard let directive = child as? BlockDirective, directive.name == DeprecationSummary.directiveName else { return nil }
                return directive
            }
            diagnosticEngine.emit(Problem(diagnostic: Diagnostic(source: foundDocumentationExtension.source, severity: .warning, range: directive?.range, identifier: "org.swift.docc.DeprecationSummaryForAvailableSymbol", summary: "\(symbol.absolutePath.singleQuoted) isn't unconditionally deprecated"), possibleSolutions: []))
        }

        return updatedNode
    }

    /// Creates a topic graph node and a documentation node for the given symbol.
    private func preparedSymbolData(_ symbol: UnifiedSymbolGraph.Symbol, reference: ResolvedTopicReference, module: SymbolGraph.Module, moduleReference: ResolvedTopicReference, fileURL symbolGraphURL: URL?) -> AddSymbolResultWithProblems {
        let documentation = DocumentationNode(reference: reference, unifiedSymbol: symbol, moduleData: module, moduleReference: moduleReference)
        let source: TopicGraph.Node.ContentLocation // TODO: use a list of URLs for the files in a unified graph
        if let symbolGraphURL {
            source = .file(url: symbolGraphURL)
        } else {
            source = .external
        }
        let graphNode = TopicGraph.Node(reference: reference, kind: documentation.kind, source: source, title: symbol.defaultSymbol!.names.title, isVirtual: module.isVirtual)

        return ((reference, symbol.uniqueIdentifier, graphNode, documentation), [])
    }

    /// The result of converting a symbol into a documentation node.
    private typealias AddSymbolResult = (reference: ResolvedTopicReference, preciseIdentifier: String, topicGraphNode: TopicGraph.Node, node: DocumentationNode)
    /// An optional result of converting a symbol into a documentation along with any related problems.
    private typealias AddSymbolResultWithProblems = (AddSymbolResult, problems: [Problem])

    /// Concurrently adds a symbol to the graph, index, and cache, or replaces an existing symbol with the same precise identifier
    /// (for light updates to symbols already in the graph).
    ///
    /// In case an article with a title that matches the symbol link is found in the article cache, it is removed from the cache
    /// and its content is merged with the symbol's metadata and/or documentation before the symbol is finally added to the topic graph.
    ///
    /// ```
    ///            ┌──────────────────┐
    ///            │   Topic Graph    │◀──────────────────────┐
    ///            └──────────────────┘                       │
    ///  ┌──────────────────┐             .───────────.       │
    ///  │   Article Cache  │─────────▶  (MyKit/MyClass)──────┘
    ///  └──────────────────┘             `───────────'       │
    ///                                       Article         │
    ///  ┌──────────────────┐             .───────────.       │
    ///  │   Symbol graph   │─────────▶  (MyKit/MyClass)──────┘
    ///  └──────────────────┘             `───────────'
    ///                                       Symbol
    /// ```
    private func addSymbolsToTopicGraph(symbolGraph: UnifiedSymbolGraph, url: URL?, symbolReferences: [SymbolGraph.Symbol.Identifier: ResolvedTopicReference], moduleReference: ResolvedTopicReference) {
        let symbols = Array(symbolGraph.symbols.values)
        let results: [AddSymbolResultWithProblems] = symbols.concurrentPerform { symbol, results in
            if let selector = symbol.defaultSelector, let module = symbol.modules[selector] {
                guard let reference = symbolReferences[symbol.defaultIdentifier] else {
                    fatalError("Symbol with identifier '\(symbol.uniqueIdentifier)' has no reference. A symbol will always have at least one reference.")
                }

                results.append(preparedSymbolData(
                    symbol,
                    reference: reference,
                    module: module,
                    moduleReference: moduleReference,
                    fileURL: url
                ))
            }
        }
        results.forEach { addPreparedSymbolToContext($0) }
    }

    /// Adds a prepared symbol data including a topic graph node and documentation node to the context.
    private func addPreparedSymbolToContext(_ result: AddSymbolResultWithProblems) {
        let symbolData = result.0
        topicGraph.addNode(symbolData.topicGraphNode)
        documentationCache.add(symbolData.node, reference: symbolData.reference, symbolID: symbolData.preciseIdentifier)

        for anchor in result.0.node.anchorSections {
            nodeAnchorSections[anchor.reference] = anchor
        }

        diagnosticEngine.emit(result.problems)
    }

    /// Loads all graph files from a given `bundle` and merges them together while building the symbol relationships and loading any available markdown documentation for those symbols.
    ///
    /// - Parameter bundle: The bundle to load symbol graph files from.
    /// - Returns: A pair of the references to all loaded modules and the hierarchy of all the loaded symbol's references.
    private func registerSymbols(
        from bundle: DocumentationBundle,
        symbolGraphLoader: SymbolGraphLoader,
        documentationExtensions: [SemanticResult<Article>]
    ) throws {
        // Making sure that we correctly let decoding memory get released, do not remove the autorelease pool.
        try autoreleasepool {
            let signpostHandle = signposter.beginInterval("Register symbols", id: signposter.makeSignpostID())
            defer {
                signposter.endInterval("Register symbols", signpostHandle)
            }

            /// We need only unique relationships so we'll collect them in a set.
            var combinedRelationshipsBySelector = [UnifiedSymbolGraph.Selector: Set<SymbolGraph.Relationship>]()
            /// Also track the unique relationships across all languages and platforms
            var uniqueRelationships = Set<SymbolGraph.Relationship>()
            /// Collect symbols from all symbol graphs.
            var combinedSymbols = [String: UnifiedSymbolGraph.Symbol]()

            var moduleReferences = [String: ResolvedTopicReference]()

            // Build references for all symbols in all of this module's symbol graphs.
            let symbolReferences = signposter.withIntervalSignpost("Disambiguate references") {
                linkResolver.localResolver.referencesForSymbols(in: symbolGraphLoader.unifiedGraphs, bundle: bundle, context: self)
            }

            // Set the index and cache storage capacity to avoid ad-hoc storage resizing.
            documentationCache.reserveCapacity(symbolReferences.count)
            documentLocationMap.reserveCapacity(symbolReferences.count)
            topicGraph.nodes.reserveCapacity(symbolReferences.count)
            topicGraph.edges.reserveCapacity(symbolReferences.count)
            combinedRelationshipsBySelector.reserveCapacity(symbolReferences.count)
            uniqueRelationships.reserveCapacity(symbolReferences.count)
            combinedSymbols.reserveCapacity(symbolReferences.count)

            // Iterate over batches of symbol graphs, each batch describing one module.
            // Each batch contains one or more symbol graph files.
            for (moduleName, unifiedSymbolGraph) in symbolGraphLoader.unifiedGraphs {
                try shouldContinueRegistration()

                let fileURL = symbolGraphLoader.mainModuleURL(forModule: moduleName)

                let moduleInterfaceLanguages: Set<SourceLanguage>
                // FIXME: Update with new SymbolKit API once available.
                // This is a very inefficient way to gather the source languages
                // represented in a symbol graph. Adding a dedicated SymbolKit API is tracked
                // with github.com/swiftlang/swift-docc-symbolkit/issues/32 and rdar://85982095.
                let symbolGraphLanguages = Set(
                    unifiedSymbolGraph.symbols.flatMap(\.value.sourceLanguages)
                )

                // If the symbol graph has no symbols, we cannot determine what languages is it available for,
                // so fall back to Swift.
                moduleInterfaceLanguages = symbolGraphLanguages.isEmpty ? [.swift] : symbolGraphLanguages

                // If it's an existing module, update the interface languages
                moduleReferences[moduleName] = moduleReferences[moduleName]?.addingSourceLanguages(moduleInterfaceLanguages)

                // Import the symbol graph symbols
                let moduleReference: ResolvedTopicReference

                // If it's a repeating module, diff & merge matching declarations.
                if let existingModuleReference = moduleReferences[moduleName] {
                    // This node is known to exist
                    moduleReference = existingModuleReference

                    try mergeSymbolDeclarations(from: unifiedSymbolGraph, references: symbolReferences, moduleReference: moduleReference, fileURL: fileURL)
                } else {
                    guard symbolGraphLoader.hasPrimaryURL(moduleName: moduleName) else { continue }

                    // Create a module symbol
                    let moduleIdentifier = SymbolGraph.Symbol.Identifier(
                        precise: moduleName,
                        interfaceLanguage: moduleInterfaceLanguages.first!.id
                    )

                    // Use the default module kind for this bundle if one was provided,
                    // otherwise fall back to 'Framework'
                    let moduleKindDisplayName = bundle.info.defaultModuleKind ?? "Framework"
                    let moduleSymbol = SymbolGraph.Symbol(
                            identifier: moduleIdentifier,
                            names: SymbolGraph.Symbol.Names(title: moduleName, navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: [moduleName],
                            docComment: nil,
                            accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                            kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .module, displayName: moduleKindDisplayName),
                            mixins: [:])
                    let moduleSymbolReference = SymbolReference(moduleName, interfaceLanguages: moduleInterfaceLanguages, defaultSymbol: moduleSymbol)
                    moduleReference = ResolvedTopicReference(symbolReference: moduleSymbolReference, moduleName: moduleName, bundle: bundle)

                    signposter.withIntervalSignpost("Add symbols to topic graph", id: signposter.makeSignpostID()) {
                        addSymbolsToTopicGraph(symbolGraph: unifiedSymbolGraph, url: fileURL, symbolReferences: symbolReferences, moduleReference: moduleReference)
                    }

                    // For inherited symbols we remove the source docs (if inheriting docs is disabled) before creating their documentation nodes.
                    for (_, relationships) in unifiedSymbolGraph.relationshipsByLanguage {
                        for relationship in relationships {
                            // Check for an origin key.
                            if let sourceOrigin = relationship[mixin: SymbolGraph.Relationship.SourceOrigin.self],
                                // Check if it's a memberOf or implementation relationship.
                                (relationship.kind == .memberOf || relationship.kind == .defaultImplementationOf)
                            {
                                SymbolGraphRelationshipsBuilder.addInheritedDefaultImplementation(
                                    sourceOrigin: sourceOrigin,
                                    inheritedSymbolID: relationship.source,
                                    context: self,
                                    localCache: documentationCache,
                                    moduleName: moduleName
                                )
                            }
                        }
                    }

                    let overloadGroups: [String: Set<String>] =
                    unifiedSymbolGraph.relationshipsByLanguage.values.flatMap({
                        $0.filter { $0.kind == .overloadOf }
                    }).reduce(into: [:], { acc, relationship in
                        acc[relationship.target, default: []].insert(relationship.source)
                    })
                    addOverloadGroupReferences(overloadGroups: overloadGroups)

                    if let rootURL = symbolGraphLoader.mainModuleURL(forModule: moduleName), let rootModule = unifiedSymbolGraph.moduleData[rootURL] {
                        addPreparedSymbolToContext(
                            preparedSymbolData(.init(fromSingleSymbol: moduleSymbol, module: rootModule, isMainGraph: true), reference: moduleReference, module: rootModule, moduleReference: moduleReference, fileURL: fileURL)
                        )
                    }

                    // Add this module to the dictionary of processed modules to keep track of repeat symbol graphs
                    moduleReferences[moduleName] = moduleReference
                }

                // Collect symbols and relationships
                combinedSymbols.merge(unifiedSymbolGraph.symbols, uniquingKeysWith: { $1 })

                for (selector, relationships) in unifiedSymbolGraph.relationshipsByLanguage {
                    combinedRelationshipsBySelector[selector, default: []].formUnion(relationships)
                    uniqueRelationships.formUnion(relationships)
                }

                // Keep track of relationships that refer to symbols that are absent from the symbol graph, so that
                // we can diagnose them.
                combinedRelationshipsBySelector[
                    .init(interfaceLanguage: "unknown", platform: nil),
                    default: []
                ].formUnion(unifiedSymbolGraph.orphanRelationships)
                uniqueRelationships.formUnion(unifiedSymbolGraph.orphanRelationships)
            }

            try shouldContinueRegistration()

            // Only add the symbol mapping now if the path hierarchy based resolver is the main implementation.
            // If it is only used for mismatch checking then we must wait until the documentation cache code path has traversed and updated all the colliding nodes.
            // Otherwise the mappings will save the unmodified references and the hierarchy based resolver won't find the expected parent nodes when resolving links.
            linkResolver.localResolver.addMappingForSymbols(localCache: documentationCache)

            // Track the symbols that have multiple matching documentation extension files for diagnostics.
            var symbolsWithMultipleDocumentationExtensionMatches = [ResolvedTopicReference: [SemanticResult<Article>]]()
            for documentationExtension in documentationExtensions {
                guard let link = documentationExtension.value.title?.child(at: 0) as? (any AnyLink) else {
                    fatalError("An article shouldn't have ended up in the documentation extension list unless its title was a link. File: \(documentationExtension.source.absoluteString.singleQuoted)")
                }

                guard let destination = link.destination else {
                    let diagnostic = Diagnostic(source: documentationExtension.source, severity: .warning, range: link.range, identifier: "org.swift.docc.emptyLinkDestination", summary: """
                        Documentation extension with an empty link doesn't correspond to any symbol.
                        """, explanation: nil, notes: [])
                    diagnosticEngine.emit(Problem(diagnostic: diagnostic))
                    continue
                }
                guard let url = ValidatedURL(parsingAuthoredLink: destination) else {
                    let diagnostic = Diagnostic(source: documentationExtension.source, severity: .warning, range: link.range, identifier: "org.swift.docc.invalidLinkDestination", summary: """
                        \(destination.singleQuoted) is not a valid RFC 3986 URL.
                        """, explanation: nil, notes: [])
                    diagnosticEngine.emit(Problem(diagnostic: diagnostic))
                    continue
                }

                // FIXME: Resolve the link relative to the module https://github.com/swiftlang/swift-docc/issues/516
                let reference = TopicReference.unresolved(.init(topicURL: url))
                switch resolve(reference, in: bundle.rootReference, fromSymbolLink: true) {
                case .success(let resolved):
                    if let existing = uncuratedDocumentationExtensions[resolved] {
                        if symbolsWithMultipleDocumentationExtensionMatches[resolved] == nil {
                            symbolsWithMultipleDocumentationExtensionMatches[resolved] = [existing]
                        }
                        symbolsWithMultipleDocumentationExtensionMatches[resolved]!.append(documentationExtension)
                    } else {
                        uncuratedDocumentationExtensions[resolved] = documentationExtension
                    }
                case .failure(_, let errorInfo):
                    guard !configuration.convertServiceConfiguration.considerDocumentationExtensionsThatDoNotMatchSymbolsAsResolved else {
                        // The ConvertService relies on old implementation detail where documentation extension files were always considered "resolved" even when they didn't match a symbol.
                        //
                        // Don't rely on this behavior for new functionality. The behavior will be removed once we have a new solution to meets the needs of the ConvertService. (rdar://108563483)
                        // https://github.com/swiftlang/swift-docc/issues/567
                        //
                        // The process that interacts with the convert service is responsible for:
                        // - Distinguishing between documentation extension files that match symbols and documentation extension files that don't match symbols.
                        // - Resolving symbol link in a way that match the behavior of regular documentation builds.
                        // the process that interacts with the convert service is responsible for maintaining it's own link resolutions implementation to match the behavior of a regular build.
                        // - Diagnosing documentation extension files that don't match any symbols.
                        let reference = documentationExtension.topicGraphNode.reference

                        let symbolPath = NodeURLGenerator.Path.documentation(path: url.components.path).stringValue
                        let symbolReference = ResolvedTopicReference(
                            bundleID: reference.bundleID,
                            path: symbolPath,
                            fragment: nil,
                            sourceLanguages: reference.sourceLanguages
                        )

                        if let existing = uncuratedDocumentationExtensions[symbolReference] {
                            if symbolsWithMultipleDocumentationExtensionMatches[symbolReference] == nil {
                                symbolsWithMultipleDocumentationExtensionMatches[symbolReference] = [existing]
                            }
                            symbolsWithMultipleDocumentationExtensionMatches[symbolReference]!.append(documentationExtension)
                        } else {
                            uncuratedDocumentationExtensions[symbolReference] = documentationExtension
                        }
                        continue
                    }

                    // Present a diagnostic specific to documentation extension files but get the solutions and notes from the general unresolved link problem.
                    let unresolvedLinkProblem = unresolvedReferenceProblem(source: documentationExtension.source, range: link.range, severity: .warning, uncuratedArticleMatch: nil, errorInfo: errorInfo, fromSymbolLink: link is SymbolLink)

                    diagnosticEngine.emit(
                        Problem(
                            diagnostic: Diagnostic(source: documentationExtension.source, severity: .warning, range: link.range, identifier: "org.swift.docc.SymbolUnmatched", summary: "No symbol matched \(destination.singleQuoted). \(errorInfo.message).", notes: unresolvedLinkProblem.diagnostic.notes),
                            possibleSolutions: unresolvedLinkProblem.possibleSolutions
                        )
                    )
                }
            }
            emitWarningsForSymbolsMatchedInMultipleDocumentationExtensions(with: symbolsWithMultipleDocumentationExtensionMatches)
            symbolsWithMultipleDocumentationExtensionMatches.removeAll()

            // Create inherited API collections
            try GeneratedDocumentationTopics.createInheritedSymbolsAPICollections(
                relationships: uniqueRelationships,
                context: self,
                bundle: bundle
            )

            // Parse and prepare the nodes' content concurrently.
            let updatedNodes = signposter.withIntervalSignpost("Parse symbol markup", id: signposter.makeSignpostID()) {
                Array(documentationCache.symbolReferences).concurrentMap { finalReference in
                    // Match the symbol's documentation extension and initialize the node content.
                    let match = uncuratedDocumentationExtensions[finalReference]
                    let updatedNode = nodeWithInitializedContent(
                        reference: finalReference,
                        match: match,
                        bundle: bundle
                    )

                    return ((
                        node: updatedNode,
                        matchedArticleURL: match?.source
                    ))
                }
            }

            // Update cache with up-to-date nodes
            for (updatedNode, matchedArticleURL) in updatedNodes {
                let reference = updatedNode.reference
                // Add node's anchors to index
                for anchor in updatedNode.anchorSections {
                    nodeAnchorSections[anchor.reference] = anchor
                }
                // Update cache with the updated node value
                if let symbol = updatedNode.symbol {
                    // If the node was a symbol, add both the reference and the symbol ID
                    documentationCache.add(updatedNode, reference: reference, symbolID: symbol.identifier.precise)
                } else {
                    documentationCache[reference] = updatedNode
                }
                if let url = matchedArticleURL {
                    documentLocationMap[url] = reference
                }
                // Remove the matched article
                uncuratedDocumentationExtensions.removeValue(forKey: reference)
            }

            // Resolve any external references first
            preResolveExternalLinks(references: Array(moduleReferences.values) + combinedSymbols.keys.compactMap({ documentationCache.reference(symbolID: $0) }), localBundleID: bundle.id)

            // Look up and add symbols that are _referenced_ in the symbol graph but don't exist in the symbol graph.
            try resolveExternalSymbols(in: combinedSymbols, relationships: combinedRelationshipsBySelector)

            for (selector, relationships) in combinedRelationshipsBySelector {
                // Build relationships in the completed graph
                buildRelationships(relationships, selector: selector, bundle: bundle)
                // Merge into target symbols the member symbols that get rendered on the same page as target.
                populateOnPageMemberRelationships(from: relationships, selector: selector)
            }
        }
    }

    private func shouldContinueRegistration() throws {
        try Task.checkCancellation()
        guard isRegistrationEnabled.sync({ $0 }) else {
            throw ContextError.registrationDisabled
        }
    }

    /// Builds in-memory relationships between symbols based on the relationship information in a given symbol graph file.
    ///
    /// - Parameters:
    ///   - symbolGraph: The symbol graph whose symbols to add in-memory relationships to.
    ///   - bundle: The bundle that the symbols belong to.
    ///   - problems: A mutable collection of problems to update with any problem encountered while building symbol relationships.
    ///
    /// ## See Also
    /// - ``SymbolGraphRelationshipsBuilder``
    func buildRelationships(
        _ relationships: Set<SymbolGraph.Relationship>,
        selector: UnifiedSymbolGraph.Selector,
        bundle: DocumentationBundle
    ) {
        // Find all of the relationships which refer to an extended module.
        let extendedModuleRelationships = ExtendedTypeFormatTransformation.collapsedExtendedModuleRelationships(from: relationships)

        for edge in relationships {
            switch edge.kind {
            case .memberOf, .optionalMemberOf:
                // Add a "Self is" constraint for members of protocol extensions that
                // extend a protocol from extended modules.
                SymbolGraphRelationshipsBuilder.addProtocolExtensionMemberConstraint(
                    edge: edge,
                    extendedModuleRelationships: extendedModuleRelationships,
                    localCache: documentationCache
                )
            case .conformsTo:
                // Build conformant type <-> protocol relationships
                SymbolGraphRelationshipsBuilder.addConformanceRelationship(
                    edge: edge,
                    selector: selector,
                    in: bundle,
                    localCache: documentationCache,
                    externalCache: externalCache,
                    engine: diagnosticEngine
                )
            case .defaultImplementationOf:
                // Build implementation <-> protocol requirement relationships.
                SymbolGraphRelationshipsBuilder.addImplementationRelationship(
                    edge: edge,
                    selector: selector,
                    in: bundle,
                    context: self,
                    localCache: documentationCache,
                    engine: diagnosticEngine
                )
            case .inheritsFrom:
                // Build ancestor <-> offspring relationships.
                SymbolGraphRelationshipsBuilder.addInheritanceRelationship(
                    edge: edge,
                    selector: selector,
                    in: bundle,
                    localCache: documentationCache,
                    externalCache: externalCache,
                    engine: diagnosticEngine
                )
            case .requirementOf:
                // Build required member -> protocol relationships.
                SymbolGraphRelationshipsBuilder.addRequirementRelationship(
                    edge: edge,
                    localCache: documentationCache,
                    engine: diagnosticEngine
                )
            case .optionalRequirementOf:
                // Build optional required member -> protocol relationships.
                SymbolGraphRelationshipsBuilder.addOptionalRequirementRelationship(
                    edge: edge,
                    localCache: documentationCache,
                    engine: diagnosticEngine
                )
            case .overloadOf:
                // Build overload <-> overloadGroup relationships.
                SymbolGraphRelationshipsBuilder.addOverloadRelationship(
                    edge: edge,
                    context: self,
                    localCache: documentationCache,
                    engine: diagnosticEngine
                )
            default:
                break
            }
        }
    }

    /// Identifies all the dictionary keys and records them in the appropriate target dictionaries.
    private func populateOnPageMemberRelationships(
        from relationships: Set<SymbolGraph.Relationship>,
        selector: UnifiedSymbolGraph.Selector
    ) {
        var keysByTarget = [String: [DictionaryKey]]()
        var parametersByTarget = [String: [HTTPParameter]]()
        var bodyByTarget = [String: HTTPBody]()
        var bodyParametersByTarget = [String: [HTTPParameter]]()
        var responsesByTarget = [String: [HTTPResponse]]()

        for edge in relationships {
            if edge.kind == .memberOf || edge.kind == .optionalMemberOf {
                if let source = documentationCache[edge.source], let target = documentationCache[edge.target],
                   let sourceSymbol = source.symbol
                {
                    switch (source.kind, target.kind) {
                    case (.dictionaryKey, .dictionary):
                        let dictionaryKey = DictionaryKey(name: sourceSymbol.names.title, contents: [], symbol: sourceSymbol, required: (edge.kind == .memberOf))
                        if keysByTarget[edge.target] == nil {
                            keysByTarget[edge.target] = [dictionaryKey]
                        } else {
                            keysByTarget[edge.target]?.append(dictionaryKey)
                        }
                    case (.httpParameter, .httpRequest):
                        let parameter = HTTPParameter(name: sourceSymbol.names.title, source: (sourceSymbol.httpParameterSource ?? "query"), contents: [], symbol: sourceSymbol, required: (edge.kind == .memberOf))
                        if parametersByTarget[edge.target] == nil {
                            parametersByTarget[edge.target] = [parameter]
                        } else {
                            parametersByTarget[edge.target]?.append(parameter)
                        }
                    case (.httpBody, .httpRequest):
                        let body = HTTPBody(mediaType: sourceSymbol.httpMediaType, contents: [], symbol: sourceSymbol)
                        bodyByTarget[edge.target] = body
                    case (.httpParameter, .httpBody):
                        let parameter = HTTPParameter(name: sourceSymbol.names.title, source: "body", contents: [], symbol: sourceSymbol, required: (edge.kind == .memberOf))
                        if bodyParametersByTarget[edge.target] == nil {
                            bodyParametersByTarget[edge.target] = [parameter]
                        } else {
                            bodyParametersByTarget[edge.target]?.append(parameter)
                        }
                    case (.httpResponse, .httpRequest):
                        let statusParts = sourceSymbol.names.title.split(separator: " ", maxSplits: 1)
                        let statusCode = UInt(statusParts[0]) ?? 0
                        let reason = statusParts.count > 1 ? String(statusParts[1]) : nil
                        let response = HTTPResponse(statusCode: statusCode, reason: reason, mediaType: sourceSymbol.httpMediaType, contents: [], symbol: sourceSymbol)
                        if responsesByTarget[edge.target] == nil {
                            responsesByTarget[edge.target] = [response]
                        } else {
                            responsesByTarget[edge.target]?.append(response)
                        }
                    case (_, _):
                        continue
                    }
                }
            }
        }

        // Merge in all the dictionary keys for each target into their section variants.
        keysByTarget.forEach { targetIdentifier, keys in
            let target = documentationCache[targetIdentifier]
            if let semantic = target?.semantic as? Symbol {
                let keys = keys.sorted(by: \.name)
                if semantic.dictionaryKeysSection == nil {
                    semantic.dictionaryKeysSection = DictionaryKeysSection(dictionaryKeys: keys)
                } else {
                    semantic.dictionaryKeysSection?.mergeDictionaryKeys(keys)
                }
            }
        }

        // Merge in all the parameters for each target into their section variants.
        parametersByTarget.forEach { targetIdentifier, parameters in
            let target = documentationCache[targetIdentifier]
            if let semantic = target?.semantic as? Symbol {
                let parameters = parameters.sorted(by: \.name)
                if semantic.httpParametersSection == nil {
                    semantic.httpParametersSection = HTTPParametersSection(parameters: parameters)
                } else {
                    semantic.httpParametersSection?.mergeParameters(parameters)
                }
            }
        }

        // Merge in the body for each target into their section variants.
        bodyByTarget.forEach { targetIdentifier, body in
            let target = documentationCache[targetIdentifier]
            if let semantic = target?.semantic as? Symbol {
                // Add any body parameters to existing body record
                var localBody = body
                if let identifier = body.symbol?.identifier.precise, let bodyParameters = bodyParametersByTarget[identifier] {
                    localBody.parameters = bodyParameters.sorted(by: \.name)
                }
                if semantic.httpBodySection == nil {
                    semantic.httpBodySection = HTTPBodySection(body: localBody)
                } else {
                    semantic.httpBodySection?.mergeBody(localBody)
                }
            }
        }

        // Merge in all the responses for each target into their section variants.
        responsesByTarget.forEach { targetIdentifier, responses in
            let target = documentationCache[targetIdentifier]
            if let semantic = target?.semantic as? Symbol {
                let responses = responses.sorted(by: \.statusCode)
                if semantic.httpResponsesSection == nil {
                    semantic.httpResponsesSection = HTTPResponsesSection(responses: responses)
                } else {
                    semantic.httpResponsesSection?.mergeResponses(responses)
                }
            }
        }
    }

    /// Look up and add symbols that are _referenced_ in the symbol graph but don't exist in the symbol graph, using an `globalExternalSymbolResolver` (if not `nil`).
    func resolveExternalSymbols(
        in symbols: [String: UnifiedSymbolGraph.Symbol],
        relationships: [UnifiedSymbolGraph.Selector: Set<SymbolGraph.Relationship>]
    ) throws {
        if configuration.externalDocumentationConfiguration.globalSymbolResolver == nil, linkResolver.externalResolvers.isEmpty {
            // Context has no mechanism for resolving external symbol links. No reason to gather any symbols to resolve.
            return
        }

        // Gather all the references to symbols that don't exist in the combined symbol graph file and add then by resolving these "external" symbols.
        var symbolsToResolve = Set<String>()

        // Add all the symbols that are the target of a relationship. These could for example be protocols that are being conformed to,
        // classes that are being subclassed, or methods that are being overridden.
        for (_, relationships) in relationships {
            for edge in relationships where documentationCache[edge.target] == nil {
                symbolsToResolve.insert(edge.target)
            }
        }

        // Add all the types that are referenced in a declaration. These could for example be the type of an argument or return value.
        for symbol in symbols.values {
            guard let defaultSymbol = symbol.defaultSymbol, let declaration = defaultSymbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self] else {
                continue
            }
            for fragment in declaration.declarationFragments {
                guard let preciseIdentifier = fragment.preciseIdentifier, documentationCache[preciseIdentifier] == nil else {
                    continue
                }
                symbolsToResolve.insert(preciseIdentifier)
            }
        }

        // TODO: When the symbol graph includes the precise identifiers for conditional availability, those symbols should also be resolved (rdar://63768609).

        func resolveSymbol(symbolID: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
            if let globalResult = configuration.externalDocumentationConfiguration.globalSymbolResolver?.symbolReferenceAndEntity(withPreciseIdentifier: symbolID) {
                return globalResult
            }
            for externalResolver in linkResolver.externalResolvers.values {
                if let result = externalResolver.symbolReferenceAndEntity(symbolID: symbolID) {
                    return result
                }
            }
            return nil
        }

        // Resolve all the collected symbol identifiers and add them do the topic graph.
        for symbolID in symbolsToResolve {
            if let (reference, entity) = resolveSymbol(symbolID: symbolID) {
                externalCache.add(entity, reference: reference, symbolID: symbolID)
            }
            // It's expected that some symbols won't resolve.
            // The build doesn't necessarily include all documentation dependencies that appear in declarations, conformances, etc.
        }
    }

    /// When building multi-platform documentation symbols might have more than one declaration
    /// depending on variances in their implementation across platforms (e.g. use `NSPoint` vs `CGPoint` parameter in a method).
    /// This method finds matching symbols between graphs and merges their declarations in case there are differences.
    func mergeSymbolDeclarations(from otherSymbolGraph: UnifiedSymbolGraph, references: [SymbolGraph.Symbol.Identifier: ResolvedTopicReference], moduleReference: ResolvedTopicReference, fileURL otherSymbolGraphURL: URL?) throws {
        let mergeError = Synchronized<(any Error)?>(nil)

        let results: [AddSymbolResultWithProblems] = Array(otherSymbolGraph.symbols.values).concurrentPerform { symbol, result in
            guard let defaultSymbol = symbol.defaultSymbol, let swiftSelector = symbol.defaultSelector, let module = symbol.modules[swiftSelector] else {
                fatalError("""
                    Only Swift symbols are currently supported. \
                    This initializer is only called with symbols from the symbol graph, which currently only supports Swift.
                    """
                )
            }
            guard defaultSymbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self] != nil else {
                diagnosticEngine.emit(Problem(diagnostic: Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.SymbolDeclarationNotFound", summary: "Symbol with identifier '\(symbol.uniqueIdentifier)' has no declaration"), possibleSolutions: []))
                return
            }

            guard let existingNode = documentationCache[symbol.uniqueIdentifier], existingNode.semantic is Symbol else {
                // New symbols that didn't exist in the previous graphs should be added.
                guard let reference = references[symbol.defaultIdentifier] else {
                    fatalError("Symbol with identifier '\(symbol.uniqueIdentifier)' has no reference. A symbol will always have at least one reference.")
                }

                result.append(preparedSymbolData(symbol, reference: reference, module: module, moduleReference: moduleReference, fileURL: otherSymbolGraphURL))
                return
            }

            do {
                // It's safe to force unwrap since we validated the data above.
                // We update the node in place so avoid copying the data around.
                try (existingNode.semantic as! Symbol).mergeDeclarations(unifiedSymbol: symbol)
            } catch {
                // Invalid input data, throw the error.
                mergeError.sync({
                    if $0 == nil { $0 = error }
                })
            }
        }

        // If there was an invalid input error re-throw it.
        if let error = mergeError.sync({ $0 }) {
            throw error
        }

        // Add any new symbols to the documentation cache.
        results.forEach { addPreparedSymbolToContext($0) }
    }

    private static let supportedImageExtensions: Set<String> = ["png", "jpg", "jpeg", "svg", "gif"]
    private static let supportedVideoExtensions: Set<String> = ["mov", "mp4"]

    // TODO: Move this functionality to ``DocumentationBundleFileTypes`` (rdar://68156425).

    /// A type of asset.
    public enum AssetType: CustomStringConvertible {
        /// An image asset.
        case image
        /// A video asset.
        case video

        public var description: String {
            switch self {
            case .image:
                return "Image"
            case .video:
                return "Video"
            }
        }
    }

    /// Checks if a given `fileExtension` is supported as a `type` of asset.
    ///
    /// - Parameters:
    ///   - fileExtension: The file extension to check.
    ///   - type: The type of asset to check if the `fileExtension` is supported for.
    /// - Returns: Whether or not the file extension is supported for the given type of asset.
    public static func isFileExtension(_ fileExtension: String, supported type: AssetType) -> Bool {
        let fileExtension = fileExtension.lowercased()
        switch type {
            case .image: return supportedImageExtensions.contains(fileExtension)
            case .video: return supportedVideoExtensions.contains(fileExtension)
        }
    }

    private func registerMiscResources(from bundle: DocumentationBundle) throws {
        let miscResources = Set(bundle.miscResourceURLs)
        try assetManagers[bundle.id, default: DataAssetManager()].register(data: miscResources)
    }

    private func registeredAssets(withExtensions extensions: Set<String>? = nil, inContexts contexts: [DataAsset.Context] = DataAsset.Context.allCases, forBundleID bundleID: DocumentationBundle.Identifier) -> [DataAsset] {
        guard let resources = assetManagers[bundleID]?.storage.values else {
            return []
        }
        return resources.filter { dataAsset in
            // Filter by file extension.
            if let extensions {
                let fileExtensions = dataAsset.variants.values.map { $0.pathExtension.lowercased() }
                guard !extensions.intersection(fileExtensions).isEmpty else {
                    return false
                }
            }
            // Filter by context.
            return contexts.contains(dataAsset.context)
        }
    }

    /// Returns a list of all the image assets that registered for a given `bundleIdentifier`.
    ///
    /// - Parameter bundleID: The identifier of the bundle to return image assets for.
    /// - Returns: A list of all the image assets for the given bundle.
    public func registeredImageAssets(for bundleID: DocumentationBundle.Identifier) -> [DataAsset] {
        registeredAssets(withExtensions: DocumentationContext.supportedImageExtensions, forBundleID: bundleID)
    }

    @available(*, deprecated, renamed: "registeredImageAssets(for:)", message: "registeredImageAssets(for:)' instead. This deprecated API will be removed after 6.2 is released")
    public func registeredImageAssets(forBundleID bundleIdentifier: BundleIdentifier) -> [DataAsset] {
        registeredImageAssets(for: DocumentationBundle.Identifier(rawValue: bundleIdentifier))
    }

    /// Returns a list of all the video assets that registered for a given `bundleIdentifier`.
    ///
    /// - Parameter bundleID: The identifier of the bundle to return video assets for.
    /// - Returns: A list of all the video assets for the given bundle.
    public func registeredVideoAssets(for bundleID: DocumentationBundle.Identifier) -> [DataAsset] {
        registeredAssets(withExtensions: DocumentationContext.supportedVideoExtensions, forBundleID: bundleID)
    }

    @available(*, deprecated, renamed: "registeredVideoAssets(for:)", message: "registeredImageAssets(for:)' instead. This deprecated API will be removed after 6.2 is released")
    public func registeredVideoAssets(forBundleID bundleIdentifier: BundleIdentifier) -> [DataAsset] {
        registeredVideoAssets(for: DocumentationBundle.Identifier(rawValue: bundleIdentifier))
    }

    /// Returns a list of all the download assets that registered for a given `bundleIdentifier`.
    ///
    /// - Parameter bundleID: The identifier of the bundle to return download assets for.
    /// - Returns: A list of all the download assets for the given bundle.
    public func registeredDownloadsAssets(for bundleID: DocumentationBundle.Identifier) -> [DataAsset] {
        registeredAssets(inContexts: [DataAsset.Context.download], forBundleID: bundleID)
    }

    @available(*, deprecated, renamed: "registeredDownloadsAssets(for:)", message: "registeredDownloadsAssets(for:)' instead. This deprecated API will be removed after 6.2 is released")
    public func registeredDownloadsAssets(forBundleID bundleIdentifier: BundleIdentifier) -> [DataAsset] {
        registeredDownloadsAssets(for: DocumentationBundle.Identifier(rawValue: bundleIdentifier))
    }

    typealias Articles = [DocumentationContext.SemanticResult<Article>]
    private typealias ArticlesTuple = (articles: Articles, rootPageArticles: Articles)

    private func splitArticles(_ articles: Articles) -> ArticlesTuple {
        return articles.reduce(into: ArticlesTuple(articles: [], rootPageArticles: [])) { result, article in
            if article.value.metadata?.technologyRoot != nil {
                result.rootPageArticles.append(article)
            } else {
                result.articles.append(article)
            }
        }
    }

    private func registerRootPages(from articles: Articles, in bundle: DocumentationBundle) {
        // Create a root leaf node for all root page articles
        for article in articles {
            // Create the documentation data
            guard let (documentation, title) = DocumentationContext.documentationNodeAndTitle(for: article, kind: .collection, in: bundle) else { continue }
            let reference = documentation.reference

            // Create the documentation node
            documentLocationMap[article.source] = reference
            let topicGraphKind = DocumentationNode.Kind.module
            let graphNode = TopicGraph.Node(reference: reference, kind: topicGraphKind, source: .file(url: article.source), title: title)
            topicGraph.addNode(graphNode)
            documentationCache[reference] = documentation

            linkResolver.localResolver.addRootArticle(article, anchorSections: documentation.anchorSections)
            for anchor in documentation.anchorSections {
                nodeAnchorSections[anchor.reference] = anchor
            }

            // Remove the article from the context
            uncuratedArticles.removeValue(forKey: article.topicGraphNode.reference)
        }
    }

    /// When `true` bundle registration will be cancelled asap.
    private var isRegistrationEnabled = Synchronized<Bool>(true)

    /// Enables or disables bundle registration.
    ///
    /// When given `false` the context will try to cancel as quick as possible
    /// any ongoing bundle registrations.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    public func setRegistrationEnabled(_ value: Bool) {
        isRegistrationEnabled.sync({ $0 = value })
    }

    /// Adds articles that are not root pages to the documentation cache.
    ///
    /// This method adds all of the `articles` to the documentation cache and inserts a node representing
    /// the article into the topic graph.
    ///
    /// > Important: `articles` must not be root pages.
    ///
    /// - Parameters:
    ///   - articles: Articles to register with the documentation cache.
    ///   - bundle: The bundle containing the articles.
    /// - Returns: The articles that were registered, with their topic graph node updated to what's been added to the topic graph.
    private func registerArticles(
        _ articles: DocumentationContext.Articles,
        in bundle: DocumentationBundle
    ) -> DocumentationContext.Articles {
        articles.map { article in
            guard let (documentation, title) = DocumentationContext.documentationNodeAndTitle(
                for: article,
                // By default, articles are available in the languages the module that's being documented
                // is available in. It's possible to override that behavior using the `@SupportedLanguage`
                // directive though; see its documentation for more details.
                availableSourceLanguages: soleRootModuleReference.map { sourceLanguages(for: $0) },
                kind: .article,
                in: bundle
            ) else {
                return article
            }
            let reference = documentation.reference

            documentationCache[reference] = documentation

            documentLocationMap[article.source] = reference
            let graphNode = TopicGraph.Node(reference: reference, kind: .article, source: .file(url: article.source), title: title)
            topicGraph.addNode(graphNode)

            linkResolver.localResolver.addArticle(article, anchorSections: documentation.anchorSections)
            for anchor in documentation.anchorSections {
                nodeAnchorSections[anchor.reference] = anchor
            }

            var article = article
            // Update the article's topic graph node with the one we just added to the topic graph.
            article.topicGraphNode = graphNode
            return article
        }
    }

    /// Registers a synthesized root page for a catalog with only non-root articles.
    ///
    /// If the catalog only has one article or has an article with the same name as the catalog itself, that article is turned into the root page instead of creating a new article.
    ///
    /// - Parameters:
    ///   - articles: On input, a list of articles. If an article is used as a root it is removed from this list.
    ///   - bundle: The bundle containing the articles.
    private func synthesizeArticleOnlyRootPage(articles: inout [DocumentationContext.SemanticResult<Article>], bundle: DocumentationBundle) {
        let title = bundle.displayName

        // An inner helper function to register a new root node from an article
        func registerAsNewRootNode(_ articleResult: SemanticResult<Article>) {
            uncuratedArticles.removeValue(forKey: articleResult.topicGraphNode.reference)
            let title = articleResult.source.deletingPathExtension().lastPathComponent
            // Create a new root-looking reference
            let reference = ResolvedTopicReference(
                bundleID: bundle.id,
                path: NodeURLGenerator.Path.documentation(path: title).stringValue,
                sourceLanguages: [DocumentationContext.defaultLanguage(in: nil /* article-only content has no source language information */)]
            )
            // Add the technology root to the article's metadata
            let metadataMarkup: BlockDirective
            if let markup = articleResult.value.metadata?.originalMarkup as? BlockDirective {
                assert(!markup.children.contains(where: { ($0 as? BlockDirective)?.name == "TechnologyRoot" }),
                       "Nothing should try to synthesize a root page if there's already an explicit authored root page")
                metadataMarkup = markup.withUncheckedChildren(
                    markup.children + [BlockDirective(name: "TechnologyRoot", children: [])]
                ) as! BlockDirective
            } else {
                metadataMarkup = BlockDirective(name: "Metadata", children: [
                    BlockDirective(name: "TechnologyRoot", children: [])
                ])
            }
            let article = Article(
                markup: articleResult.value.markup,
                metadata: Metadata(from: metadataMarkup, for: bundle),
                redirects: articleResult.value.redirects,
                options: articleResult.value.options
            )

            let graphNode = TopicGraph.Node(reference: reference, kind: .module, source: articleResult.topicGraphNode.source, title: title)
            registerRootPages(from: [.init(value: article, source: articleResult.source, topicGraphNode: graphNode)], in: bundle)
        }

        if articles.count == 1 {
            // This catalog only has one article, so we make that the root.
            registerAsNewRootNode(articles.removeFirst())
        } else if let nameMatchIndex = articles.firstIndex(where: { $0.source.deletingPathExtension().lastPathComponent == title }) {
            // This catalog has an article with the same name as the catalog itself, so we make that the root.
            registerAsNewRootNode(articles.remove(at: nameMatchIndex))
        } else {
            // There's no particular article to make into the root. Instead, create a new minimal root page.
            let path = NodeURLGenerator.Path.documentation(path: title).stringValue
            let sourceLanguage = DocumentationContext.defaultLanguage(in: [])

            let reference = ResolvedTopicReference(bundleID: bundle.id, path: path, sourceLanguages: [sourceLanguage])

            let graphNode = TopicGraph.Node(reference: reference, kind: .module, source: .external, title: title)
            topicGraph.addNode(graphNode)

            // Build up the "full" markup for an empty technology root article
            let metadataDirectiveMarkup = BlockDirective(name: "Metadata", children: [
                BlockDirective(name: "TechnologyRoot", children: [])
            ])
            let markup = Document(
                Heading(level: 1, Text(title)),
                metadataDirectiveMarkup
            )
            let metadata = Metadata(from: metadataDirectiveMarkup, for: bundle)
            let article = Article(markup: markup, metadata: metadata, redirects: nil, options: [:])
            let documentationNode = DocumentationNode(
                reference: reference,
                kind: .collection,
                sourceLanguage: sourceLanguage,
                availableSourceLanguages: [sourceLanguage],
                name: .conceptual(title: title),
                markup: markup,
                semantic: article
            )
            documentationCache[reference] = documentationNode
        }
    }

    /// Creates a documentation node and title for the given article semantic result.
    ///
    /// - Parameters:
    ///   - article: The article that will be used to create the returned documentation node.
    ///   - kind: The kind that should be used to create the returned documentation node.
    ///   - bundle: The documentation bundle this article belongs to.
    /// - Returns: A documentation node and title for the given article semantic result.
    static func documentationNodeAndTitle(
        for article: DocumentationContext.SemanticResult<Article>,
        availableSourceLanguages: Set<SourceLanguage>? = nil,
        kind: DocumentationNode.Kind,
        in bundle: DocumentationBundle
    ) -> (node: DocumentationNode, title: String)? {
        guard let articleMarkup = article.value.markup else {
            return nil
        }

        let path = NodeURLGenerator.pathForSemantic(article.value, source: article.source, bundle: bundle)

        // Use the languages specified by the `@SupportedLanguage` directives if present.
        let availableSourceLanguages = article.value
            .metadata
            .flatMap { metadata in
                let languages = Set(
                    metadata.supportedLanguages
                        .map(\.language)
                )

                return languages.isEmpty ? nil : languages
            }
        ?? availableSourceLanguages

        // If available source languages are provided and it contains Swift, use Swift as the default language of
        // the article.
        let defaultSourceLanguage = defaultLanguage(in: availableSourceLanguages)

        let reference = ResolvedTopicReference(
            bundleID: bundle.id,
            path: path,
            sourceLanguages: availableSourceLanguages
                // FIXME: Pages in article-only catalogs should not be inferred as "Swift" as a fallback
                // (github.com/swiftlang/swift-docc/issues/240).
                ?? [.swift]
        )

        let title = article.topicGraphNode.title

        let documentationNode = DocumentationNode(
            reference: reference,
            kind: kind,
            sourceLanguage: defaultSourceLanguage,
            availableSourceLanguages: availableSourceLanguages,
            name: .conceptual(title: title),
            markup: articleMarkup,
            semantic: article.value
        )

        return (documentationNode, title)
    }

    /// Curates articles under the root module.
    ///
    /// This method creates a new task group under the root page containing references to all of the articles
    /// in the bundle that haven't been manually curated.
    ///
    /// - Parameters:
    ///   - otherArticles: Non-root articles to curate.
    ///   - rootNode: The node that will serve as the source of any topic graph edges created by this method.
    /// - Throws: If looking up a `DocumentationNode` for the root module reference fails.
    /// - Returns: An array of resolved references to the articles that were automatically curated.
    private func autoCurateArticles(_ otherArticles: DocumentationContext.Articles, startingFrom rootNode: TopicGraph.Node) throws -> [ResolvedTopicReference] {
        let articlesToAutoCurate = otherArticles.filter { article in
            let reference = article.topicGraphNode.reference
            return topicGraph.edges[reference] == nil && topicGraph.reverseEdges[reference] == nil
        }
        guard !articlesToAutoCurate.isEmpty else {
            return []
        }

        for article in articlesToAutoCurate {
            topicGraph.addEdge(from: rootNode, to: article.topicGraphNode)
            uncuratedArticles.removeValue(forKey: article.topicGraphNode.reference)
        }

        let articleReferences = articlesToAutoCurate.map(\.topicGraphNode.reference)
        let automaticTaskGroup = AutomaticTaskGroupSection(
            title: "Articles",
            references: articleReferences,
            renderPositionPreference: .top
        )

        let node = try entity(with: rootNode.reference)

        // If the node we're automatically curating the article under is a symbol, automatically curate the article
        // for each language it's available in.
        if let symbol = node.semantic as? Symbol {
            for sourceLanguage in node.availableSourceLanguages {
                symbol.automaticTaskGroupsVariants[.init(interfaceLanguage: sourceLanguage.id)] = [automaticTaskGroup]
            }
        } else if var taskGroupProviding = node.semantic as? (any AutomaticTaskGroupsProviding) {
            taskGroupProviding.automaticTaskGroups = [automaticTaskGroup]
        }

        return articleReferences
    }

    /**
     Register a documentation bundle with this context.
     */
    private func register(_ bundle: DocumentationBundle) throws {
        try shouldContinueRegistration()

        let currentFeatureFlags: FeatureFlags?
        if let bundleFlags = bundle.info.featureFlags {
            currentFeatureFlags = FeatureFlags.current
            FeatureFlags.current.loadFlagsFromBundle(bundleFlags)

            for unknownFeatureFlag in bundleFlags.unknownFeatureFlags {
                let suggestions = NearMiss.bestMatches(
                    for: DocumentationBundle.Info.BundleFeatureFlags.CodingKeys.allCases.map({ $0.stringValue }),
                    against: unknownFeatureFlag)
                var summary: String = "Unknown feature flag in Info.plist: \(unknownFeatureFlag.singleQuoted)"
                if !suggestions.isEmpty {
                    summary += ". Possible suggestions: \(suggestions.map(\.singleQuoted).joined(separator: ", "))"
                }
                diagnosticEngine.emit(.init(diagnostic:
                        .init(
                            severity: .warning,
                            identifier: "org.swift.docc.UnknownBundleFeatureFlag",
                            summary: summary
                        )))
            }
        } else {
            currentFeatureFlags = nil
        }
        defer {
            if let currentFeatureFlags = currentFeatureFlags {
                FeatureFlags.current = currentFeatureFlags
            }
        }

        // Note: Each bundle is registered and processed separately.
        // Documents and symbols may both reference each other so the bundle is registered in 4 steps

        // In the bundle discovery phase all tasks run in parallel as they don't depend on each other.
        let discoveryGroup = DispatchGroup()
        let discoveryQueue = DispatchQueue(label: "org.swift.docc.Discovery", qos: .unspecified, attributes: .concurrent, autoreleaseFrequency: .workItem)

        let discoveryError = Synchronized<(any Error)?>(nil)

        // Load all bundle symbol graphs into the loader.
        var symbolGraphLoader: SymbolGraphLoader!
        var hierarchyBasedResolver: PathHierarchyBasedLinkResolver!

        discoveryGroup.async(queue: discoveryQueue) { [unowned self] in
            symbolGraphLoader = SymbolGraphLoader(
                bundle: bundle,
                dataLoader: { try self.contentsOfURL($0, in: $1) },
                symbolGraphTransformer: configuration.convertServiceConfiguration.symbolGraphTransformer
            )

            do {
                try signposter.withIntervalSignpost("Load symbols", id: signposter.makeSignpostID()) {
                    try symbolGraphLoader.loadAll()
                }
                hierarchyBasedResolver = signposter.withIntervalSignpost("Build PathHierarchy", id: signposter.makeSignpostID()) {
                    PathHierarchyBasedLinkResolver(pathHierarchy: PathHierarchy(
                        symbolGraphLoader: symbolGraphLoader,
                        bundleName: urlReadablePath(bundle.displayName),
                        knownDisambiguatedPathComponents: configuration.convertServiceConfiguration.knownDisambiguatedSymbolPathComponents
                    ))
                }
            } catch {
                // Pipe the error out of the dispatch queue.
                discoveryError.sync({
                    if $0 == nil { $0 = error }
                })
            }
        }

        // First, all the resources are added since they don't reference anything else.
        discoveryGroup.async(queue: discoveryQueue) { [unowned self] in
            do {
                try signposter.withIntervalSignpost("Load resources", id: signposter.makeSignpostID()) {
                    try self.registerMiscResources(from: bundle)
                }
            } catch {
                // Pipe the error out of the dispatch queue.
                discoveryError.sync({
                    if $0 == nil { $0 = error }
                })
            }
        }

        // Second, all the documents and symbols are added.
        //
        // Note: Documents and symbols may look up resources at this point but shouldn't lookup other documents or
        //       symbols or attempt to resolve links/references since the topic graph may not contain all documents
        //       or all symbols yet.
        var result: (
            tutorialTableOfContentsResults: [SemanticResult<TutorialTableOfContents>],
            tutorials: [SemanticResult<Tutorial>],
            tutorialArticles: [SemanticResult<TutorialArticle>],
            articles: [SemanticResult<Article>],
            documentationExtensions: [SemanticResult<Article>]
        )!

        discoveryGroup.async(queue: discoveryQueue) { [unowned self] in
            do {
                result = try signposter.withIntervalSignpost("Load documents", id: signposter.makeSignpostID()) {
                    try self.registerDocuments(from: bundle)
                }
            } catch {
                // Pipe the error out of the dispatch queue.
                discoveryError.sync({
                    if $0 == nil { $0 = error }
                })
            }
        }

        discoveryGroup.async(queue: discoveryQueue) { [unowned self] in
            do {
                try signposter.withIntervalSignpost("Load external resolvers", id: signposter.makeSignpostID()) {
                    try linkResolver.loadExternalResolvers(dependencyArchives: configuration.externalDocumentationConfiguration.dependencyArchives)
                }
            } catch {
                // Pipe the error out of the dispatch queue.
                discoveryError.sync({
                    if $0 == nil { $0 = error }
                })
            }
        }

        discoveryGroup.wait()

        try shouldContinueRegistration()

        // Re-throw discovery errors
        if let encounteredError = discoveryError.sync({ $0 }) {
            throw encounteredError
        }

        // All discovery went well, process the inputs.
        let (tutorialTableOfContentsResults, tutorials, tutorialArticles, allArticles, documentationExtensions) = result
        var (otherArticles, rootPageArticles) = splitArticles(allArticles)

        let globalOptions = (allArticles + documentationExtensions).compactMap { article in
            return article.value.options[.global]
        }

        if globalOptions.count > 1 {
            let extraGlobalOptionsProblems = globalOptions.map { extraOptionsDirective -> Problem in
                let diagnostic = Diagnostic(
                    source: extraOptionsDirective.originalMarkup.nameLocation?.source,
                    severity: .warning,
                    range: extraOptionsDirective.originalMarkup.range,
                    identifier: "org.swift.docc.DuplicateGlobalOptions",
                    summary: "Duplicate \(extraOptionsDirective.scope) \(Options.directiveName.singleQuoted) directive",
                    explanation: """
                    A DocC catalog can only contain a single \(Options.directiveName.singleQuoted) \
                    directive with the \(extraOptionsDirective.scope.rawValue.singleQuoted) scope.
                    """
                )

                guard let range = extraOptionsDirective.originalMarkup.range else {
                    return Problem(diagnostic: diagnostic)
                }

                let solution = Solution(
                    summary: "Remove extraneous \(extraOptionsDirective.scope) \(Options.directiveName.singleQuoted) directive",
                    replacements: [
                        Replacement(range: range, replacement: "")
                    ]
                )

                return Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            }

            diagnosticEngine.emit(extraGlobalOptionsProblems)
        } else {
            options = globalOptions.first
        }

        self.linkResolver.localResolver = hierarchyBasedResolver
        hierarchyBasedResolver.addMappingForRoots(bundle: bundle)
        for tutorial in tutorials {
            hierarchyBasedResolver.addTutorial(tutorial)
        }
        for article in tutorialArticles {
            hierarchyBasedResolver.addTutorialArticle(article)
        }
        for tutorialTableOfContents in tutorialTableOfContentsResults {
            hierarchyBasedResolver.addTutorialTableOfContents(tutorialTableOfContents)
        }

        registerRootPages(from: rootPageArticles, in: bundle)
        try registerSymbols(from: bundle, symbolGraphLoader: symbolGraphLoader, documentationExtensions: documentationExtensions)
        // We don't need to keep the loader in memory after we've registered all symbols.
        symbolGraphLoader = nil

        try shouldContinueRegistration()

        if topicGraph.nodes.isEmpty,
           !otherArticles.isEmpty,
           !configuration.convertServiceConfiguration.allowsRegisteringArticlesWithoutTechnologyRoot
        {
            synthesizeArticleOnlyRootPage(articles: &otherArticles, bundle: bundle)
        }

        // Keep track of the root modules registered from symbol graph files, we'll need them to automatically
        // curate articles.
        rootModules = topicGraph.nodes.values.compactMap { node in
            guard node.kind == .module else {
                return nil
            }
            return node.reference
        }

        // Articles that will be automatically curated can be resolved but they need to be pre registered before resolving links.
        let rootNodeForAutomaticCuration = soleRootModuleReference.flatMap(topicGraph.nodeWithReference(_:))
        if configuration.convertServiceConfiguration.allowsRegisteringArticlesWithoutTechnologyRoot || rootNodeForAutomaticCuration != nil {
            otherArticles = registerArticles(otherArticles, in: bundle)
            try shouldContinueRegistration()
        }

        // Third, any processing that relies on resolving other content is done, mainly resolving links.
        preResolveExternalLinks(semanticObjects:
            tutorialTableOfContentsResults.map(referencedSemanticObject) +
            tutorials.map(referencedSemanticObject) +
            tutorialArticles.map(referencedSemanticObject),
                                localBundleID: bundle.id)

        resolveLinks(
            tutorialTableOfContents: tutorialTableOfContentsResults,
            tutorials: tutorials,
            tutorialArticles: tutorialArticles,
            bundle: bundle
        )

        // After the resolving links in tutorial content all the local references are known and can be added to the referenceIndex for fast lookup.
        referenceIndex.reserveCapacity(knownIdentifiers.count + nodeAnchorSections.count)
        for reference in knownIdentifiers {
            referenceIndex[reference.absoluteString] = reference
        }
        for reference in nodeAnchorSections.keys {
            referenceIndex[reference.absoluteString] = reference
        }

        try shouldContinueRegistration()
        var allCuratedReferences = try crawlSymbolCuration(in: linkResolver.localResolver.topLevelSymbols(), bundle: bundle)

        // Store the list of manually curated references if doc coverage is on.
        if configuration.experimentalCoverageConfiguration.shouldStoreManuallyCuratedReferences {
            manuallyCuratedReferences = allCuratedReferences
        }

        try shouldContinueRegistration()

        // Fourth, automatically curate all symbols that haven't been curated manually
        let automaticallyCurated = signposter.withIntervalSignpost("Auto-curate symbols ", id: signposter.makeSignpostID()) {
            autoCurateSymbolsInTopicGraph()
        }

        // Crawl the rest of the symbols that haven't been crawled so far in hierarchy pre-order.
        allCuratedReferences = try crawlSymbolCuration(in: automaticallyCurated.map(\.symbol), bundle: bundle, initial: allCuratedReferences)

        // Remove curation paths that have been created automatically above
        // but we've found manual curation for in the second crawl pass.
        removeUnneededAutomaticCuration(automaticallyCurated)

        // Automatically curate articles that haven't been manually curated
        // Article curation is only done automatically if there is only one root module
        if let rootNode = rootNodeForAutomaticCuration {
            let articleReferences = try autoCurateArticles(otherArticles, startingFrom: rootNode)
            preResolveExternalLinks(references: articleReferences, localBundleID: bundle.id)
            resolveLinks(curatedReferences: Set(articleReferences), bundle: bundle)
        }

        // Remove any empty "Extended Symbol" pages whose children have been curated elsewhere.
        for module in rootModules {
            trimEmptyExtendedSymbolPages(under: module)
        }

        // Emit warnings for any remaining uncurated files.
        emitWarningsForUncuratedTopics()

        linkResolver.localResolver.addAnchorForSymbols(localCache: documentationCache)

        // Fifth, resolve links in nodes that are added solely via curation
        preResolveExternalLinks(references: Array(allCuratedReferences), localBundleID: bundle.id)
        resolveLinks(curatedReferences: allCuratedReferences, bundle: bundle)

        if configuration.convertServiceConfiguration.fallbackResolver != nil {
            // When the ``ConvertService`` builds documentation for a single page there won't be a module or root
            // reference to auto-curate the page under, so the regular local link resolution code path won't visit
            // the single page. To ensure that links are resolved, explicitly visit all pages.
            resolveLinks(curatedReferences: Set(knownPages), bundle: bundle)
        }

        // We should use a read-only context during render time (rdar://65130130).

        // Sixth - fetch external entities and merge them in the context
        for case .success(let reference) in externallyResolvedLinks.values {
            referenceIndex[reference.absoluteString] = reference
        }

        // Seventh, the complete topic graph—with all nodes and all edges added—is analyzed.
        signposter.withIntervalSignpost("Analyze topic graph", id: signposter.makeSignpostID()) {
            topicGraphGlobalAnalysis()
        }

        preResolveModuleNames()
    }

    /// Given a list of topics that have been automatically curated, checks if a topic has been additionally manually curated
    /// and if so removes the automatic curation.
    ///
    /// During the first crawl pass we skip over all automatically curated nodes (as they are not in the topic graph yet.
    /// After adding all symbols automatically to their parents and running a second crawl pass we discover any manual
    /// curations that we could not crawl in the first pass.
    ///
    /// To remove the automatic curations that have been made "obsolete" via the second pass of crawling
    /// call `removeUnneededAutomaticCuration(_:)` which walks the list of automatic curations and removes
    /// the parent <-> child topic graph relationships that have been obsoleted.
    ///
    /// - Parameter automaticallyCurated: A list of automatic curation records.
    func removeUnneededAutomaticCuration(_ automaticallyCurated: [AutoCuratedSymbolRecord]) {
        // It might look like it would be correct to check `topicGraph.nodes[symbol]?.shouldAutoCurateInCanonicalLocation` here,
        // but that would incorrectly remove the only parent if the manual curation and the automatic curation was the same.
        //
        // Similarly, it might look like it would be correct to only check `parents(of: symbol).count > 1` here,
        // but that would incorrectly remove the automatic curation for symbols with different language representations with different parents.
        for (symbol, parent, counterpartParent) in automaticallyCurated where parents(of: symbol).count > (counterpartParent != nil ? 2 : 1) {
            topicGraph.removeEdge(fromReference: parent, toReference: symbol)
            if let counterpartParent {
                topicGraph.removeEdge(fromReference: counterpartParent, toReference: symbol)
            }
        }
    }

    /// Remove unneeded "Extended Symbol" pages whose children have been curated elsewhere.
    func trimEmptyExtendedSymbolPages(under nodeReference: ResolvedTopicReference) {
        // Get the children of this node that are an "Extended Symbol" page.
        let extendedSymbolChildren = topicGraph.edges[nodeReference]?.filter({ childReference in
            guard let childNode = topicGraph.nodeWithReference(childReference) else { return false }
            return childNode.kind.isExtendedSymbolKind
        }) ?? []

        // First recurse to clean up the tree depth-first.
        for child in extendedSymbolChildren {
            trimEmptyExtendedSymbolPages(under: child)
        }

        // Finally, if this node was left with no children and does not have an extension file,
        // remove it from the topic graph.
        if let node = topicGraph.nodeWithReference(nodeReference),
           node.kind.isExtendedSymbolKind,
           topicGraph[node].isEmpty,
           documentationExtensionURL(for: nodeReference) == nil
        {
            topicGraph.removeEdges(to: node)
            topicGraph.removeEdges(from: node)
            topicGraph.edges.removeValue(forKey: nodeReference)
            topicGraph.reverseEdges.removeValue(forKey: nodeReference)

            topicGraph.replaceNode(node, with: .init(
                reference: node.reference,
                kind: node.kind,
                source: node.source,
                title: node.title,
                isResolvable: false, // turn isResolvable off to prevent a link from being made
                isVirtual: true, // set isVirtual to keep it from generating a page later on
                isEmptyExtension: true
            ))
        }
    }

    typealias AutoCuratedSymbolRecord = (symbol: ResolvedTopicReference, parent: ResolvedTopicReference, counterpartParent: ResolvedTopicReference?)

    /// Curate all remaining uncurated symbols under their natural parent from the symbol graph.
    ///
    /// This will include all symbols that were not manually curated by the documentation author.
    /// - Returns: An ordered list of symbol references that have been added to the topic graph automatically.
    private func autoCurateSymbolsInTopicGraph() -> [AutoCuratedSymbolRecord] {
        var automaticallyCuratedSymbols = [AutoCuratedSymbolRecord]()
        linkResolver.localResolver.traverseSymbolAndParents { reference, parentReference, counterpartParentReference in
            guard let topicGraphNode = topicGraph.nodeWithReference(reference),
                  // Check that the node isn't already manually curated
                  topicGraphNode.shouldAutoCurateInCanonicalLocation
            else { return }

            // Check that the symbol doesn't already have parent's that aren't either language representation's hierarchical parent.
            // This for example happens for default implementation and symbols that are requirements of protocol conformances.
            guard parents(of: reference).allSatisfy({ $0 == parentReference || $0 == counterpartParentReference }) else {
                return
            }

            guard let topicGraphParentNode = topicGraph.nodeWithReference(parentReference) else {
                preconditionFailure("Node with reference \(parentReference.absoluteString) exist in link resolver but not in topic graph.")
            }
            topicGraph.addEdge(from: topicGraphParentNode, to: topicGraphNode)

            if let counterpartParentReference {
                guard let topicGraphCounterpartParentNode = topicGraph.nodeWithReference(counterpartParentReference) else {
                    preconditionFailure("Node with reference \(counterpartParentReference.absoluteString) exist in link resolver but not in topic graph.")
                }
                topicGraph.addEdge(from: topicGraphCounterpartParentNode, to: topicGraphNode)
            }
            // Collect a single automatic curation record for both language representation parents.
            automaticallyCuratedSymbols.append((reference, parentReference, counterpartParentReference))
        }
        return automaticallyCuratedSymbols
    }

    private func addOverloadGroupReferences(overloadGroups: [String: Set<String>]) {
        guard FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled else {
            return
        }

        for (overloadGroupID, overloadSymbolIDs) in overloadGroups {
            guard overloadSymbolIDs.count > 1 else {
                assertionFailure("Overload group \(overloadGroupID) contained \(overloadSymbolIDs.count) symbols, but should have more than one symbol to be valid.")
                continue
            }
            guard let overloadGroupNode = documentationCache[overloadGroupID] else {
                preconditionFailure("Overload group \(overloadGroupID) doesn't have a local entity")
            }

            var overloadSymbolNodes = overloadSymbolIDs.map {
                guard let node = documentationCache[$0] else {
                    preconditionFailure("Overloaded symbol \($0) doesn't have a local entity")
                }
                return node
            }
            if overloadSymbolNodes.allSatisfy({ node in
                (node.semantic as? Symbol)?.overloadsVariants.firstValue != nil
            }) {
                // If SymbolKit saved its sort of the symbols, use that ordering here
                overloadSymbolNodes.sort(by: { lhs, rhs in
                    let lhsIndex = (lhs.semantic as! Symbol).overloadsVariants.firstValue!.displayIndex
                    let rhsIndex = (rhs.semantic as! Symbol).overloadsVariants.firstValue!.displayIndex
                    return lhsIndex < rhsIndex
                })
            } else {
                assertionFailure("""
                    Overload group \(overloadGroupNode.reference.absoluteString.singleQuoted) was not properly initialized with overload data from SymbolKit.
                    Symbols without overload data: \(Array(overloadSymbolNodes.filter({ ($0.semantic as? Symbol)?.overloadsVariants.firstValue == nil }).map(\.reference.absoluteString.singleQuoted)))
                    """)
                return
            }

            func addOverloadReferences(
                to documentationNode: DocumentationNode,
                at index: Int,
                overloadSymbolReferences: [DocumentationNode]
            ) {
                guard let symbol = documentationNode.semantic as? Symbol else {
                    preconditionFailure("""
                    Only symbols can be overloads. Found non-symbol overload for \(documentationNode.reference.absoluteString.singleQuoted).
                    Non-symbols should already have been filtered out by SymbolKit.
                    """)
                }
                guard documentationNode.reference.sourceLanguage == .swift else {
                    assertionFailure("""
                    Overload groups are only supported for Swift symbols.
                    The symbol at \(documentationNode.reference.absoluteString.singleQuoted) is listed as \(documentationNode.reference.sourceLanguage.name).
                    """)
                    return
                }

                var otherOverloadedSymbolReferences = overloadSymbolReferences.map(\.reference)
                otherOverloadedSymbolReferences.remove(at: index)
                let displayIndex = symbol.overloadsVariants.firstValue?.displayIndex ?? index
                let overloads = Symbol.Overloads(references: otherOverloadedSymbolReferences, displayIndex: displayIndex)
                symbol.overloadsVariants = .init(swiftVariant: overloads)
            }

            // The overload group node itself is a clone of the first symbol, so the code above can
            // swap out the first element in the overload references to create the alternate
            // declarations section properly. However, it is also a distinct symbol, node, and page,
            // so the first overload itself should also be handled separately in the loop below.
            addOverloadReferences(to: overloadGroupNode, at: 0, overloadSymbolReferences: overloadSymbolNodes)

            for (index, node) in overloadSymbolNodes.indexed() {
                addOverloadReferences(to: node, at: index, overloadSymbolReferences: overloadSymbolNodes)
            }
        }
    }

    /// A closure type getting the information about a reference in a context and returns any possible problems with it.
    public typealias ReferenceCheck = (DocumentationContext, ResolvedTopicReference) -> [Problem]

    /// Adds new checks to be run during the global topic analysis; after a bundle has been fully registered and its topic graph has been fully built.
    ///
    /// - Parameter newChecks: The new checks to add.
    @available(*, deprecated, message: "Use 'TopicAnalysisConfiguration.additionalChecks' instead. This deprecated API will be removed after 6.2 is released")
    public func addGlobalChecks(_ newChecks: [ReferenceCheck]) {
        configuration.topicAnalysisConfiguration.additionalChecks.append(contentsOf: newChecks)
    }

    /// Crawls the hierarchy of the given list of nodes, adding relationships in the topic graph for all resolvable task group references.
    /// - Parameters:
    ///   - references: A list of references to crawl.
    ///   - bundle: A documentation bundle.
    ///   - initial: A list of references to skip when crawling.
    /// - Returns: The references of all the symbols that were curated.
    @discardableResult
    func crawlSymbolCuration(in references: [ResolvedTopicReference], bundle: DocumentationBundle, initial: Set<ResolvedTopicReference> = []) throws -> Set<ResolvedTopicReference> {
        let signpostHandle = signposter.beginInterval("Curate symbols", id: signposter.makeSignpostID())
        defer {
            signposter.endInterval("Curate symbols", signpostHandle)
        }

        var crawler = DocumentationCurator(in: self, bundle: bundle, initial: initial)

        for reference in references {
            try crawler.crawlChildren(
                of: reference,
                relateNodes: { container, descendant in
                    topicGraph.unsafelyAddEdge(source: container, target: descendant)

                    guard topicGraph.nodes[descendant]?.shouldAutoCurateInCanonicalLocation == true else {
                        // Descendant is already marked to be removed from automatic curation.
                        return
                    }

                    // An inner function called below
                    func stopAutoCuratingDescendant() {
                        topicGraph.nodes[descendant]?.shouldAutoCurateInCanonicalLocation = false
                    }

                    guard let (canonicalContainer, counterpartContainer) = linkResolver.localResolver.nearestContainers(ofSymbol: descendant) else {
                        // Any curation of a non-symbol removes it from automatic curation
                        stopAutoCuratingDescendant()
                        return
                    }

                    // For symbols we only stop automatic curation if they are curated within their canonical container's sub-hierarchy
                    // or if a top-level symbol is curated under another top-level symbol (more on that below).
                    //
                    // For example, curating a member under an API collection within the container removes the member from automatic curation:
                    //  ┆
                    //  ├─SomeClass
                    //  │ └─API Collection
                    //  │   └─SomeClass/someMethod()  ◀︎━━ won't auto curate
                    //
                    // However, curating a member outside under another container _doesn't_ remove it from automatic curation:
                    //  ┆
                    //  ├─Other Container
                    //  │ └─SomeClass/someMethod()  ◀︎━━  will still auto curate under `SomeClass`
                    //  ├─SomeClass
                    //
                    // The same applies if the authored curation location is a another member of the canonical container:
                    //  ┆
                    //  ├─SomeClass
                    //  │ └─SomeClass/SomeInnerClass
                    //  │   └─SomeClass/someMethod()  ◀︎━━ will still auto curate under `SomeClass`
                    //
                    // Top-level symbols curated under other top-level is an exception to this rule.
                    //  ┆
                    //  ├─SomeClass
                    //  │ └─OtherTopLevelClass  ◀︎━━ won't auto curate because it's top-level.
                    //
                    // The reason for this exception is to allow developers to group top-level types under one-another without requiring an API collection.
                    // For example, in DocC one could curate `DiagnosticConsumer`, `DiagnosticFormattingOptions`, and `Diagnostic` under `DiagnosticEngine`,
                    // treating the `DiagnosticEngine` as the top-level topic for all diagnostic related types.


                    // To determine if `container` exists in the curated symbol's canonical container's sub-hierarchy,
                    // first find its nearest container symbol (in case `container` is a series of API collections).
                    //
                    // If the `container` is a symbol, this returns the container.
                    guard let nearestSymbolContainer = topicGraph.reverseEdgesGraph
                        .breadthFirstSearch(from: container)
                        .first(where: { topicGraph.nodes[$0]?.kind.isSymbol == true })
                    else {
                        // The container doesn't exist in the same module as the curated symbol.
                        // Continue to automatically curate the descendant under its canonical container.
                        return
                    }

                    if nearestSymbolContainer == canonicalContainer || nearestSymbolContainer == counterpartContainer {
                        // The descendant is curated in its canonical container (in either language representation)
                        stopAutoCuratingDescendant()
                        return
                    }

                    // An inner function called below
                    func isModule(_ reference: ResolvedTopicReference) -> Bool {
                        topicGraph.nodes[reference]?.kind == .module
                    }

                    if isModule(canonicalContainer) || counterpartContainer.map(isModule) == true {
                        guard let curationLocationContainers = linkResolver.localResolver.nearestContainers(ofSymbol: nearestSymbolContainer) else {
                            assertionFailure("""
                                Unexpectedly didn't find any canonical containers for symbol \(nearestSymbolContainer.absoluteString.singleQuoted).
                                Every non-module symbol should have a canonical container.
                                """)
                            return
                        }

                        if canonicalContainer   == curationLocationContainers.main        ||
                           canonicalContainer   == curationLocationContainers.counterpart ||
                           counterpartContainer == curationLocationContainers.main        ||
                           counterpartContainer == curationLocationContainers.counterpart && counterpartContainer != nil
                        {
                            // The descendant is a top-level symbol, curated under another top-level symbol in the same module
                            stopAutoCuratingDescendant()
                            return
                        }
                    }
                }
            )
        }

        diagnosticEngine.emit(crawler.problems)

        return crawler.curatedNodes
    }

    /// Emits warnings for symbols that are matched by multiple documentation extensions.
    private func emitWarningsForSymbolsMatchedInMultipleDocumentationExtensions(with symbolsWithMultipleDocumentationExtensionMatches: [ResolvedTopicReference : [DocumentationContext.SemanticResult<Article>]]) {
        for (reference, documentationExtensions) in symbolsWithMultipleDocumentationExtensionMatches {
            let symbolPath = reference.url.pathComponents.dropFirst(2).joined(separator: "/")
            let firstExtension = documentationExtensions.first!

            guard let link = firstExtension.value.title?.child(at: 0) as? (any AnyLink) else {
                fatalError("An article shouldn't have ended up in the documentation extension list unless its title was a link. File: \(firstExtension.source.absoluteString.singleQuoted)")
            }
            let zeroRange = SourceLocation(line: 1, column: 1, source: nil)..<SourceLocation(line: 1, column: 1, source: nil)
            let notes: [DiagnosticNote] = documentationExtensions.dropFirst().map { documentationExtension in
                guard let link = documentationExtension.value.title?.child(at: 0) as? (any AnyLink) else {
                    fatalError("An article shouldn't have ended up in the documentation extension list unless its title was a link. File: \(documentationExtension.source.absoluteString.singleQuoted)")
                }
                return DiagnosticNote(source: documentationExtension.source, range: link.range ?? zeroRange, message: "\(symbolPath.singleQuoted) is also documented here.")
            }

            diagnosticEngine.emit(
                Problem(diagnostic: Diagnostic(source: firstExtension.source, severity: .warning, range: link.range, identifier: "org.swift.docc.DuplicateMarkdownTitleSymbolReferences", summary: "Multiple documentation extensions matched \(symbolPath.singleQuoted).", notes: notes), possibleSolutions: [])
            )
        }
    }

    /// Emits information diagnostics for uncurated articles.
    private func emitWarningsForUncuratedTopics() {
        // Check that all articles are curated
        for articleResult in uncuratedArticles.values {
            diagnosticEngine.emit(Problem(diagnostic: Diagnostic(source: articleResult.source, severity: .information, range: nil, identifier: "org.swift.docc.ArticleUncurated", summary: "You haven't curated \(articleResult.topicGraphNode.reference.description.singleQuoted)"), possibleSolutions: []))
        }
    }

    /**
     Analysis that runs after all nodes are successfully registered in the context.
     Useful for checks that need the complete node graph.
     */
    func topicGraphGlobalAnalysis() {
        // Run any checks added to the context.
        let problems = knownIdentifiers.flatMap { reference in
            return configuration.topicAnalysisConfiguration.additionalChecks.flatMap { check in
                return check(self, reference)
            }
        }
        diagnosticEngine.emit(problems)

        // Run pre-defined global analysis.
        for node in topicGraph.nodes.values {
            switch node.kind {
            case .tutorial:
                Tutorial.analyze(node, completedContext: self, engine: diagnosticEngine)
            case .tutorialArticle:
                TutorialArticle.analyze(node, completedContext: self, engine: diagnosticEngine)
            default: break
            }
        }

        // Run analysis to determine whether manually configured alternate representations are valid.
        analyzeAlternateRepresentations()

        // Run global ``TopicGraph`` global analysis.
        analyzeTopicGraph()
    }

    /**
     Unregister a documentation bundle with this context and clear any cached resources associated with it.
     */
    private func unregister(_ bundle: DocumentationBundle) {
        let referencesToRemove = topicGraph.nodes.keys.filter {
            $0.bundleID == bundle.id
        }

        for reference in referencesToRemove {
            topicGraph.edges[reference]?.removeAll(where: { $0.bundleID == bundle.id })
            topicGraph.reverseEdges[reference]?.removeAll(where: { $0.bundleID == bundle.id })
            topicGraph.nodes[reference] = nil
        }
    }

    // MARK: - Getting documentation relationships

    /**
     Look for a secondary resource among the registered bundles.

     The context tracks resources by file name. If the documentation author specified a resource reference using a
     qualified path, instead of a file name, the context will fail to find that resource.

     - Returns: A `Foundation.Data` object with the data for the given ``ResourceReference``.
     - Throws: ``ContextError/notFound(_:)` if a resource with the given was not found.
     */
    public func resource(with identifier: ResourceReference, trait: DataTraitCollection = .init()) throws -> Data {
        guard let bundle,
              let assetManager = assetManagers[identifier.bundleID],
              let asset = assetManager.allData(named: identifier.path) else {
            throw ContextError.notFound(identifier.url)
        }

        let resource = asset.data(bestMatching: trait)

        return try contentsOfURL(resource.url, in: bundle)
    }

    /// Returns true if a resource with the given identifier exists in the registered bundle.
    public func resourceExists(with identifier: ResourceReference, ofType expectedAssetType: AssetType? = nil) -> Bool {
        guard let assetManager = assetManagers[identifier.bundleID] else {
            return false
        }

        guard let key = assetManager.bestKey(forAssetName: identifier.path) else {
            return false
        }

        guard let expectedAssetType, let asset = assetManager.storage[key] else {
            return true
        }

        return asset.hasVariant(withAssetType: expectedAssetType)
    }

    private func externalEntity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity? {
        return configuration.externalDocumentationConfiguration.sources[reference.bundleID].map({ $0.entity(with: reference) })
            ?? configuration.convertServiceConfiguration.fallbackResolver?.entityIfPreviouslyResolved(with: reference)
    }

    /**
     Look for a documentation node among the registered bundles and via any external resolvers.

     - Returns: A ``DocumentationNode`` with the given identifier.
     - Throws: ``ContextError/notFound(_:)`` if a documentation node with the given identifier was not found.
     */
    public func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
        if let cached = documentationCache[reference] {
            return cached
        }

        throw ContextError.notFound(reference.url)
    }

    private func knownEntityValue<Result>(
        reference: ResolvedTopicReference,
        valueInLocalEntity: (DocumentationNode) -> Result,
        valueInExternalEntity: (LinkResolver.ExternalEntity) -> Result
    ) -> Result {
        do {
            // Look up the entity without its fragment. The documentation context does not keep track of page sections
            // as nodes, and page sections are considered to be available in the same languages as the page they're
            // defined in.
            let referenceWithoutFragment = reference.withFragment(nil)
            return try valueInLocalEntity(entity(with: referenceWithoutFragment))
        } catch ContextError.notFound {
            if let externalEntity = externalCache[reference] {
                return valueInExternalEntity(externalEntity)
            }
            preconditionFailure("Reference does not have an associated documentation node.")
        } catch {
            fatalError("Unexpected error when retrieving entity: \(error)")
        }
    }

    /// Returns the set of languages the entity corresponding to the given reference is available in.
    ///
    /// - Precondition: The entity associated with the given reference must be registered in the context.
    public func sourceLanguages(for reference: ResolvedTopicReference) -> Set<SourceLanguage> {
        knownEntityValue(
            reference: reference,
            valueInLocalEntity: \.availableSourceLanguages,
            valueInExternalEntity: \.sourceLanguages
        )
    }

    /// Returns whether the given reference corresponds to a symbol.
    func isSymbol(reference: ResolvedTopicReference) -> Bool {
        knownEntityValue(
            reference: reference,
            valueInLocalEntity: { node in node.kind.isSymbol },
            valueInExternalEntity: { entity in entity.topicRenderReference.kind == .symbol }
        )
    }

    // MARK: - Relationship queries

    /// Fetch the child nodes of a documentation node with the given `reference`, optionally filtering to only children of the given `kind`.
    ///
    /// > Important: The returned list can't be used to determine source language specific children.
    ///
    /// - Parameters:
    ///   - reference: The reference of the node to fetch children for.
    ///   - kind: An optional documentation node kind to filter the children by.
    /// - Returns: A list of the reference and kind for each matching child node.
    public func children(of reference: ResolvedTopicReference, kind: DocumentationNode.Kind? = nil) -> [(reference: ResolvedTopicReference, kind: DocumentationNode.Kind)] {
        guard let node = topicGraph.nodeWithReference(reference) else {
            return []
        }
        return topicGraph[node].compactMap {
            guard let node = topicGraph.nodeWithReference($0) else {
                return nil
            }
            if kind == nil || node.kind == kind {
                return ($0, node.kind)
            }
            return nil
        }
    }

    /// Fetches the parents of the documentation node with the given `reference`.
    ///
    /// - Parameter reference: The reference of the node to fetch parents for.
    /// - Returns: A list of the reference for the given node's parent nodes.
    public func parents(of reference: ResolvedTopicReference) -> [ResolvedTopicReference] {
        return topicGraph.reverseEdges[reference] ?? []
    }

    /// Returns the document URL for the given article or tutorial reference.
    ///
    /// - Parameter reference: The identifier for the topic whose file URL to locate.
    /// - Returns: If the reference is a reference to a known Markdown document, this function returns the article's URL, otherwise `nil`.
    public func documentURL(for reference: ResolvedTopicReference) -> URL? {
        if let node = topicGraph.nodes[reference], case .file(let url) = node.source {
            return url
        }
        return nil
    }

    /// Returns the URL of the documentation extension of the given reference.
    ///
    /// - Parameter reference: The reference to the symbol this function should return the documentation extension URL for.
    /// - Returns: The document URL of the given symbol reference. If the given reference is not a symbol reference, returns `nil`.
    public func documentationExtensionURL(for reference: ResolvedTopicReference) -> URL? {
        guard (try? entity(with: reference))?.kind.isSymbol == true else {
            return nil
        }
        return documentLocationMap[reference]
    }

    /// Attempt to locate the reference for a given file.
    ///
    /// - Parameter url: The file whose reference to locate.
    /// - Returns: The reference for the file if it could be found, otherwise `nil`.
    public func referenceForFileURL(_ url: URL) -> ResolvedTopicReference? {
        return documentLocationMap[url]
    }

    /**
     Attempt to retrieve the title for a given `reference`.

     - Parameter reference: The reference for the topic whose title is desired.
     - Returns: The title of the topic if it could be found, otherwise `nil`.
     */
    public func title(for reference: ResolvedTopicReference) -> String? {
        return topicGraph.nodes[reference]?.title
    }

    /// Returns a sequence that traverses the topic graph in breadth first order from a given reference, without visiting the same node more than once.
    func breadthFirstSearch(from reference: ResolvedTopicReference) -> some Sequence<TopicGraph.Node> {
        topicGraph.breadthFirstSearch(from: reference)
    }

    /**
     Attempt to resolve a ``TopicReference``.

     > Note: If the reference is already resolved, the original reference is returned.

     - Parameters:
       - reference: An unresolved (or resolved) reference.
       - parent: The *resolved* reference that serves as an enclosing search context, especially the parent reference's bundle identifier.
       - isCurrentlyResolvingSymbolLink: If `true` will try to resolve relative links *only* in documentation symbol locations in the hierarchy. If `false` it will try to resolve relative links as tutorials, articles, symbols, etc.
     - Returns: Either the successfully resolved reference for the topic or error information about why the reference couldn't resolve.
     */
    public func resolve(_ reference: TopicReference, in parent: ResolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool = false) -> TopicReferenceResolutionResult {
        switch reference {
        case .unresolved(let unresolvedReference):
            return linkResolver.resolve(unresolvedReference, in: parent, fromSymbolLink: isCurrentlyResolvingSymbolLink, context: self)

        case .resolved(let resolved):
            // This reference is already resolved (either as a success or a failure), so don't change anything.
            return resolved
        }
    }

    /// Update the asset with a new value given the assets name and the topic it's referenced in.
    ///
    /// - Parameters:
    ///   - name: The name of the asset to update.
    ///   - asset: The new asset for this name.
    ///   - parent: The topic where the asset is referenced.
    public func updateAsset(named name: String, asset: DataAsset, in parent: ResolvedTopicReference) {
        assetManagers[parent.bundleID]?.update(name: name, asset: asset)
    }

    /// Attempt to resolve an asset given its name and the topic it's referenced in.
    ///
    /// - Parameters:
    ///   - name: The name of the asset.
    ///   - parent: The topic where the asset is referenced.
    ///   - type: A restriction for what type of asset to resolve.
    /// - Returns: The data that's associated with an image asset if it was found, otherwise `nil`.
    public func resolveAsset(named name: String, in parent: ResolvedTopicReference, withType type: AssetType? = nil) -> DataAsset? {
        resolveAsset(named: name, bundleID: parent.bundleID, withType: type)
    }

    func resolveAsset(named name: String, bundleID: DocumentationBundle.Identifier, withType expectedType: AssetType?) -> DataAsset? {
        if let localAsset = assetManagers[bundleID]?.allData(named: name) {
            if let expectedType {
                guard localAsset.hasVariant(withAssetType: expectedType) else {
                    return nil
                }
            }

            return localAsset
        }

        if let fallbackAssetResolver = configuration.convertServiceConfiguration.fallbackResolver,
           let externallyResolvedAsset = fallbackAssetResolver.resolve(assetNamed: name) {
            assetManagers[bundleID, default: DataAssetManager()]
                .register(dataAsset: externallyResolvedAsset, forName: name)
            return externallyResolvedAsset
        }

        // If no fallbackAssetResolver is set, try to treat it as external media link
        if let externalMediaLink = URL(string: name),
           externalMediaLink.isAbsoluteWebURL {
            var asset = DataAsset()
            asset.context = .display
            asset.register(externalMediaLink, with: DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard))
            return asset
        }
        return nil
    }

    /// Finds the identifier for a given asset name.
    ///
    /// `name` is one of the following formats:
    /// - "image" - asset name without extension
    /// - "image.png" - asset name including extension
    ///
    /// - Parameters:
    ///   - name: The name of the asset.
    ///   - parent: The topic where the asset is referenced.
    ///
    /// - Returns: The best matching storage key if it was found, otherwise `nil`.
    public func identifier(forAssetName name: String, in parent: ResolvedTopicReference) -> String? {
        if let assetManager = assetManagers[parent.bundleID] {
            if let localName = assetManager.bestKey(forAssetName: name) {
                return localName
            } else if let fallbackAssetManager = configuration.convertServiceConfiguration.fallbackResolver {
                return fallbackAssetManager.resolve(assetNamed: name) != nil ? name : nil
            }
            return nil
        } else {
            return nil
        }
    }

    /// Attempt to resolve an unresolved code listing.
    ///
    /// - Parameters:
    ///   - unresolvedCodeListingReference: The code listing reference to resolve.
    ///   - parent: The topic the code listing reference appears in.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.1 is released")
    public func resolveCodeListing(_ unresolvedCodeListingReference: UnresolvedCodeListingReference, in parent: ResolvedTopicReference) -> AttributedCodeListing? {
        switch dataProvider {
        case .legacy(let legacyDataProvider):
            legacyDataProvider.bundles[parent.bundleIdentifier]?.attributedCodeListings[unresolvedCodeListingReference.identifier]
        case .new:
            nil
        }
    }

    /// The references of all nodes in the topic graph.
    public var knownIdentifiers: [ResolvedTopicReference] {
        return Array(topicGraph.nodes.keys)
    }

    /// The references of all the pages in the topic graph.
    public var knownPages: [ResolvedTopicReference] {
        return topicGraph.nodes.values
            .filter { !$0.isVirtual && $0.kind.isPage }
            .map { $0.reference }
    }

    func dumpGraph() -> String {
        return topicGraph.nodes.values
            .filter { parents(of: $0.reference).isEmpty }
            .sorted(by: \.reference.absoluteString)
            .map { node -> String in
                self.topicGraph.dump(startingAt: node, keyPath: \.reference.absoluteString)
            }
            .joined()
    }

    private static func defaultLanguage(in sourceLanguages: Set<SourceLanguage>?) -> SourceLanguage {
        sourceLanguages.map { sourceLanguages in
            if sourceLanguages.contains(.swift) {
                return .swift
            } else {
                return sourceLanguages.first ?? .swift
            }
        } ?? SourceLanguage.swift
    }
}

// MARK: - DocumentationCurator
extension DocumentationContext {

    /// The nodes that are allowed to be roots in the topic graph.
    static var allowedRootNodeKinds: [DocumentationNode.Kind] = [.tutorialTableOfContents, .module]

    func analyzeTopicGraph() {
        // Find all nodes that are loose in the graph and have no parent but aren't supposed to
        let unexpectedRoots = topicGraph.nodes.values.filter { node in
            return !DocumentationContext.allowedRootNodeKinds.contains(node.kind)
                && parents(of: node.reference).isEmpty
        }
        let problems = unexpectedRoots.compactMap { node -> Problem? in
            let source: URL
            switch node.source {
            case .file(url: let url): source = url
            case .range(_, let url): source = url
            case .external: return nil
            }
            return Problem(diagnostic: Diagnostic(source: source, severity: .information, range: nil, identifier: "org.swift.docc.SymbolNotCurated", summary: "You haven't curated \(node.reference.absoluteString.singleQuoted)"), possibleSolutions: [Solution(summary: "Add a link to \(node.reference.absoluteString.singleQuoted) from a Topics group of another documentation node.", replacements: [])])
        }
        diagnosticEngine.emit(problems)
// Check for multiple root page warnings
        warnAboutMultipleRootPages()
    }

    /// Checks for multiple root pages in the documentation and emits appropriate warnings.
    private func warnAboutMultipleRootPages() {
        let problems = detectMultipleRootWarnings()
        diagnosticEngine.emit(problems)
    }

    func detectMultipleRootWarnings() -> [Problem] {
        var problems: [Problem] = []

        //Skip detection if there's only one or no root
        guard rootModules.count > 1 else {
            return []
        }

        //collects all root pages that aren't organized as a child of another root
        let freestandingRoots = rootModules.filter { root in
            return parents(of: root).isEmpty
                || !parents(of: root).contains { parentRef in
                    return rootModules.contains(parentRef)
                }
        }

        //If all roots are properly organized in a hierarchy, no warning needed
        if freestandingRoots.count <= 1 {
            return []
        }

        //Categorize roots by type
        let moduleRoots = freestandingRoots.filter { root in
            let node = topicGraph.nodeWithReference(root)

            //Must be a module node
            guard node?.kind == .module else {
                return false
            }

            //And must not have a TechnologyRoot directive
            if let entity = try? entity(with: root),
                let metadata = entity.metadata,
                metadata.technologyRoot != nil
            {
                return false
            }

            return true
        }

        let technologyRoots = freestandingRoots.filter { root in
            // Check if this has a TechnologyRoot directive
            if let entity = try? entity(with: root),
                let metadata = entity.metadata,
                metadata.technologyRoot != nil
            {
                return true
            }
            return false
        }

        // Check if modules are properly organized under technology roots
        let modulesUnderTechnologyRoots = moduleRoots.filter { moduleRoot in
            // Check if there's a path to a technology root
            if let pathToRoot = shortestFinitePath(to: moduleRoot) {
                // Check if any node in the path has a @TechnologyRoot directive
                return pathToRoot.contains { reference in
                    if let entity = try? entity(with: reference),
                       let metadata = entity.metadata,
                       metadata.technologyRoot != nil {
                        return true
                    }
                    return false
                }
            }
            return false
        }
        
        // Only warn about modules that are not organized under technology roots
        let freestandingModules = moduleRoots.filter { !modulesUnderTechnologyRoots.contains($0) }

        //different warning scenarios

        //multiple symbol graph modules
        if freestandingModules.count > 1 {
            let rootList = freestandingModules.map { $0.lastPathComponent.singleQuoted }.joined(
                separator: ", ")
            let problem = Problem(
                diagnostic: Diagnostic(
                    severity: .warning,
                    identifier: "org.swift.docc.MultipleSymbolGraphRoots",
                    summary: "Documentation has multiple symbol graph modules as root pages",
                    explanation:
                        "Found multiple root pages from symbol graph files: \(rootList). The primary root page can't be determined."
                ),
                possibleSolutions: []
            )
            problems.append(problem)
        }

        //symbol graph module and manual technology root
        if !freestandingModules.isEmpty && !technologyRoots.isEmpty {
            let moduleList = freestandingModules.map { $0.lastPathComponent.singleQuoted }.joined(
                separator: ", ")
            let technologyList = technologyRoots.map { $0.lastPathComponent.singleQuoted }.joined(
                separator: ", ")

            let problem = Problem(
                diagnostic: Diagnostic(
                    severity: .warning,
                    identifier: "org.swift.docc.MixedRootTypes",
                    summary:
                        "Documentation has both symbol graph modules and manual technology roots",
                    explanation:
                        "Found symbol graph modules (\(moduleList)) and manual technology roots (\(technologyList)). The symbol graph modules are considered primary roots, making any manual @TechnologyRoot pages unexpected extra roots."
                ),
                possibleSolutions: []
            )
            problems.append(problem)
        }

        //multiple manual technology roots
        if technologyRoots.count > 1 {
            let rootList = technologyRoots.map { $0.lastPathComponent.singleQuoted }.joined(
                separator: ", ")
            let problem = Problem(
                diagnostic: Diagnostic(
                    severity: .warning,
                    identifier: "org.swift.docc.MultipleTechnologyRoots",
                    summary: "Documentation has multiple manual technology roots",
                    explanation:
                        "Found multiple pages with @TechnologyRoot directive: \(rootList). The primary root page can't be determined."
                ),
                possibleSolutions: []
            )
            problems.append(problem)
        }

        return problems
    }

    func analyzeAlternateRepresentations() {
        var problems = [Problem]()

        func listSourceLanguages(_ sourceLanguages: Set<SourceLanguage>) -> String {
            sourceLanguages.sorted(by: { language1, language2 in
                // Emit Swift first, then alphabetically.
                switch (language1, language2) {
                case (.swift, _): return true
                case (_, .swift): return false
                default: return language1.id < language2.id
                }
            }).map(\.name).list(finalConjunction: .and)
        }
        func removeAlternateRepresentationSolution(_ alternateRepresentation: AlternateRepresentation) -> [Solution] {
            [Solution(
                summary: "Remove this alternate representation",
                replacements: alternateRepresentation.originalMarkup.range.map { [Replacement(range: $0, replacement: "")] } ?? [])]
        }

        for reference in knownPages {
            guard let entity = try? self.entity(with: reference), let alternateRepresentations = entity.metadata?.alternateRepresentations else { continue }

            var sourceLanguageToReference: [SourceLanguage: AlternateRepresentation] = [:]
            for alternateRepresentation in alternateRepresentations {
                // Check if the entity is not a symbol, as only symbols are allowed to specify custom alternate representations
                guard entity.symbol != nil else {
                    problems.append(Problem(
                        diagnostic: Diagnostic(
                            source: alternateRepresentation.originalMarkup.range?.source,
                            severity: .warning,
                            range: alternateRepresentation.originalMarkup.range,
                            identifier: "org.swift.docc.AlternateRepresentation.UnsupportedPageKind",
                            summary: "Custom alternate representations are not supported for page kind \(entity.kind.name.singleQuoted)",
                            explanation: "Alternate representations are only supported for symbols."
                        ),
                        possibleSolutions: removeAlternateRepresentationSolution(alternateRepresentation)
                    ))
                    continue
                }

                guard case .resolved(.success(let alternateRepresentationReference)) = alternateRepresentation.reference,
                      let alternateRepresentationEntity = try? self.entity(with: alternateRepresentationReference) else {
                    continue
                }

                // Check if the resolved entity is not a symbol, as only symbols are allowed as custom alternate representations
                guard alternateRepresentationEntity.symbol != nil else {
                    problems.append(Problem(
                        diagnostic: Diagnostic(
                            source: alternateRepresentation.originalMarkup.range?.source,
                            severity: .warning,
                            range: alternateRepresentation.originalMarkup.range,
                            identifier: "org.swift.docc.AlternateRepresentation.UnsupportedPageKind",
                            summary: "Page kind \(alternateRepresentationEntity.kind.name.singleQuoted) is not allowed as a custom alternate language representation",
                            explanation: "Symbols can only specify other symbols as custom language representations."
                        ),
                        possibleSolutions: removeAlternateRepresentationSolution(alternateRepresentation)
                    ))
                    continue
                }

                // Check if the documented symbol already has alternate representations from in-source annotations.
                let duplicateSourceLanguages = alternateRepresentationEntity.availableSourceLanguages.intersection(entity.availableSourceLanguages)
                if !duplicateSourceLanguages.isEmpty {
                    problems.append(Problem(
                        diagnostic: Diagnostic(
                            source: alternateRepresentation.originalMarkup.range?.source,
                            severity: .warning,
                            range: alternateRepresentation.originalMarkup.range,
                            identifier: "org.swift.docc.AlternateRepresentation.DuplicateLanguageDefinition",
                            summary: "\(entity.name.plainText.singleQuoted) already has a representation in \(listSourceLanguages(duplicateSourceLanguages))",
                            explanation: "Symbols can only specify custom alternate language representations for languages that the documented symbol doesn't already have a representation for."
                        ),
                        possibleSolutions: [Solution(summary: "Replace this alternate language representation with a symbol which isn't available in \(listSourceLanguages(entity.availableSourceLanguages))", replacements: [])]
                    ))
                }

                let duplicateAlternateLanguages = Set(sourceLanguageToReference.keys).intersection(alternateRepresentationEntity.availableSourceLanguages)
                if !duplicateAlternateLanguages.isEmpty {
                    let notes: [DiagnosticNote] = duplicateAlternateLanguages.compactMap { duplicateAlternateLanguage in
                        guard let alreadyExistingRepresentation = sourceLanguageToReference[duplicateAlternateLanguage],
                              let range = alreadyExistingRepresentation.originalMarkup.range,
                              let source = range.source else {
                            return nil
                        }

                        return DiagnosticNote(source: source, range: range, message: "This directive already specifies an alternate \(duplicateAlternateLanguage.name) representation.")
                    }
                    problems.append(Problem(
                        diagnostic: Diagnostic(
                            source: alternateRepresentation.originalMarkup.range?.source,
                            severity: .warning,
                            range: alternateRepresentation.originalMarkup.range,
                            identifier: "org.swift.docc.AlternateRepresentation.DuplicateLanguageDefinition",
                            summary: "A custom alternate language representation for \(listSourceLanguages(duplicateAlternateLanguages)) has already been specified",
                            explanation: "Only one custom alternate language representation can be specified per language.",
                            notes: notes
                        ),
                        possibleSolutions: removeAlternateRepresentationSolution(alternateRepresentation)
                    ))
                }

                // Update mapping from source language to alternate declaration, for diagnostic purposes
                for alreadySeenLanguage in alternateRepresentationEntity.availableSourceLanguages {
                    sourceLanguageToReference[alreadySeenLanguage] = alternateRepresentation
                }
            }
        }

        diagnosticEngine.emit(problems)
    }
}

extension GraphCollector.GraphKind {
    var fileURL: URL {
        switch self {
        case .primary(let url): return url
        case .extension(let url): return url
        }
    }
}

extension SymbolGraphLoader {
    func mainModuleURL(forModule moduleName: String) -> URL? {
        guard let graphURLs = self.graphLocations[moduleName] else { return nil }

        if let firstPrimary: URL = graphURLs.compactMap({
            if case let .primary(url) = $0 {
                return url
            } else {
                return nil
            }
        }).first {
            return firstPrimary
        } else {
            return graphURLs.first.map({ $0.fileURL })
        }
    }

    func hasPrimaryURL(moduleName: String) -> Bool {
        guard let graphURLs = self.graphLocations[moduleName] else { return false }

        return graphURLs.contains(where: {
            if case .primary(_) = $0 {
                return true
            } else {
                return false
            }
        })
    }
}

extension DataAsset {
    fileprivate func hasVariant(withAssetType assetType: DocumentationContext.AssetType) -> Bool {
        return variants.values.map(\.pathExtension).contains { pathExtension in
            return DocumentationContext.isFileExtension(pathExtension, supported: assetType)
        }
    }
}

@available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
extension DocumentationContext: DocumentationContextDataProviderDelegate {}
