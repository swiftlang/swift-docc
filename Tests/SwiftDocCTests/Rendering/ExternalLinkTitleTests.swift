/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

public class ExternalLinkTitleTests: XCTestCase {
    private func getTranslatorAndBlockContentForMarkup(_ markupSource: String) throws -> (translator: RenderNodeTranslator, content: [RenderBlockContent]) {
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        let testReference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc", path: "/test", sourceLanguage: .swift)
        let node = DocumentationNode(reference: testReference,
                                     kind: .article,
                                     sourceLanguage: .swift,
                                     name: .conceptual(title: "Title"),
                                     markup: document,
                                     semantic: Semantic())
        
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let result = translator.visit(MarkupContainer(document.children)) as! [RenderBlockContent]
        
        return (translator, result)
    }
    
    func testPlainTextExternalLinkTitle() throws {
        let markupSource = """
        # Test

        This is a plain text link: [Example](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(firstParagraph.inlineContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let expectedLinkTitle: [RenderInlineContent] = [
            .text("Example"),
        ]
        XCTAssertEqual(linkReference?.title, "Example")
        XCTAssertEqual(linkReference?.titleInlineContent, expectedLinkTitle, "Plain text title should have been rendered.")
    }
    
    func testEmphasisExternalLinkTitle() throws {
        let markupSource = """
        # Test

        This is an emphasized text link: [*Apple*](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(firstParagraph.inlineContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let expectedLinkTitle: [RenderInlineContent] = [
            .emphasis(inlineContent: [.text("Apple")]),
        ]
        XCTAssertEqual(linkReference?.title, "Apple")
        XCTAssertEqual(linkReference?.titleInlineContent, expectedLinkTitle, "Emphasized text title should have been rendered.")
    }
    
    func testStrongExternalLinkTitle() throws {
        let markupSource = """
        # Test

        This is a strong text link: [**Apple**](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(firstParagraph.inlineContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let expectedLinkTitle: [RenderInlineContent] = [
            .strong(inlineContent: [.text("Apple")]),
        ]
        XCTAssertEqual(linkReference?.title, "Apple")
        XCTAssertEqual(linkReference?.titleInlineContent, expectedLinkTitle, "Strong text title should have been rendered.")
    }
    
    func testCodeVoiceExternalLinkTitle() throws {
        let markupSource = """
        # Test

        This is a code voice text link: [`Apple`](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(firstParagraph.inlineContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let expectedLinkTitle: [RenderInlineContent] = [
            .codeVoice(code: "Apple"),
        ]
        XCTAssertEqual(linkReference?.title, "Apple")
        XCTAssertEqual(linkReference?.titleInlineContent, expectedLinkTitle, "Code voice text title should have been rendered.")
    }
    
    func testMixedExternalLinkTitle() throws {
        let markupSource = """
        # Test

        This is a mixed text link: [**This** *is* a `fancy` _link_ title.](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(firstParagraph.inlineContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let expectedLinkTitle: [RenderInlineContent] = [
            .strong(inlineContent: [.text("This")]),
            .text(" "),
            .emphasis(inlineContent: [.text("is")]),
            .text(" a "),
            .codeVoice(code: "fancy"),
            .text(" "),
            .emphasis(inlineContent: [.text("link")]),
            .text(" title."),
        ]
        XCTAssertEqual(linkReference?.title, "This is a fancy link title.")
        XCTAssertEqual(linkReference?.titleInlineContent, expectedLinkTitle, "Mixed text title should have been rendered.")
    }
    
    
    func testMultipleLinksWithEqualURL() throws {
        let markupSource = """
        # Test

        This is a strong text link: [**Apple**](https://www.example.com).
        This is an emphasized text link: [*Apple*](https://www.example.com).
        """
        
        let (translator, content) = try getTranslatorAndBlockContentForMarkup(markupSource)
        
        guard case let .paragraph(firstParagraph) = content[1] else {
            XCTFail("Unexpected render tree.")
            return
        }
        let paragraphContent = firstParagraph.inlineContent
        
        let expectedReferenceIdentifier = RenderReferenceIdentifier.init(forExternalLink: "https://www.example.com")
        XCTAssertEqual(paragraphContent[1], RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil))
        
        let linkReference = translator.linkReferences[expectedReferenceIdentifier.identifier]
        XCTAssertNotNil(linkReference, "Link reference should have been collected by translator.")
        
        let firstExpectedLinkTitle: [RenderInlineContent] = [
            .strong(inlineContent: [.text("Apple")]),
        ]
        XCTAssertEqual(linkReference?.title, "Apple")
        XCTAssertEqual(linkReference?.titleInlineContent, firstExpectedLinkTitle, "Stronge text title should have been rendered.")
        
        
        let secondExpectedLinkTitle: [RenderInlineContent] = [
            .emphasis(inlineContent: [.text("Apple")]),
        ]
        XCTAssertEqual(paragraphContent[5],
                       RenderInlineContent.reference(identifier: expectedReferenceIdentifier, isActive: true, overridingTitle: "Apple", overridingTitleInlineContent: secondExpectedLinkTitle),
                       "Second reference to same link should have overriden link title.")
    }
}
