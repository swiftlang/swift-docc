/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SwiftDocC

class RenderBlockContent_CapitalizationTests: XCTestCase {
    
    // MARK: - Inlines
    // Text, Emphasis, Strong are all auto-capitalized, and everything else defaults to not capitalized.
    
    func testRenderInlineContentText() {
        let text = RenderInlineContent.text("hello, world!").capitalizeFirstWord
        XCTAssertEqual("Hello, world!", text.plainText)
    }
    
    func testRenderInlineContentEmphasis() {
        let emphasis = RenderInlineContent.emphasis(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", emphasis.plainText)
    }
    
    func testRenderInlineContentStrong() {
        let strong = RenderInlineContent.strong(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", strong.plainText)
    }
    
    func testRenderInlineContentCodeVoice() {
        let codeVoice = RenderInlineContent.codeVoice(code: "code voice").capitalizeFirstWord
        XCTAssertEqual("code voice", codeVoice.plainText)
    }
    
    func testRenderInlineContentReference() {
        let reference = RenderInlineContent.reference(identifier: .init("Test"), isActive: true, overridingTitle: "hello, world!", overridingTitleInlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("hello, world!", reference.plainText)
    }
    
    func testRenderInlineContentNewTerm() {
        let newTerm = RenderInlineContent.newTerm(inlineContent: [.text("helloWorld")]).capitalizeFirstWord
        XCTAssertEqual("helloWorld", newTerm.plainText)
    }
    
    func testRenderInlineContentInlineHead() {
        let inlineHead = RenderInlineContent.inlineHead(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("hello, world!", inlineHead.plainText)
    }
    
    func testRenderInlineContentSubscript() {
        let subscriptContent = RenderInlineContent.subscript(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("hello, world!", subscriptContent.plainText)
    }
    
    func testRenderInlineContentSuperscript() {
        let superscriptContent = RenderInlineContent.superscript(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("hello, world!", superscriptContent.plainText)
    }
    
    func testRenderInlineContentStrikethrough() {
        let strikethrough = RenderInlineContent.strikethrough(inlineContent: [.text("hello, world!")]).capitalizeFirstWord
        XCTAssertEqual("hello, world!", strikethrough.plainText)
    }
    
    // MARK: - Blocks
    // Paragraphs, asides, headings, and small content are all auto-capitalized, and everything else defaults to not capitalized.
    
    func testRenderBlockContentParagraph() {
        let paragraph = RenderBlockContent.paragraph(.init(inlineContent: [.text("hello, world!")])).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", paragraph.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentAside() {
        let aside = RenderBlockContent.aside(.init(style: .init(rawValue: "Experiment"), content: [.paragraph(.init(inlineContent: [.text("hello, world!")]))])).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", aside.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentSmall() {
        let small = RenderBlockContent.small(.init(inlineContent: [.text("hello, world!")])).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", small.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentHeading() {
        let heading = RenderBlockContent.heading(.init(level: 1, text: "hello, world!", anchor: "hi")).capitalizeFirstWord
        XCTAssertEqual("Hello, world!", heading.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentUnorderedList() {
        let list = RenderBlockContent.unorderedList(.init(items: [
            .init(content: [
            .paragraph(.init(inlineContent: [.text("hello,")])),
                ]),
            .init(content: [
                .paragraph(.init(inlineContent: [.text("world!")])),
                ]),
        ])).capitalizeFirstWord
        XCTAssertEqual("hello, world!", list.rawIndexableTextContent(references: [:]))
    }
    
    func testRenderBlockContentStep() {
        let step = RenderBlockContent.step(.init(content: [.paragraph(.init(inlineContent: [.text("hello, world!")]))], caption: [.paragraph(.init(inlineContent: [.text("Step caption")]))], media: RenderReferenceIdentifier("Media"), code: RenderReferenceIdentifier("Code"), runtimePreview: RenderReferenceIdentifier("Preview"))).capitalizeFirstWord
        XCTAssertEqual("hello, world! Step caption", step.rawIndexableTextContent(references: [:]))
    }
    
    
    func testRenderBlockContentOrderedList() {
        let list = RenderBlockContent.orderedList(.init(items: [
            .init(content: [
                .paragraph(.init(inlineContent: [.text("hello,")])),
                ]),
            .init(content: [
                .paragraph(.init(inlineContent: [.text("world!")])),
                ]),
        ])).capitalizeFirstWord
        XCTAssertEqual("hello, world!", list.rawIndexableTextContent(references: [:]))
    }
    
}
