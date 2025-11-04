/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

#if canImport(os)
package import os
#endif

package enum ConvertActionConverter {
#if canImport(os)
    static package let signposter = OSSignposter(subsystem: "org.swift.docc", category: "Convert")
#else
    static package let signposter = NoOpSignposterShim()
#endif
    
    /// Converts the documentation in the given context and passes its output to a given consumer.
    ///
    /// - Parameters:
    ///   - context: The context that the bundle is a part of.
    ///   - outputConsumer: The consumer that the conversion passes outputs of the conversion to.
    ///   - sourceRepository: The source repository where the documentation's sources are hosted.
    ///   - emitDigest: Whether the conversion should pass additional metadata output––such as linkable entities information, indexing information, or asset references by asset type––to the consumer.
    ///   - documentationCoverageOptions: The level of experimental documentation coverage information that the conversion should pass to the consumer.
    package static func convert(
        context: DocumentationContext,
        outputConsumer: some ConvertOutputConsumer & ExternalNodeConsumer,
        sourceRepository: SourceRepository?,
        emitDigest: Bool,
        documentationCoverageOptions: DocumentationCoverageOptions
    ) async throws {
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
                try (_Deprecated(outputConsumer) as (any _DeprecatedConsumeProblemsAccess))._consume(problems: context.problems)
            }
            return
        }
        
        // Precompute the render context
        let renderContext = signposter.withIntervalSignpost("Build RenderContext", id: signposter.makeSignpostID()) {
            RenderContext(documentationContext: context)
        }
        try outputConsumer.consume(renderReferenceStore: renderContext.store)

        // Copy images, sample files, and other static assets.
        try outputConsumer.consume(assetsInBundle: context.inputs)
        
        let converter = DocumentationContextConverter(
            context: context,
            renderContext: renderContext,
            sourceRepository: sourceRepository
        )
          
        // Consume external links and add them into the sidebar.
        for externalLink in context.externalCache {
            // Here we're associating the external node with the **current** bundle's bundle ID.
            // This is needed because nodes are only considered children if the parent and child's bundle ID match.
            // Otherwise, the node will be considered as a separate root node and displayed separately.
            let externalRenderNode = ExternalRenderNode(externalEntity: externalLink.value, bundleIdentifier: context.inputs.id)
            try outputConsumer.consume(externalRenderNode: externalRenderNode)
        }
        
        let renderSignpostHandle = signposter.beginInterval("Render", id: signposter.makeSignpostID(), "Render \(context.knownPages.count) pages")
        
        // Render all pages and gather their supplementary "digest" information if enabled.
        let supplementaryRenderInfo = try await withThrowingTaskGroup(of: SupplementaryRenderInformation.self) { taskGroup in
            let coverageFilterClosure = documentationCoverageOptions.generateFilterClosure()
            // Iterate over all the known pages in chunks
            var remaining = context.knownPages[...]
            
            let numberOfBatches = ProcessInfo.processInfo.processorCount * 4
            let numberOfElementsPerTask = Int(Double(remaining.count) / Double(numberOfBatches) + 1)
            
            while !remaining.isEmpty {
                let slice = remaining.prefix(numberOfElementsPerTask)
                remaining = remaining.dropFirst(numberOfElementsPerTask)
                
                // Start work of one slice of the known pages
                taskGroup.addTask {
                    var supplementaryRenderInfo = SupplementaryRenderInformation()
                    
                    for identifier in slice {
                        try autoreleasepool {
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
                                    supplementaryRenderInfo.coverageInfo.append(coverageEntry)
                                }
                            case .none:
                                break
                            }
                            
                            if emitDigest {
                                let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode, includeTaskGroups: true)
                                let nodeIndexingRecords = try renderNode.indexingRecords(onPage: identifier)
                                
                                supplementaryRenderInfo.assets.merge(renderNode.assetReferences, uniquingKeysWith: +)
                                supplementaryRenderInfo.linkSummaries.append(contentsOf: nodeLinkSummaries)
                                supplementaryRenderInfo.indexingRecords.append(contentsOf: nodeIndexingRecords)
                            } else if FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
                                let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode, includeTaskGroups: false)
                                
                                supplementaryRenderInfo.linkSummaries.append(contentsOf: nodeLinkSummaries)
                            }
                        }
                    }
                    
                    return supplementaryRenderInfo
                }
            }
            
            var aggregateSupplementaryRenderInfo = SupplementaryRenderInformation()
            
            for try await partialInfo in taskGroup {
                aggregateSupplementaryRenderInfo.assets.merge(partialInfo.assets, uniquingKeysWith: +)
                aggregateSupplementaryRenderInfo.linkSummaries.append(contentsOf: partialInfo.linkSummaries)
                aggregateSupplementaryRenderInfo.indexingRecords.append(contentsOf: partialInfo.indexingRecords)
                aggregateSupplementaryRenderInfo.coverageInfo.append(contentsOf: partialInfo.coverageInfo)
            }
            
            return aggregateSupplementaryRenderInfo
        }
        
        signposter.endInterval("Render", renderSignpostHandle)
        
        guard !Task.isCancelled else { return }
        
        // Write various metadata
        if emitDigest {
            try signposter.withIntervalSignpost("Emit digest", id: signposter.makeSignpostID()) {
                try outputConsumer.consume(linkableElementSummaries: supplementaryRenderInfo.linkSummaries)
                try outputConsumer.consume(indexingRecords: supplementaryRenderInfo.indexingRecords)
                try outputConsumer.consume(assets: supplementaryRenderInfo.assets)
            }
        }
        
        if FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
            try signposter.withIntervalSignpost("Serialize link hierarchy", id: signposter.makeSignpostID()) {
                let serializableLinkInformation = try context.linkResolver.localResolver.prepareForSerialization(bundleID: context.inputs.id)
                try outputConsumer.consume(linkResolutionInformation: serializableLinkInformation)
                
                if !emitDigest {
                    try outputConsumer.consume(linkableElementSummaries: supplementaryRenderInfo.linkSummaries)
                }
            }
        }
        
        if emitDigest {
            try signposter.withIntervalSignpost("Emit digest", id: signposter.makeSignpostID()) {
                try (_Deprecated(outputConsumer) as (any _DeprecatedConsumeProblemsAccess))._consume(problems: context.problems)
            }
        }

        switch documentationCoverageOptions.level {
        case .detailed, .brief:
            try outputConsumer.consume(documentationCoverageInfo: supplementaryRenderInfo.coverageInfo)
        case .none:
            break
        }
        
        try outputConsumer.consume(buildMetadata: BuildMetadata(bundleDisplayName: context.inputs.displayName, bundleID: context.inputs.id))
        
        // Log the finalized topic graph checksum.
        benchmark(add: Benchmark.TopicGraphHash(context: context))
        // Log the finalized list of topic anchor sections.
        benchmark(add: Benchmark.TopicAnchorHash(context: context))
        // Log the finalized external topics checksum.
        benchmark(add: Benchmark.ExternalTopicsHash(context: context))
        // Log the peak memory.
        benchmark(add: Benchmark.PeakMemory())
    }
}

private struct SupplementaryRenderInformation {
    var indexingRecords = [IndexingRecord]()
    var linkSummaries = [LinkDestinationSummary]()
    var assets = [RenderReferenceType : [any RenderReference]]()
    var coverageInfo = [CoverageDataEntry]()
}
