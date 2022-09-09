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

class SubscriptSuperscriptElementsTests: XCTestCase {
    func testDecodeSubscriptSuperscriptElementsURL() throws {
        let subscriptSuperscriptElementsURL = Bundle.module.url(
            forResource: "subscript-superscript-elements", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: subscriptSuperscriptElementsURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let discussion = symbol.primaryContentSections.first as? ContentRenderSection,
            discussion.content.count == 2 else {
            XCTFail("Discussion section not decoded")
            return
        }
        
        guard case RenderBlockContent.paragraph(let contentParagraph) = discussion.content[1],
              contentParagraph.inlineContent.count == 5 else {
            XCTFail("Didn't find a paragraph element in discussion")
            return
        }
        XCTAssertEqual([
            RenderInlineContent.text("Use "),
            RenderInlineContent.subscript(inlineContent: [.text("sub")]),
            RenderInlineContent.text(" and "),
            RenderInlineContent.superscript(inlineContent: [.text("sup")]),
            RenderInlineContent.text(" to render attributed text."),
        ], contentParagraph.inlineContent)
    }
}
