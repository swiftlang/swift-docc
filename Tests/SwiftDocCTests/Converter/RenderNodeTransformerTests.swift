/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RenderNodeTransformerTests: XCTestCase {
    func testRemovesAutomaticallyCuratedSeeAlsoSections() throws {
        let symbolJSON = try String(contentsOf: Bundle.module.url(
            forResource: "symbol-with-automatic-see-also-section", withExtension: "json",
            subdirectory: "Converter Fixtures")!)

        let renderNode = try RenderNodeTransformer(renderNodeData: symbolJSON.data(using: .utf8)!)
            .apply(transformation: RemoveAutomaticallyCuratedSeeAlsoSectionsTransformation())

        XCTAssertEqual(renderNode.seeAlsoSections.count, 1)
        XCTAssertFalse(renderNode.seeAlsoSections[0].generated)

        XCTAssertNotNil(renderNode.references["doc://org.swift.docc.example/documentation/Reference-In-Automatic-SeeAlso-And-Fragments"])
        XCTAssertNil(renderNode.references["doc://org.swift.docc.example/documentation/Reference-From-Automatic-SeeAlso-Section-Only"])
        XCTAssertEqual(renderNode.references.count, 11)
    }
    
    func testRemovesAutomaticallyCuratedSeeAlsoSectionsPreservingReferences() throws {
        let symbolJSON = try String(contentsOf: Bundle.module.url(
            forResource: "symbol-auto-see-also-fragments-and-relationships", withExtension: "json",
            subdirectory: "Converter Fixtures")!)
        
        let originalRenderNode = try RenderNode.decode(fromJSON: Data(symbolJSON.utf8))
        XCTAssertEqual(originalRenderNode.primaryContentSections.mapFirst { $0 as? DeclarationsRenderSection }?.declarations.first?.tokens.last?.identifier,
                       "doc://org.swift.docc.example/documentation/backgroundtasks/bgtaskrequest")
        
        let renderNode = try RenderNodeTransformer(renderNodeData: symbolJSON.data(using: .utf8)!)
            .apply(transformation: RemoveAutomaticallyCuratedSeeAlsoSectionsTransformation())

        XCTAssertEqual(renderNode.seeAlsoSections.count, 0)

        XCTAssertNotNil(renderNode.references["doc://org.swift.docc.example/documentation/backgroundtasks/bgtaskrequest"])
        XCTAssertNil(renderNode.references["doc://org.swift.docc.example/documentation/backgroundtasks/bgprocessingtaskrequest"])
        XCTAssertEqual(renderNode.references.count, 7)
        XCTAssertEqual(renderNode.primaryContentSections.mapFirst { $0 as? DeclarationsRenderSection }?.declarations.first?.tokens.last?.identifier,
                       "doc://org.swift.docc.example/documentation/backgroundtasks/bgtaskrequest")
        
        let encoder = JSONEncoder()
        let output = try encoder.encode(renderNode)
        let roundTripped = try RenderNode.decode(fromJSON: output)
        
        XCTAssertEqual(output.count, try encoder.encode(roundTripped).count)
        XCTAssertEqual(roundTripped.references.count, 7)
        XCTAssertEqual(roundTripped.primaryContentSections.mapFirst { $0 as? DeclarationsRenderSection }?.declarations.first?.tokens.last?.identifier,
                       "doc://org.swift.docc.example/documentation/backgroundtasks/bgtaskrequest")
    }

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
        
        XCTAssertNil(renderNode.hierarchy)
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
