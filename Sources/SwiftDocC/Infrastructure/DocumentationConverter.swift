/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A converter from a documentation catalog to an output that can be consumed by a renderer.
///
/// This protocol is primarily used for injecting mock documentation converters during testing.
///
/// ## See Also
///
/// - ``DocumentationConverter``
public protocol DocumentationConverterProtocol {
    /// Converts documentation, outputting products using the given output consumer.
    /// - Parameter outputConsumer: The output consumer for content produced during conversion.
    /// - Returns: The problems emitted during analysis of the documentation catalog and during conversion.
    /// - Throws: Throws an error if the conversion process was not able to start at all, for example if the catalog could not be read.
    /// Partial failures, such as failing to consume a single render node, are returned in the `conversionProblems` component
    /// of the returned tuple.
    mutating func convert<OutputConsumer: ConvertOutputConsumer>(
        outputConsumer: OutputConsumer
    ) throws -> (analysisProblems: [Problem], conversionProblems: [Problem])
}

/// A converter from a documentation catalog to an output that can be consumed by a renderer.
///
/// A documentation converter analyzes a documentation catalog and converts it to products that can be used by a documentation
/// renderer to render documentation. The output format of the conversion is controlled by a ``ConvertOutputConsumer``, which
/// determines what to do with the conversion products, for example, write them to disk.
///
/// You can also configure the documentation converter to emit extra metadata such as linkable entities and indexing records
/// information.
public struct DocumentationConverter: DocumentationConverterProtocol {
    let rootURL: URL?
    let emitDigest: Bool
    let documentationCoverageOptions: DocumentationCoverageOptions
    let catalogDiscoveryOptions: CatalogDiscoveryOptions
    let diagnosticEngine: DiagnosticEngine
    
    private(set) var context: DocumentationContext
    private let workspace: DocumentationWorkspace
    private var currentDataProvider: DocumentationWorkspaceDataProvider?
    private var dataProvider: DocumentationWorkspaceDataProvider
    
    /// An optional closure that sets up a context before the conversion begins.
    public var setupContext: ((inout DocumentationContext) -> Void)?
    
    /// Conversion batches should be big enough to keep all cores busy but small enough not to keep
    /// around too many async blocks that update the conversion results. After running some tests it
    /// seems that more than couple hundred of a batch size doesn't bring more performance CPU-wise
    /// and it's a fair amount of async tasks to keep in memory before draining the results queue
    /// after the batch is converted.
    var batchNodeCount = 1
    
    /// The external IDs of the symbols to convert.
    ///
    /// Use this property to indicate what symbol documentation nodes should be converted. When ``externalIDsToConvert``
    /// and ``documentationPathsToConvert`` are both set, the documentation nodes that are in either arrays will be
    /// converted.
    ///
    /// If you want all the symbol render nodes to be returned as part of the conversion's response, set this property to `nil`.
    /// For Swift, the external ID of the symbol is its USR.
    var externalIDsToConvert: [String]?
    
    /// The paths of the documentation nodes to convert.
    ///
    /// Use this property to indicate what documentation nodes should be converted. When ``externalIDsToConvert``
    /// and ``documentationPathsToConvert`` are both set, the documentation nodes that are in either arrays will be
    /// converted.
    ///
    /// If you want all the render nodes to be returned as part of the conversion's response, set this property to `nil`.
    var documentPathsToConvert: [String]?
    
    /// Whether the documentation converter should include source file
    /// location metadata in any render nodes representing symbols it creates.
    ///
    /// Before setting this value to `true` please confirm that your use case doesn't include
    /// public distribution of any created render nodes as there are filesystem privacy and security
    /// concerns with distributing this data.
    var shouldEmitSymbolSourceFileURIs: Bool
    
    /// Whether the documentation converter should include access level information for symbols.
    var shouldEmitSymbolAccessLevels: Bool
    
    /// `true` if the conversion is cancelled.
    private var isCancelled: Synchronized<Bool>? = nil

