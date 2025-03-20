/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

#if canImport(os)
import os
#endif

package enum ConvertActionConverter {
#if canImport(os)
    static package let signposter = OSSignposter(subsystem: "org.swift.docc", category: "Convert")
#else
    static package let signposter = NoOpSignposterShim()
#endif
    
    /// Converts the documentation bundle in the given context and passes its output to a given consumer.
    ///
    /// - Parameters:
    ///   - bundle: The documentation bundle to convert.
    ///   - context: The context that the bundle is a part of.
    ///   - outputConsumer: The consumer that the conversion passes outputs of the conversion to.
    ///   - sourceRepository: The source repository where the documentation's sources are hosted.
    ///   - emitDigest: Whether the conversion should pass additional metadata output––such as linkable entities information, indexing information, or asset references by asset type––to the consumer.
    ///   - documentationCoverageOptions: The level of experimental documentation coverage information that the conversion should pass to the consumer.
    /// - Returns: A list of problems that occurred during the conversion (excluding the problems that the context already encountered).
    package static func convert(
        bundle: DocumentationBundle,
        context: DocumentationContext,
        outputConsumer: some ConvertOutputConsumer,
        sourceRepository: SourceRepository?,
        emitDigest: Bool,
        documentationCoverageOptions: DocumentationCoverageOptions
    ) throws -> [Problem] {
        let signposter = Self.signposter
        
        defer {
            signposter.withIntervalSignpost("Display diagnostics", id: signposter.makeSignpostID()) {
                context.diagnosticEngine.flush()
            }
        }
        
        let processingDurationMetric = benchmark(begin: Benchmark.Duration(id: "documentation-processing"))
        defer {
            benchmark(end: processingDurationMetric)
        }
        
        guard !context.problems.containsErrors else {
            if emitDigest {
                try outputConsumer.consume(problems: context.problems)
            }
            return []
        }
        
        // Precompute the render context
        let renderContext = signposter.withIntervalSignpost("Build RenderContext", id: signposter.makeSignpostID()) {
            RenderContext(documentationContext: context, bundle: bundle)
        }
        try outputConsumer.consume(renderReferenceStore: renderContext.store)

        // Copy images, sample files, and other static assets.
        try outputConsumer.consume(assetsInBundle: bundle)
        
        let converter = DocumentationContextConverter(
            bundle: bundle,
            context: context,
            renderContext: renderContext,
            sourceRepository: sourceRepository
        )
        
        // Arrays to gather additional metadata if `emitDigest` is `true`.
        var indexingRecords = [IndexingRecord]()
        var linkSummaries = [LinkDestinationSummary]()
        var assets = [RenderReferenceType : [any RenderReference]]()
        var coverageInfo = [CoverageDataEntry]()
        let coverageFilterClosure = documentationCoverageOptions.generateFilterClosure()
        
        // An inner function to gather problems for errors encountered during the conversion.
        //
        // These problems only represent unexpected thrown errors and aren't particularly user-facing.
        // For now we emit them as diagnostics because `DocumentationConverter.convert(outputConsumer:)` (which this replaced) used to do that.
        //
        // FIXME: In the future we could simplify this control flow by not catching these errors and turning them into diagnostics.
        // Since both error-level diagnostics and thrown errors fail the documentation build,
        // the only practical different this would have is that we stop on the first unexpected error instead of processing all pages and gathering all unexpected errors.
        func recordProblem(from error: any Swift.Error, in problems: inout [Problem], withIdentifier identifier: String) {
            let problem = Problem(diagnostic: Diagnostic(
                severity: .error,
                identifier: "org.swift.docc.documentation-converter.\(identifier)",
                summary: error.localizedDescription
            ), possibleSolutions: [])
            
            context.diagnosticEngine.emit(problem)
            problems.append(problem)
        }
        
        let resultsSyncQueue = DispatchQueue(label: "Convert Serial Queue", qos: .unspecified, attributes: [])
        let resultsGroup = DispatchGroup()
        
        let renderSignpostHandle = signposter.beginInterval("Render", id: signposter.makeSignpostID(), "Render \(context.knownPages.count) pages")
        
        var conversionProblems: [Problem] = context.knownPages.concurrentPerform { identifier, results in
            // If cancelled skip all concurrent conversion work in this block.
            guard !Task.isCancelled else { return }
            
            // Wrap JSON encoding in an autorelease pool to avoid retaining the autoreleased ObjC objects returned by `JSONSerialization`
            autoreleasepool {
                do {
                    let entity = try context.entity(with: identifier)

                    guard let renderNode = converter.renderNode(for: entity) else {
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
                            resultsGroup.async(queue: resultsSyncQueue) {
                                coverageInfo.append(coverageEntry)
                            }
                        }
                    case .none:
                        break
                    }
                    
                    if emitDigest {
                        let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode, includeTaskGroups: true)
                        let nodeIndexingRecords = try renderNode.indexingRecords(onPage: identifier)
                        
                        resultsGroup.async(queue: resultsSyncQueue) {
                            assets.merge(renderNode.assetReferences, uniquingKeysWith: +)
                            linkSummaries.append(contentsOf: nodeLinkSummaries)
                            indexingRecords.append(contentsOf: nodeIndexingRecords)
                        }
                    } else if FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
                        let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode, includeTaskGroups: false)
                        
                        resultsGroup.async(queue: resultsSyncQueue) {
                            linkSummaries.append(contentsOf: nodeLinkSummaries)
                        }
                    }
                } catch {
                    recordProblem(from: error, in: &results, withIdentifier: "render-node")
                }
            }
        }
        
        // Wait for any concurrent updates to complete.
        resultsGroup.wait()
        
        signposter.endInterval("Render", renderSignpostHandle)
        
        guard !Task.isCancelled else { return [] }
        
        // Write various metadata
        if emitDigest {
            signposter.withIntervalSignpost("Emit digest", id: signposter.makeSignpostID()) {
                do {
                    try outputConsumer.consume(linkableElementSummaries: linkSummaries)
                    try outputConsumer.consume(indexingRecords: indexingRecords)
                    try outputConsumer.consume(assets: assets)
                } catch {
                    recordProblem(from: error, in: &conversionProblems, withIdentifier: "metadata")
                }
            }
        }
        
        if FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
            signposter.withIntervalSignpost("Serialize link hierarchy", id: signposter.makeSignpostID()) {
                do {
                    let serializableLinkInformation = try context.linkResolver.localResolver.prepareForSerialization(bundleID: bundle.id)
                    try outputConsumer.consume(linkResolutionInformation: serializableLinkInformation)
                    
                    if !emitDigest {
                        try outputConsumer.consume(linkableElementSummaries: linkSummaries)
                    }
                } catch {
                    recordProblem(from: error, in: &conversionProblems, withIdentifier: "link-resolver")
                }
            }
        }
        
        if emitDigest {
            signposter.withIntervalSignpost("Emit digest", id: signposter.makeSignpostID()) {
                do {
                    try outputConsumer.consume(problems: context.problems + conversionProblems)
                } catch {
                    recordProblem(from: error, in: &conversionProblems, withIdentifier: "problems")
                }
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
        
        try outputConsumer.consume(buildMetadata: BuildMetadata(bundleDisplayName: bundle.displayName, bundleID: bundle.id))
        
        // Log the finalized topic graph checksum.
        benchmark(add: Benchmark.TopicGraphHash(context: context))
        // Log the finalized list of topic anchor sections.
        benchmark(add: Benchmark.TopicAnchorHash(context: context))
        // Log the finalized external topics checksum.
        benchmark(add: Benchmark.ExternalTopicsHash(context: context))
        // Log the peak memory.
        benchmark(add: Benchmark.PeakMemory())
        
        return conversionProblems
    }
}
