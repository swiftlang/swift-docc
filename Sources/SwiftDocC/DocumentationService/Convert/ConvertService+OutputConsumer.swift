/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension ConvertService {
    /// Output consumer for a conversion service.
    ///
    /// This consumer stores render nodes so that they can be retrieved by the service after conversion.
    class OutputConsumer: ConvertOutputConsumer {
        var renderNodes = Synchronized<[RenderNode]>([])
        var renderReferenceStore: RenderReferenceStore?
        
        func consume(problems: [Problem]) throws {}
        
        func consume(renderNode: RenderNode) throws {
            renderNodes.sync { $0.append(renderNode) }
        }
        
        func consume(assetsInBundle bundle: DocumentationBundle) throws {}
        
        func consume(linkableElementSummaries: [LinkDestinationSummary]) throws {}
        
        func consume(indexingRecords: [IndexingRecord]) throws {}
        
        func consume(assets: [RenderReferenceType : [RenderReference]]) throws {}
        
        func consume(benchmarks: Benchmark) throws {}

        func consume(documentationCoverageInfo: [CoverageDataEntry]) throws {}
        
        func consume(renderReferenceStore: RenderReferenceStore) throws {
            self.renderReferenceStore = renderReferenceStore
        }
    }
}
