/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RenderNodeTransformerTests: XCTestCase {
    
    func testCombinationTransformation() throws {
        let symbolJSON = try String(contentsOf: Bundle.module.url(
            forResource: "symbol-with-automatic-see-also-section", withExtension: "json",
            subdirectory: "Converter Fixtures")!)

        let renderNode = try RenderNodeTransformer(renderNodeData: symbolJSON.data(using: .utf8)!)
            .apply(transformation:
                SetMetadataTransformation(transform: { $0.title = "test title" })
                    .then(SetMetadataTransformation(transform: { $0.roleHeading = "test heading" }))
                    .then(RemoveHierarchyTransformation())
            )

        XCTAssertEqual(renderNode.metadata.title, "test title")
        XCTAssertEqual(renderNode.metadata.roleHeading, "test heading")
        
        XCTAssertNil(renderNode.hierarchyVariants.defaultValue)
        XCTAssertNil(renderNode.references["doc://org.swift.docc.example/documentation/MyKit"])

    }

    struct SetMetadataTransformation: RenderNodeTransforming {
        var transform: (inout RenderMetadata) -> Void

        func transform(renderNode: RenderNode, context: RenderNodeTransformationContext)
            -> RenderNodeTransformationResult {
            var renderNode = renderNode
            transform(&renderNode.metadata)
            return (renderNode, context)
        }
    }
}
