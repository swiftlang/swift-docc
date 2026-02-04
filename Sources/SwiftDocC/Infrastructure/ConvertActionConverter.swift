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

private import DocCHTML

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
    ///   - htmlContentConsumer: The consumer for HTML content that the conversion produces, or `nil` if the conversion shouldn't produce any HTML content.
    ///   - sourceRepository: The source repository where the documentation's sources are hosted.
    ///   - emitDigest: Whether the conversion should pass additional metadata output––such as linkable entities information, indexing information, or asset references by asset type––to the consumer.
    ///   - documentationCoverageOptions: The level of experimental documentation coverage information that the conversion should pass to the consumer.
    package static func convert(
        context: DocumentationContext,
        outputConsumer: some ConvertOutputConsumer & ExternalNodeConsumer,
        htmlContentConsumer: (any HTMLContentConsumer)?,
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
        
        let renderSignpostHandle = signposter.beginInterval("Render", id: signposter.makeSignpostID(), "Render \(context.knownPages.count) pages")
        
        // Render all pages and gather their supplementary "digest" information if enabled.
        let coverageFilterClosure = documentationCoverageOptions.generateFilterClosure()
        let supplementaryRenderInfo = try await context.knownPages._concurrentPerform(
            taskName: "Render",
            batchWork: { slice in
                var supplementaryRenderInfo = SupplementaryRenderInformation()
                
                for identifier in slice {
                    try autoreleasepool {
                        let entity = try context.entity(with: identifier)

                        if let htmlContentConsumer {
                            var renderer = HTMLRenderer(reference: identifier, context: context, goal: .conciseness)
                            
                            if let symbol = entity.semantic as? Symbol {
                                let renderedPageInfo = renderer.renderSymbol(symbol)
                                try htmlContentConsumer.consume(pageInfo: renderedPageInfo, forPage: identifier)
                            } else if let article = entity.semantic as? Article {
                                let renderedPageInfo = renderer.renderArticle(article)
                                try htmlContentConsumer.consume(pageInfo: renderedPageInfo, forPage: identifier)
                            }
                        }

                        guard let renderNode = converter.renderNode(for: entity) else {
                            // No render node was produced for this entity, so just skip it.
                            return
                        }
                        
                        if FeatureFlags.current.isExperimentalMarkdownOutputEnabled,
                           let markdownConsumer = outputConsumer as? (any ConvertOutputMarkdownConsumer),
                           let markdownNode = converter.markdownOutput(for: entity)
                        {
                            try markdownConsumer.consume(markdownNode: markdownNode.writable)
                            if FeatureFlags.current.isExperimentalMarkdownOutputManifestEnabled,
                               let manifest = markdownNode.manifest
                            {
                                supplementaryRenderInfo.markdownManifestDocuments.formUnion(manifest.documents)
                                supplementaryRenderInfo.markdownManifestRelationships.formUnion(manifest.relationships)
                            }
                        }

                        try outputConsumer.consume(renderNode: renderNode)

                        switch documentationCoverageOptions.level {
                        case .detailed, .brief:
                            let coverageEntry = try CoverageDataEntry(documentationNode: entity, renderNode: renderNode, context: context)
                            if coverageFilterClosure(coverageEntry) {
                                supplementaryRenderInfo.coverageInfo.append(coverageEntry)
                            }
                        case .none:
                            break
                        }
                        
                        if emitDigest {
                            let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
                            let nodeIndexingRecords = try renderNode.indexingRecords(onPage: identifier)
                            
                            supplementaryRenderInfo.assets.merge(renderNode.assetReferences, uniquingKeysWith: +)
                            supplementaryRenderInfo.linkSummaries.append(contentsOf: nodeLinkSummaries)
                            supplementaryRenderInfo.indexingRecords.append(contentsOf: nodeIndexingRecords)
                        } else if FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled {
                            let nodeLinkSummaries = entity.externallyLinkableElementSummaries(context: context, renderNode: renderNode)
                            
                            supplementaryRenderInfo.linkSummaries.append(contentsOf: nodeLinkSummaries)
                        }
                    }
                }
                
                return supplementaryRenderInfo
            },
            initialResult: SupplementaryRenderInformation(),
            combineResults: { accumulated, partialResult in
                accumulated.assets.merge(partialResult.assets, uniquingKeysWith: +)
                accumulated.linkSummaries.append(contentsOf: partialResult.linkSummaries)
                accumulated.indexingRecords.append(contentsOf: partialResult.indexingRecords)
                accumulated.coverageInfo.append(contentsOf: partialResult.coverageInfo)
                accumulated.markdownManifestDocuments.formUnion(partialResult.markdownManifestDocuments)
                accumulated.markdownManifestRelationships.formUnion(partialResult.markdownManifestRelationships)
            }
        )
        
        signposter.endInterval("Render", renderSignpostHandle)
        
        guard !Task.isCancelled else { return }
        
        // Consumes all external links and adds them into the sidebar.
        // This consumes all external links referenced across all content, and indexes them so they're available for reference in the navigator.
        // This is not ideal as it means that links outside of the Topics section can impact the content of the navigator.
        // TODO: It would be more correct to only index external links which have been curated as part of the Topics section.
        //
        // This has to run after all local nodes have been indexed because we're associating the external node with the **local** documentation's identifier,
        // which makes it possible for there be clashes between local and external render nodes.
        // When there are duplicate nodes, only the first one will be indexed,
        // so in order to prefer local entities whenever there are any clashes, we have to index external nodes second.
        // TODO: External render nodes should be associated with the correct documentation identifier.
        try signposter.withIntervalSignpost("Index external links", id: signposter.makeSignpostID()) {
            for externalLink in context.externalCache {
                // Here we're associating the external node with the **local** documentation's identifier.
                // This is needed because nodes are only considered children if the parent and child's identifier match.
                // Otherwise, the node will be considered as a separate root node and displayed separately.
                let externalRenderNode = ExternalRenderNode(externalEntity: externalLink.value, bundleIdentifier: context.inputs.id)
                try outputConsumer.consume(externalRenderNode: externalRenderNode)
            }
        }

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
        
        if FeatureFlags.current.isExperimentalMarkdownOutputManifestEnabled,
           let markdownConsumer = outputConsumer as? (any ConvertOutputMarkdownConsumer)
        {
            try markdownConsumer.consume(
                markdownManifest: MarkdownOutputManifest(
                    title: context.inputs.displayName,
                    documents: supplementaryRenderInfo.markdownManifestDocuments,
                    relationships: supplementaryRenderInfo.markdownManifestRelationships
                )
            )
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
    var markdownManifestDocuments = Set<MarkdownOutputManifest.Document>()
    var markdownManifestRelationships = Set<MarkdownOutputManifest.Relationship>()
}

private extension HTMLContentConsumer {
    func consume(pageInfo: HTMLRenderer.RenderedPageInfo, forPage reference: ResolvedTopicReference) throws {
        try consume(
            mainContent: pageInfo.content,
            metadata: (
                title: pageInfo.metadata.title,
                description: pageInfo.metadata.plainDescription
            ),
            forPage: reference
        )
    }
}