    private var durationMetric: Benchmark.Duration?

    /// Creates a documentation converter given a documentation catalog's URL.
    ///
    /// - Parameters:
    ///  - documentationCatalogURL: The root URL of the documentation catalog to convert.
    ///  - emitDigest: Whether the conversion should create metadata files, such as linkable entities information.
    ///  - documentationCoverageOptions: What level of documentation coverage output should be emitted.
    ///  - currentPlatforms: The current version and beta information for platforms that may be encountered while processing symbol graph files.
    ///   that may be encountered while processing symbol graph files.
    ///  - workspace: A provided documentation workspace. Creates a new empty workspace if value is `nil`.
    ///  - context: A provided documentation context. Creates a new empty context in the workspace if value is `nil`.
    ///  - dataProvider: A data provider to use when registering catalogs.
    /// - Parameter fileManager: A file persistence manager
    /// - Parameter externalIDsToConvert: The external IDs of the documentation nodes to convert.
    /// - Parameter documentPathsToConvert: The paths of the documentation nodes to convert.
    /// - Parameter catalogDiscoveryOptions: Options to configure how the converter discovers documentation catalogs.
    /// - Parameter emitSymbolSourceFileURIs: Whether the documentation converter should include
    ///   source file location metadata in any render nodes representing symbols it creates.
    ///
    ///   Before passing `true` please confirm that your use case doesn't include public
    ///   distribution of any created render nodes as there are filesystem privacy and security
    ///   concerns with distributing this data.
    public init(
        documentationCatalogURL: URL?,
        emitDigest: Bool,
        documentationCoverageOptions: DocumentationCoverageOptions,
        currentPlatforms: [String : PlatformVersion]?,
        workspace: DocumentationWorkspace,
        context: DocumentationContext,
        dataProvider: DocumentationWorkspaceDataProvider,
        externalIDsToConvert: [String]? = nil,
        documentPathsToConvert: [String]? = nil,
        catalogDiscoveryOptions: CatalogDiscoveryOptions,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false,
        isCancelled: Synchronized<Bool>? = nil,
        diagnosticEngine: DiagnosticEngine = .init()
    ) {
        self.rootURL = documentationCatalogURL
        self.emitDigest = emitDigest
        self.documentationCoverageOptions = documentationCoverageOptions
        self.workspace = workspace
        self.context = context
        self.dataProvider = dataProvider
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.catalogDiscoveryOptions = catalogDiscoveryOptions
        self.shouldEmitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.shouldEmitSymbolAccessLevels = emitSymbolAccessLevels
        self.isCancelled = isCancelled
        self.diagnosticEngine = diagnosticEngine
        
        // Inject current platform versions if provided
        if let currentPlatforms = currentPlatforms {
            self.context.externalMetadata.currentPlatforms = currentPlatforms
        }
    }
    
    @available(*, deprecated, renamed: "init(documentationCatalogURL:emitDigest:documentationCoverageOptions:currentPlatforms:workspace:context:dataProvider:externalIDsToConvert:documentPathsToConvert:catalogDiscoveryOptions:emitSymbolSourceFileURIs:emitSymbolAccessLevels:isCancelled:diagnosticEngine:)")
    public init(
        documentationBundleURL: URL?,
        emitDigest: Bool,
        documentationCoverageOptions: DocumentationCoverageOptions,
        currentPlatforms: [String : PlatformVersion]?,
        workspace: DocumentationWorkspace,
        context: DocumentationContext,
        dataProvider: DocumentationWorkspaceDataProvider,
        externalIDsToConvert: [String]? = nil,
        documentPathsToConvert: [String]? = nil,
        bundleDiscoveryOptions: CatalogDiscoveryOptions,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false,
        isCancelled: Synchronized<Bool>? = nil,
        diagnosticEngine: DiagnosticEngine = .init()
    ) {
        self = .init(documentationCatalogURL: documentationBundleURL, emitDigest: emitDigest, documentationCoverageOptions: documentationCoverageOptions, currentPlatforms: currentPlatforms, workspace: workspace, context: context, dataProvider: dataProvider, externalIDsToConvert: externalIDsToConvert, documentPathsToConvert: documentPathsToConvert, catalogDiscoveryOptions: bundleDiscoveryOptions, emitSymbolSourceFileURIs: emitSymbolSourceFileURIs, emitSymbolAccessLevels: emitSymbolAccessLevels, isCancelled: isCancelled, diagnosticEngine: diagnosticEngine)
    }
    
