/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class TableElementTests: XCTestCase {
    func testDecodeTableElementSymbol() throws {
        let tableSymbolURL = Bundle.module.url(
            forResource: "tables", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: tableSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let discussion = symbol.primaryContentSections.first as? ContentRenderSection,
            discussion.content.count == 2 else {
            XCTFail("Discussion section not decoded")
            return
        }
        
        guard case RenderBlockContent.table(let t) = discussion.content[1] else {
            XCTFail("Didn't find a table element in discussion")
            return
        }
        
        XCTAssertEqual(RenderBlockContent.HeaderType(rawValue: "row"), t.header)
        XCTAssertEqual([RenderBlockContent.TableRow(cells: [
            [RenderBlockContent.paragraph(.init(inlineContent: [RenderInlineContent.text("cell 1:1")]))],
            [RenderBlockContent.paragraph(.init(inlineContent: [RenderInlineContent.text("cell 1:2")]))],
        ])], t.rows)
        XCTAssertEqual(RenderContentMetadata(anchor: "anchor", title: "Figure 1", abstract: [RenderInlineContent.text("Tabulur data")]), t.metadata)
    }
}
