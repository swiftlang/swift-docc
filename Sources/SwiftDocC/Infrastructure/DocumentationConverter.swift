/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A converter from a documentation bundle to an output that can be consumed by a renderer.
///
/// This protocol is primarily used for injecting mock documentation converters during testing.
///
/// ## See Also
///
/// - ``DocumentationConverter``
public protocol DocumentationConverterProtocol {
    /// Converts documentation, outputting products using the given output consumer.
    /// - Parameter outputConsumer: The output consumer for content produced during conversion.
    /// - Returns: The problems emitted during analysis of the documentation bundle and during conversion.
    /// - Throws: Throws an error if the conversion process was not able to start at all, for example if the bundle could not be read.
    /// Partial failures, such as failing to consume a single render node, are returned in the `conversionProblems` component
    /// of the returned tuple.
    mutating func convert<OutputConsumer: ConvertOutputConsumer>(
        outputConsumer: OutputConsumer
    ) throws -> (analysisProblems: [Problem], conversionProblems: [Problem])
}

/// A converter from a documentation bundle to an output that can be consumed by a renderer.
///
/// A documentation converter analyzes a documentation bundle and converts it to products that can be used by a documentation
/// renderer to render documentation. The output format of the conversion is controlled by a ``ConvertOutputConsumer``, which
/// determines what to do with the conversion products, for example, write them to disk.
///
/// You can also configure the documentation converter to emit extra metadata such as linkable entities and indexing records
/// information.
public struct DocumentationConverter: DocumentationConverterProtocol {
    let rootURL: URL?
    let emitDigest: Bool
    let documentationCoverageOptions: DocumentationCoverageOptions
    let bundleDiscoveryOptions: BundleDiscoveryOptions
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
    
    /// The source repository where the documentation's sources are hosted.
    var sourceRepository: SourceRepository?
    
    /// `true` if the conversion is cancelled.
    private var isCancelled: Synchronized<Bool>? = nil

    private var processingDurationMetric: Benchmark.Duration?