    /// Returns the first catalog in the source directory, if any.
    /// > Note: The result of this function is not cached, it reads the source directory and finds all catalogs.
    public func firstAvailableCatalog() -> DocumentationCatalog? {
        return (try? dataProvider.catalogs(options: catalogDiscoveryOptions)).map(sorted(catalogs:))?.first
    }
    
    @available(*, deprecated, renamed: "firstAvailableCatalog")
    public func firstAvailableBundle() -> DocumentationCatalog? {
        return firstAvailableCatalog()
    }
    
    /// Sorts a list of catalogs by the catalog identifier.
    private func sorted(catalogs: [DocumentationCatalog]) -> [DocumentationCatalog] {
        return catalogs.sorted(by: \.identifier)
    }
    
    mutating public func convert<OutputConsumer: ConvertOutputConsumer>(
        outputConsumer: OutputConsumer
    ) throws -> (analysisProblems: [Problem], conversionProblems: [Problem]) {
        // Unregister the current file data provider and all its catalogs
        // when running repeated conversions.
        if let dataProvider = self.currentDataProvider {
            try workspace.unregisterProvider(dataProvider)
        }
        
        // Do additional context setup.
        setupContext?(&context)

        durationMetric = benchmark(begin: Benchmark.Duration(id: "convert-action"))

        /*
           Asynchronously cancel registration if necessary.
           We spawn a timer that periodically checks `isCancelled` and if necessary
           disables registration in `DocumentationContext` as registration being
           the largest part of a documentation conversion.
        */
        let context = self.context
        let isCancelled = self.isCancelled
        
        // `true` if the `isCancelled` flag is set.
        func isConversionCancelled() -> Bool {
            return isCancelled?.sync({ $0 }) == true
        }

        // Run a timer that synchronizes the cancelled state between the converter and the context directly.
        // We need a timer on a separate dispatch queue because `workspace.registerProvider()` blocks
        // the current thread until it loads all symbol graphs, markdown files, and builds the topic graph
        // so in order to be able to update the context cancellation flag we need to run on a different thread.
        var cancelTimerQueue: DispatchQueue? = DispatchQueue(label: "org.swift.docc.ConvertActionCancelTimer", qos: .unspecified, attributes: .concurrent)
        let cancelTimer = DispatchSource.makeTimerSource(queue: cancelTimerQueue)
        cancelTimer.schedule(deadline: .now(), repeating: .milliseconds(500), leeway: .milliseconds(50))
        cancelTimer.setEventHandler {
            if isConversionCancelled() {
                cancelTimer.cancel()
                context.setRegistrationEnabled(false)
            }
        }
        cancelTimer.resume()
        
        // Start catalog registration
        try workspace.registerProvider(dataProvider, options: catalogDiscoveryOptions)
        self.currentDataProvider = dataProvider

        // Catalog registration is finished - stop the timer and reset the context cancellation state.
        cancelTimer.cancel()
        cancelTimerQueue = nil
        context.setRegistrationEnabled(true)
        
        // If cancelled, return early before we emit diagnostics.
        guard !isConversionCancelled() else { return ([], []) }
        
        let catalogs = try sorted(catalogs: dataProvider.catalogs(options: catalogDiscoveryOptions))
        guard !catalogs.isEmpty else {
            if let rootURL = rootURL {
                throw Error.doesNotContainCatalog(url: rootURL)
            } else {
                try outputConsumer.consume(problems: context.problems)
                throw GeneratedDataProvider.Error.notEnoughDataToGenerateCatalog(options: catalogDiscoveryOptions, underlyingError: nil)
            }
        }
        
        // For now, we only support one catalog.
        let catalog = catalogs.first!
        
        guard !context.problems.containsErrors else {
            if emitDigest {
                try outputConsumer.consume(problems: context.problems)
            }
            return (analysisProblems: context.problems, conversionProblems: [])
        }
        
        // Precompute the render context
        let renderContext = RenderContext(documentationContext: context, catalog: catalog)
        
        try outputConsumer.consume(renderReferenceStore: renderContext.store)
        
        let converter = DocumentationContextConverter(
            catalog: catalog,
            context: context,
            renderContext: renderContext,
            emitSymbolSourceFileURIs: shouldEmitSymbolSourceFileURIs,
            emitSymbolAccessLevels: shouldEmitSymbolAccessLevels
        )
        
        var indexingRecords = [IndexingRecord]()
        var linkSummaries = [LinkDestinationSummary]()
        var assets = [RenderReferenceType : [RenderReference]]()
        
        let references = context.knownPages
        let resultsSyncQueue = DispatchQueue(label: "Convert Serial Queue", qos: .unspecified, attributes: [])
        let resultsGroup = DispatchGroup()

        var coverageInfo = [CoverageDataEntry]()
        // No need to generate this closure more than once.
        let coverageFilterClosure = documentationCoverageOptions.generateFilterClosure()
        
        // Process render nodes in batches allowing us to release memory and sync after each batch
        // Keep track of any problems in case emitDigest == true
        var conversionProblems: [Problem] = references.concurrentPerform { identifier, results in
            // If cancelled skip all concurrent conversion work in this block.
            guard !isConversionCancelled() else { return }

            let source = context.documentURL(for: identifier)
            
            // Wrap JSON encoding in an autorelease pool to avoid retaining the autoreleased ObjC objects returned by `JSONSerialization`
            autoreleasepool {
                do {
                    let entity = try context.entity(with: identifier)

                    guard shouldConvertEntity(entity: entity, identifier: identifier) else {
                        return
                    }

                    guard let renderNode = try converter.renderNode(for: entity, at: source) else {
                        // No render node was produced for this entity, so just skip it.
                        return
                    }
                    
                    try outputConsumer.consume(renderNode: renderNode)

                    switch documentationCoverageOptions.level {
                    case .detailed, .brief:
                        let coverageEntry = try CoverageDataEntry(
                            documentationNode: entity,
                            renderNode: renderNode,
                            context: context
                        )
                        if coverageFilterClosure(coverageEntry) {
                            coverageInfo.append(coverageEntry)
                        }
                    case .none:
                        break
                    }
                    
                    if emitDigest {
                        let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
                        let nodeIndexingRecords = try renderNode.indexingRecords(onPage: identifier)
                        
                        resultsGroup.async(queue: resultsSyncQueue) {
                            assets.merge(renderNode.assetReferences, uniquingKeysWith: +)
                            linkSummaries.append(contentsOf: nodeLinkSummaries)
                            indexingRecords.append(contentsOf: nodeIndexingRecords)
                        }
                    }
                } catch {
                    results.append(.init(description: error.localizedDescription, source: source))
                    diagnosticEngine.emit(.init(description: error.localizedDescription, source: source))
                }
            }
        }
        
        // Wait for any concurrent updates to complete.
        resultsGroup.wait()
        
        // If cancelled, return before producing outputs.
        guard !isConversionCancelled() else { return ([], []) }
        
        // Copy images, sample files, and other static assets.
        do {
            try outputConsumer.consume(assetsInCatalog: catalog)
        } catch {
            conversionProblems.append(.init(description: error.localizedDescription, source: nil))
            diagnosticEngine.emit(.init(description: error.localizedDescription, source: nil))
        }
        
        // Write various metadata
        if emitDigest {
            do {
                try outputConsumer.consume(linkableElementSummaries: linkSummaries)
                try outputConsumer.consume(indexingRecords: indexingRecords)
                try outputConsumer.consume(assets: assets)
            } catch {
                conversionProblems.append(.init(description: error.localizedDescription, source: nil))
                diagnosticEngine.emit(.init(description: error.localizedDescription, source: nil))
            }
        }
        
        if emitDigest {
            do {
                try outputConsumer.consume(problems: context.problems + conversionProblems)
            } catch {
                conversionProblems.append(.init(description: error.localizedDescription, source: nil))
                diagnosticEngine.emit(.init(description: error.localizedDescription, source: nil))
            }
        }

        switch documentationCoverageOptions.level {
        case .detailed, .brief:
            do {
                try outputConsumer.consume(documentationCoverageInfo: coverageInfo)
            } catch {
                let problem = Problem(description: error.localizedDescription, source: nil)
                conversionProblems.append(problem)
                diagnosticEngine.emit(problem)
            }
        case .none:
            break
        }
        
        try outputConsumer.consume(
            buildMetadata: BuildMetadata(
                catalogDisplayName: catalog.displayName,
                catalogIdentifier: catalog.identifier
            )
        )
        
        // Log the duration of the convert action.
        benchmark(end: durationMetric)
        // Log the finalized topic graph checksum.
        benchmark(add: Benchmark.TopicGraphHash(context: context))
        // Log the finalized list of topic anchor sections.
        benchmark(add: Benchmark.TopicAnchorHash(context: context))
        // Log the finalized external topics checksum.
        benchmark(add: Benchmark.ExternalTopicsHash(context: context))
        // Log the peak memory.
        benchmark(add: Benchmark.PeakMemory())

        return (analysisProblems: context.problems, conversionProblems: conversionProblems)
    }
    
