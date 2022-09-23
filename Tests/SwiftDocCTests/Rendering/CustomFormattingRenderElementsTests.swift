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

class CustomFormattingRenderElementsTests: XCTestCase {
    func testDecodeCustomElementsSymbol() throws {
        let customElementsSymbolURL = Bundle.module.url(
            forResource: "custom-render-elements", withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: customElementsSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let discussion = symbol.primaryContentSections.first as? ContentRenderSection,
            discussion.content.count == 3 else {
            XCTFail("Didn't find discussion section")
            return
        }
        guard case RenderBlockContent.paragraph(inlineContent: let firstParagraph) = discussion.content[1] else {
            XCTFail("Didn't find discussion 1st paragraph")
            return
        }
        
        XCTAssertEqual(firstParagraph.inlineContent, [
            .text("Use "),
            .newTerm(inlineContent: [.text("www")]),
            .text(" and "),
            .inlineHead(inlineContent: [.text("ftp")]),
            .text("."),
        ])

        guard case RenderBlockContent.termList(let l) = discussion.content[2] else {
            XCTFail("Didn't find term list")
            return
        }
        
        XCTAssertEqual(l.items, [
            RenderBlockContent.TermListItem(
                term: .init(inlineContent: [
                    .text("This is a term"),
                ]),
                definition: .init(content: [
                    .paragraph(.init(inlineContent: [
                        .text("This is a definition"),
                    ])),
                ])),
        ])
    }
}
