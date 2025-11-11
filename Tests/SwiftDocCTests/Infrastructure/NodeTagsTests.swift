/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import TestUtilities

class NodeTagsTests: XCTestCase {
    func testSPIMetadata() async throws {
        let spiSGURL = Bundle.module.url(
            forResource: "SPI.symbols", withExtension: "json", subdirectory: "Test Resources")!
        
        let bundleFolder = Folder(name: "unit-tests.docc", content: [
            InfoPlist(displayName: "spi", identifier: "com.tests.spi"),
            CopyOfFile(original: spiSGURL),
        ])
        let tempURL = try createTemporaryDirectory().appendingPathComponent("unit-tests.docc")
        try bundleFolder.write(to: tempURL)
        
        let (_, _, context) = try await loadBundle(from: tempURL)
        
        // Verify that `Test` is marked as SPI.
        let reference = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/Minimal_docs/Test", sourceLanguage: .swift)
        let node = try XCTUnwrap(context.entity(with: reference))
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        XCTAssertTrue(symbol.isSPI)

        // Verify the render node contains the SPI tag.
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)

        XCTAssertEqual(renderNode.metadata.tags, [.spi])

        // Verify that the link to the node contains the SPI tag.
        let moduleReference = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/Minimal_docs", sourceLanguage: .swift)
        let moduleNode = try XCTUnwrap(context.entity(with: moduleReference))
        let moduleSymbol = try XCTUnwrap(moduleNode.semantic as? Symbol)

        // Verify the render node contains the SPI tag.
        var moduleTranslator = RenderNodeTranslator(context: context, identifier: node.reference)
        let moduleRenderNode = try XCTUnwrap(moduleTranslator.visit(moduleSymbol) as? RenderNode)
        let linkReference = try XCTUnwrap(moduleRenderNode.references["doc://com.tests.spi/documentation/Minimal_docs/Test"] as? TopicRenderReference)
        
        XCTAssertEqual(linkReference.tags, [.spi])
    }
}