    /// Creates a documentation converter given a documentation bundle's URL.
    ///
    /// - Parameters:
    ///  - documentationBundleURL: The root URL of the documentation bundle to convert.
    ///  - emitDigest: Whether the conversion should create metadata files, such as linkable entities information.
    ///  - documentationCoverageOptions: What level of documentation coverage output should be emitted.
    ///  - currentPlatforms: The current version and beta information for platforms that may be encountered while processing symbol graph files.
    ///   that may be encountered while processing symbol graph files.
    ///  - workspace: A provided documentation workspace. Creates a new empty workspace if value is `nil`.
    ///  - context: A provided documentation context.
    ///  - dataProvider: A data provider to use when registering bundles.
    /// - Parameter fileManager: A file persistence manager
    /// - Parameter externalIDsToConvert: The external IDs of the documentation nodes to convert.
    /// - Parameter documentPathsToConvert: The paths of the documentation nodes to convert.
    /// - Parameter bundleDiscoveryOptions: Options to configure how the converter discovers documentation bundles.
    /// - Parameter emitSymbolSourceFileURIs: Whether the documentation converter should include
    ///   source file location metadata in any render nodes representing symbols it creates.
    ///
    ///   Before passing `true` please confirm that your use case doesn't include public
    ///   distribution of any created render nodes as there are filesystem privacy and security
    ///   concerns with distributing this data.
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
        bundleDiscoveryOptions: BundleDiscoveryOptions,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false,
        sourceRepository: SourceRepository? = nil,
        isCancelled: Synchronized<Bool>? = nil,
        diagnosticEngine: DiagnosticEngine = .init()
    ) {
        self.rootURL = documentationBundleURL
        self.emitDigest = emitDigest
        self.documentationCoverageOptions = documentationCoverageOptions
        self.workspace = workspace
        self.context = context
        self.dataProvider = dataProvider
        self.externalIDsToConvert = externalIDsToConvert
        self.documentPathsToConvert = documentPathsToConvert
        self.bundleDiscoveryOptions = bundleDiscoveryOptions
        self.shouldEmitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.shouldEmitSymbolAccessLevels = emitSymbolAccessLevels
        self.sourceRepository = sourceRepository
        self.isCancelled = isCancelled
        self.diagnosticEngine = diagnosticEngine
        
        // Inject current platform versions if provided
        if let currentPlatforms = currentPlatforms {
            self.context.externalMetadata.currentPlatforms = currentPlatforms
        }
    }
    
    /// Returns the first bundle in the source directory, if any.
    /// > Note: The result of this function is not cached, it reads the source directory and finds all bundles.
    public func firstAvailableBundle() -> DocumentationBundle? {
        return (try? dataProvider.bundles(options: bundleDiscoveryOptions)).map(sorted(bundles:))?.first
    }
    
    /// Sorts a list of bundles by the bundle identifier.
    private func sorted(bundles: [DocumentationBundle]) -> [DocumentationBundle] {
        return bundles.sorted(by: \.identifier)
    }
    
    mutating public func convert<OutputConsumer: ConvertOutputConsumer>(
        outputConsumer: OutputConsumer
    ) throws -> (analysisProblems: [Problem], conversionProblems: [Problem]) {
        // Unregister the current file data provider and all its bundles
        // when running repeated conversions.
        if let dataProvider = self.currentDataProvider {
            try workspace.unregisterProvider(dataProvider)
        }
        
        // Do additional context setup.
        setupContext?(&context)

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
        
        // Start bundle registration
        try workspace.registerProvider(dataProvider, options: bundleDiscoveryOptions)
        self.currentDataProvider = dataProvider

        // Bundle registration is finished - stop the timer and reset the context cancellation state.
        cancelTimer.cancel()
        cancelTimerQueue = nil
        context.setRegistrationEnabled(true)
        
        // If cancelled, return early before we emit diagnostics.
        guard !isConversionCancelled() else { return ([], []) }
        
        processingDurationMetric = benchmark(begin: Benchmark.Duration(id: "documentation-processing"))
        
        let bundles = try sorted(bundles: dataProvider.bundles(options: bundleDiscoveryOptions))
        guard !bundles.isEmpty else {
            if let rootURL = rootURL {
                throw Error.doesNotContainBundle(url: rootURL)
            } else {
                try outputConsumer.consume(problems: context.problems)
                throw GeneratedDataProvider.Error.notEnoughDataToGenerateBundle(options: bundleDiscoveryOptions, underlyingError: nil)
            }
        }
        
        // For now, we only support one bundle.
        let bundle = bundles.first!
        
        guard !context.problems.containsErrors else {
            if emitDigest {
                try outputConsumer.consume(problems: context.problems)
            }
            return (analysisProblems: context.problems, conversionProblems: [])
        }
        
        // Precompute the render context
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        
        try outputConsumer.consume(renderReferenceStore: renderContext.store)
        
        let converter = DocumentationContextConverter(
            bundle: bundle,
            context: context,
            renderContext: renderContext,
            emitSymbolSourceFileURIs: shouldEmitSymbolSourceFileURIs,
            emitSymbolAccessLevels: shouldEmitSymbolAccessLevels,
            sourceRepository: sourceRepository
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
                    recordProblem(from: error, in: &results, withIdentifier: "render-node")
                }
            }
        }
        
        // Wait for any concurrent updates to complete.
        resultsGroup.wait()
        
        // If cancelled, return before producing outputs.
        guard !isConversionCancelled() else { return ([], []) }
        
        // Copy images, sample files, and other static assets.
        do {
            try outputConsumer.consume(assetsInBundle: bundle)
        } catch {
            recordProblem(from: error, in: &conversionProblems, withIdentifier: "assets")
        }
        
        // Write various metadata
        if emitDigest {
            do {
                try outputConsumer.consume(linkableElementSummaries: linkSummaries)
                try outputConsumer.consume(indexingRecords: indexingRecords)
                try outputConsumer.consume(assets: assets)
            } catch {
                recordProblem(from: error, in: &conversionProblems, withIdentifier: "metadata")
            }
        }
        
        if emitDigest {
            do {
                try outputConsumer.consume(problems: context.problems + conversionProblems)
            } catch {
                recordProblem(from: error, in: &conversionProblems, withIdentifier: "problems")
            }
        }

        switch documentationCoverageOptions.level {
        case .detailed, .brief:
            do {
                try outputConsumer.consume(documentationCoverageInfo: coverageInfo)
            } catch {
                recordProblem(from: error, in: &conversionProblems, withIdentifier: "coverage")
            }
        case .none:
            break
        }
        
        try outputConsumer.consume(
            buildMetadata: BuildMetadata(
                bundleDisplayName: bundle.displayName,
                bundleIdentifier: bundle.identifier
            )
        )
        
        // Log the duration of the processing (after the bundle content finished registering).
        benchmark(end: processingDurationMetric)
        // Log the finalized topic graph checksum.
        benchmark(add: Benchmark.TopicGraphHash(context: context))
        // Log the finalized list of topic anchor sections.
        benchmark(add: Benchmark.TopicAnchorHash(context: context))
        // Log the finalized external topics checksum.
        benchmark(add: Benchmark.ExternalTopicsHash(context: context))
        // Log the peak memory.
        benchmark(add: Benchmark.PeakMemory())

        context.linkResolutionMismatches.reportGatheredMismatchesIfEnabled()
        
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
    
    /// Record a problem from the given error in the given problem array.
    ///
    /// Creates a ``Problem`` from the given `Error` and identifier, emits it to the
    /// ``DocumentationConverter``'s ``DiagnosticEngine``, and appends it to the given
    /// problem array.
    ///
    /// - Parameters:
    ///   - error: The error that describes the problem.
    ///   - problems: The array that the created problem should be appended to.
    ///   - identifier: A unique identifier the problem.
    private func recordProblem(
        from error: Swift.Error,
        in problems: inout [Problem],
        withIdentifier identifier: String
    ) {
        let singleDiagnostic = Diagnostic(
            source: nil,
            severity: .error,
            range: nil,
            identifier: "org.swift.docc.documentation-converter.\(identifier)",
            summary: error.localizedDescription
        )
        let problem = Problem(diagnostic: singleDiagnostic, possibleSolutions: [])
        
        diagnosticEngine.emit(problem)
        problems.append(problem)
    }
    
    enum Error: DescribedError {
        case doesNotContainBundle(url: URL)
        
        var errorDescription: String {
            switch self {
            case .doesNotContainBundle(let url):
                return """
                    The directory at '\(url)' and its subdirectories do not contain at least one \
                    valid documentation bundle. A documentation bundle is a directory ending in \
                    `.docc`.
                    """
            }
        }
    }
}
