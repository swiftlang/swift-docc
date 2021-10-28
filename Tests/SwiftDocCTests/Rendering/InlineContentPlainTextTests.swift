/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

public class InlineContentPlainTextTests: XCTestCase {
    func testPlainTextFromCodeVoice() {
        let testText = "This text is code voiced."
        
        let codeVoiceContent: [RenderInlineContent] = [
            .codeVoice(code: testText),
        ]
        
        XCTAssertEqual(codeVoiceContent.plainText, testText)
    }
    
    func testPlainTextFromEmphasis() {
        let testText = "This text is emphasized."
        
        let emphasisContent: [RenderInlineContent] = [
            .emphasis(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(emphasisContent.plainText, testText)
    }
    
    func testPlainTextFromStrong() {
        let testText = "This is strong text."
        
        let strongContent: [RenderInlineContent] = [
            .strong(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(strongContent.plainText, testText)
    }

    func testPlainTextFromImage() {
        let testText = "This is an image abstract."
        
        let firstImageContent: [RenderInlineContent] = [
            .image(identifier: RenderReferenceIdentifier("id"),
                   metadata: RenderContentMetadata(anchor: nil, title: nil, abstract: [.text(testText)])),
        ]
        
        let secondImageContent: [RenderInlineContent] = [
            .image(identifier: RenderReferenceIdentifier("id"),
                   metadata: RenderContentMetadata(anchor: nil, title: nil, abstract: nil)),
        ]
        
        XCTAssertEqual(firstImageContent.plainText, testText)
        XCTAssertEqual(secondImageContent.plainText, "")
    }
    
    func testPlainTextFromReference() {
        let testText = "This is a reference title."
        
        let firstReferenceContent: [RenderInlineContent] = [
            .reference(identifier: RenderReferenceIdentifier("test"),
                       isActive: true, overridingTitle: testText, overridingTitleInlineContent: [.text(testText)]),
        ]
        
        let secondReferenceContent: [RenderInlineContent] = [
            .reference(identifier: RenderReferenceIdentifier("test"),
                       isActive: true, overridingTitle: testText, overridingTitleInlineContent: nil),
        ]
        
        let thirdReferenceContent: [RenderInlineContent] = [
            .reference(identifier: RenderReferenceIdentifier("test"),
                       isActive: true, overridingTitle: nil, overridingTitleInlineContent: [.text(testText)]),
        ]
        
        let fourthReferenceContent: [RenderInlineContent] = [
            .reference(identifier: RenderReferenceIdentifier("test"),
                       isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil),
        ]
        
        XCTAssertEqual(firstReferenceContent.plainText, testText)
        XCTAssertEqual(secondReferenceContent.plainText, testText)
        XCTAssertEqual(thirdReferenceContent.plainText, testText)
        XCTAssertEqual(fourthReferenceContent.plainText, "")
    }
    
    func testPlainTextFromText() {
        let testText = "This is plain text."
        
        let textContent: [RenderInlineContent] = [
            .text(testText),
        ]
        
        XCTAssertEqual(textContent.plainText, testText)
    }
    
    func testPlainTextFromNewTerm() {
        let testText = "This is a new term."
        
        let newTermContent: [RenderInlineContent] = [
            .newTerm(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(newTermContent.plainText, testText)
    }
    
    func testPlainTextFromInlineHeader() {
        let testText = "This is an inline header."
        
        let inlineHeadContent: [RenderInlineContent] = [
            .inlineHead(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(inlineHeadContent.plainText, testText)
    }
    
    func testPlainTextFromSubscript() {
        let testText = "This is a subscript."
        
        let subscriptContent: [RenderInlineContent] = [
            .subscript(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(subscriptContent.plainText, testText)
    }
    
    func testPlainTextFromSuperscript() {
        let testText = "This is a superscript."
        
        let superscriptContent: [RenderInlineContent] = [
            .superscript(inlineContent: [.text(testText)]),
        ]
        
        XCTAssertEqual(superscriptContent.plainText, testText)
    }
    
    func testPlainTextFromMixed() {
        let basicMixedContent: [RenderInlineContent] = [
            .codeVoice(code: "This is code."),
            .text(" "),
            .emphasis(inlineContent: [.text("This is emphasized.")]),
            .text(" "),
            .strong(inlineContent: [.text("This is strong.")]),
            .text(" "),
            .text("This is text."),
            .text(" "),
            .newTerm(inlineContent: [.text("This is a new term.")]),
            .text(" "),
            .inlineHead(inlineContent: [.text("This is an inline header.")]),
            .text(" "),
            .subscript(inlineContent: [.text("This is a subscript.")]),
            .text(" "),
            .superscript(inlineContent: [.text("This is a superscript.")]),
        ]
        
        let expectedBasicText = "This is code. This is emphasized. This is strong. This is text. This is a new term. This is an inline header. This is a subscript. This is a superscript."
        
        XCTAssertEqual(basicMixedContent.plainText, expectedBasicText)
        
        let complicatedMixedContent: [RenderInlineContent] = [
            .codeVoice(code: basicMixedContent.plainText),
            .text(" "),
            .emphasis(inlineContent: basicMixedContent),
            .text(" "),
            .strong(inlineContent: basicMixedContent),
            .text(" "),
            .text(basicMixedContent.plainText),
            .text(" "),
            .newTerm(inlineContent: basicMixedContent),
            .text(" "),
            .inlineHead(inlineContent: basicMixedContent),
            .text(" "),
            .subscript(inlineContent: basicMixedContent),
            .text(" "),
            .superscript(inlineContent: basicMixedContent),
        ]
        
        let expectedComplicatedText = "\(expectedBasicText) \(expectedBasicText) \(expectedBasicText) \(expectedBasicText) \(expectedBasicText) \(expectedBasicText) \(expectedBasicText) \(expectedBasicText)"
        
        XCTAssertEqual(complicatedMixedContent.plainText, expectedComplicatedText)
    }
}