    /// Whether the given entity should be converted to a render node.
    private func shouldConvertEntity(
        entity: DocumentationNode,
        identifier: ResolvedTopicReference
    ) -> Bool {
        let isDocumentPathToConvert: Bool
        if let documentPathsToConvert = documentPathsToConvert {
            isDocumentPathToConvert = documentPathsToConvert.contains(identifier.path)
        } else {
            isDocumentPathToConvert = true
        }
        
        let isExternalIDToConvert: Bool
        if let externalIDsToConvert = externalIDsToConvert {
            isExternalIDToConvert = entity.symbol.map {
                externalIDsToConvert.contains($0.identifier.precise)
            } == true
        } else {
            isExternalIDToConvert = true
        }

        // If the identifier of the entity is neither in `documentPathsToConvert`
        // nor `externalIDsToConvert`, we don't convert it to a render node.
        return isDocumentPathToConvert || isExternalIDToConvert
    }
    
    enum Error: DescribedError {
        case doesNotContainCatalog(url: URL)
        
        var errorDescription: String {
            switch self {
            case .doesNotContainCatalog(let url):
                return """
                    The directory at '\(url)' and its subdirectories do not contain at least one \
                    valid documentation catalog. A documentation catalog is a directory ending in \
                    `.docc`.
                    """
            }
        }
    }
}

private extension Problem {
    /// Creates a new problem with the given description and documentation source location.
    ///
    /// Use this to provide a user-friendly description of an error,
    /// along with a direct reference to the source file and line number where you call this initializer.
    ///
    /// - Parameters:
    ///   - description: A brief description of the problem.
    ///   - source: The URL for the documentation file that caused this problem, if any.
    ///   - file: The source file where you call this initializer.
    init(description: String, source: URL?, file: String = #file) {
        let fileName = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
        
        let singleDiagnostic = Diagnostic(source: source, severity: .error, range: nil, identifier: "org.swift.docc.\(fileName)", summary: description)
        self.init(diagnostic: singleDiagnostic, possibleSolutions: [])
    }
}
