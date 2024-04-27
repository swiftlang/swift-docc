/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
@_spi(FileManagerProtocol) import SwiftDocCTestUtilities

class HeadingAnchorTests: XCTestCase {
    func testEncodeHeadingAnchor() throws {
        let catalogURL = try createTempFolder(content: [
            Folder(name: "unit-test.docc", content: [
                TextFile(name: "Root.md", utf8Content: """
                # My root page
                
                This single article defines two headings and links to them
                
                ### テスト
                - <doc:#テスト>
                
                ### Some heading
                - <doc:#Some-heading>
                """),
            ])
        ])
        let (_, bundle, context) = try loadBundle(from: catalogURL)
        
        let reference = try XCTUnwrap(context.soleRootModuleReference)
        let node = try context.entity(with: reference)
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let renderNode = try XCTUnwrap(converter.renderNode(for: node, at: nil))

        // Check heading anchors are encoded
        let contentSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        let headings: [RenderBlockContent.Heading] = contentSection.content.compactMap {
            if case .heading(let heading) = $0 {
                return heading
            } else {
                return nil
            }
        }
        XCTAssertEqual(headings[0].anchor, "%E3%83%86%E3%82%B9%E3%83%88")
        XCTAssertEqual(headings[1].anchor, "Some-heading")
        
        // Check links to them
        let testTopic0 = try XCTUnwrap(renderNode.references["doc://unit-test/documentation/Root#%E3%83%86%E3%82%B9%E3%83%88"] as? TopicRenderReference)
        XCTAssertEqual(testTopic0.url, "/documentation/root#%E3%83%86%E3%82%B9%E3%83%88")
        let testTopic1 = try XCTUnwrap(renderNode.references["doc://unit-test/documentation/Root#Some-heading"] as? TopicRenderReference)
        XCTAssertEqual(testTopic1.url, "/documentation/root#Some-heading")
    }
}
