/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A consumer for output produced by a documentation conversion.
///
/// Types that conform to this protocol manage what to do with documentation conversion products, for example persist them to disk
/// or store them in memory.
public protocol ConvertOutputConsumer {
    /// Consumes an array of problems that were generated during a conversion.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    func consume(problems: [Problem]) throws
    
    /// Consumes a render node that was generated during a conversion.
    /// > Warning: This method might be called concurrently.
    func consume(renderNode: RenderNode) throws
    
    /// Consumes a documentation bundle with the purpose of extracting its on-disk assets.
    func consume(assetsInBundle bundle: DocumentationBundle) throws
    
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
    
    /// Consumes a markdown output node
    func consume(markdownNode: WritableMarkdownOutputNode) throws
    
    /// Consumes a markdown output manifest
    func consume(markdownManifest: MarkdownOutputManifest) throws
}

// Default implementations that discard the documentation conversion products, for consumers that don't need these
// values.
public extension ConvertOutputConsumer {
    func consume(renderReferenceStore: RenderReferenceStore) throws {}
    func consume(buildMetadata: BuildMetadata) throws {}
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws {}
    func consume(markdownNode: WritableMarkdownOutputNode) throws {}
    func consume(markdownManifest: MarkdownOutputManifest) throws {}
}

// Default implementation so that conforming types don't need to implement deprecated API.
public extension ConvertOutputConsumer {
    func consume(problems: [Problem]) throws {}
}

// A package-internal protocol that callers can cast to when they need to call `_consume(problems:)` for backwards compatibility (until `consume(problems:)` is removed).
package protocol _DeprecatedConsumeProblemsAccess {
    func _consume(problems: [Problem]) throws
}

// Because `ConvertOutputConsumer` is a public protocol, it can't conform to `_DeprecatedConsumeProblemsAccess`.
// Also, it would both be a public change and a breaking change to add a non-deprecated `_consume(problems:)` to `ConvertOutputConsumer` directly.
//
// To work around, this while still allowing callers to call `_consume(problems:)` without deprecation warnings, we wrap the consumer in a generic box (`_Deprecated`).
// This box can conform to `_DeprecatedConsumeProblemsAccess`, so the caller can cast the box to avoid the deprecation warning:
//
//     (_Deprecated(outputConsumer) as _DeprecatedConsumeProblemsAccess)._consume(problems: ...)
package struct _Deprecated<Consumer: ConvertOutputConsumer>: _DeprecatedConsumeProblemsAccess {
    private let consumer: Consumer
    package init(_ consumer: Consumer) {
        self.consumer = consumer
    }
    
    // This needs to be deprecated to be able to call `consume(problems:)` without a deprecation warning.
    @available(*, deprecated, message: "This deprecated API will be removed after 6.2 is released")
    package func _consume(problems: [Problem]) throws {
        var problems = problems
        
        if !problems.isEmpty {
            problems.insert(
                Problem(diagnostic: Diagnostic(
                    severity: .warning,
                    identifier: "org.swift.docc.DeprecatedDiagnosticsDigets",
                    summary: """
                    The 'diagnostics.json' digest file is deprecated and will be removed after 6.2 is released. \
                    Pass a `--diagnostics-file <diagnostics-file>` to specify a custom location where DocC will write a diagnostics JSON file with more information.
                    """)
                ),
                at: 0
            )
        }
        
        try consumer.consume(problems: problems)
    }
}

/// A consumer for nodes generated from external references.
///
/// Types that conform to this protocol manage what to do with external references, for example index them.
package protocol ExternalNodeConsumer {
    /// Consumes a external render node that was generated during a conversion.
    /// > Warning: This method might be called concurrently.
    func consume(externalRenderNode: ExternalRenderNode) throws
}
