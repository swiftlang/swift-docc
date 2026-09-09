/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A consumer for output produced by a documentation conversion.
///
/// Types that conform to this protocol manage what to do with documentation conversion products, for example persist them to disk
/// or store them in memory.
public protocol _WillBeMadeNonPublicConvertOutputConsumer {
    /// Consumes a render node that was generated during a conversion.
    /// > Warning: This method might be called concurrently.
    func consume(renderNode: RenderNode) throws
    
    /// Consumes a collection of documentation inputs with the purpose of extracting its on-disk assets.
    func consume(assetsInInputs inputs: DocumentationContext.Inputs) throws
    
    /// Consumes the linkable element summaries produced during a conversion.
    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws
    
    /// Consumes the indexing records produced during a conversion.
    func consume(indexingRecords: [IndexingRecord]) throws
    
    /// Consumes the assets and their variants that were registered during a conversion.
    func consume(assets: [RenderReferenceType: [any RenderReference]]) throws
    
    /// Consumes benchmarks collected during a conversion.
    func consume(benchmarks: Benchmark) throws

    /// Consumes documentation coverage info created during a conversion.
    /// - note: Should only be called when doc coverage is enabled.
    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws
    
    /// Consumes a render reference store creating during a conversion.
    func consume(renderReferenceStore: RenderReferenceStore) throws
    
    /// Consumes build metadata created during a conversion.
    func consume(buildMetadata: BuildMetadata) throws
    
    /// Consumes a file representation of the local link resolution information.
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws
}

package protocol ConvertOutputMarkdownConsumer {
    /// Consumes a markdown output node
    func consume(markdownNode: WritableMarkdownOutputNode) throws
    
    /// Consumes a markdown output manifest
    func consume(markdownManifest: MarkdownOutputManifest) throws
}

// Default implementations that discard the documentation conversion products, for consumers that don't need these
// values.
public extension _WillBeMadeNonPublicConvertOutputConsumer {
    func consume(renderReferenceStore: RenderReferenceStore) throws {}
    func consume(buildMetadata: BuildMetadata) throws {}
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws {}
}

/// A consumer for nodes generated from external references.
///
/// Types that conform to this protocol manage what to do with external references, for example index them.
package protocol ExternalNodeConsumer {
    /// Consumes a external render node that was generated during a conversion.
    /// > Warning: This method might be called concurrently.
    func consume(externalRenderNode: ExternalRenderNode) throws
}

extension _WillBeMadeNonPublicConvertOutputConsumer {
    @available(*, deprecated, renamed: "consume(assetsInInputs:)", message: "Use 'consume(assetsInInputs:)' instead. This deprecated API will be removed after 6.5 is released.")
    func consume(assetsInBundle inputs: DocumentationContext.Inputs) throws {
        try consume(assetsInInputs: inputs)
    }
}

// Default implementation so that conforming types don't need to implement deprecated API.
public extension _WillBeMadeNonPublicConvertOutputConsumer {
    @available(*, deprecated)
    func consume(assetsInInputs inputs: DocumentationContext.Inputs) throws {
        // Despite this protocol being public, it's not possible to configure an output consumer from outside this package.
        // Because of this, we'll only encounter known conforming types that have been updated to use the new name.
        // This default implementation only exist for the unlikely case that an out-of-package client conforms to this protocol.
    }
}

@available(*, deprecated, message: "The output consumer is not publicly configurable. This protocol will be made non-public after 6.5 is released.")
public typealias ConvertOutputConsumer = _WillBeMadeNonPublicConvertOutputConsumer
