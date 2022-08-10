/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SwiftDocC

class TermListTests: XCTestCase {
    
    func discussionContents(fileName: String) throws -> [RenderBlockContent] {
        let termListSymbolURL = Bundle.module.url(
            forResource: fileName, withExtension: "json",
            subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: termListSymbolURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let discussion = symbol.primaryContentSections.first as? ContentRenderSection else {
            XCTFail("Discussion section not decoded")
            return []
        }
        
        return Array(discussion.content.dropFirst())
    }
    
    func testDecodeTermListElementSymbol() throws {
        let content = try discussionContents(fileName: "term-lists-1")
        guard content.count == 1 else {
            XCTFail("Discussion section didn't have expected number of contents")
            return
        }
        guard case let .termList(l) = content.first,
              content.count == 1 else {
            XCTFail("Term list not decoded")
            fatalError()
        }
        
        XCTAssertEqual(l.items.count, 4)
    }
    
    func testRenderingListWithAllTermListItems() throws {
        let jsonFixtureItems = try discussionContents(fileName: "term-lists-2")
        guard jsonFixtureItems.count == 1 else {
            XCTFail("Discussion section didn't have expected number of contents")
            return
        }
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: nil, sourceLanguage: .swift))
        
        let source = """
        - term First term : A paragraph that
          spans multiple lines.

        - Term Another `term`: Second definition.

          It has _multiple_ paragraphs.
        
        - term Penultimate `term`
          :*Definition* for code voice term.
          Still part of paragraph with another: colon.

        - term **Final** term :
          Definition for bold term.
        """
        let document = Document(parsing: source)
        
        // Verifies that a markdown term list renders correctly.
        
        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!) as? [RenderBlockContent])
        XCTAssertEqual(result.count, 1)
        
        let renderedTermList = try XCTUnwrap(result.first)
        
        switch renderedTermList {
        case .termList(let l):
            XCTAssertEqual(l.items.count, 4)
        default: XCTFail("Unexpected element")
        }
        
        XCTAssertEqual(jsonFixtureItems, result)
    }
    
    func testRenderingListWithInterleavedListItems() throws {
        let jsonFixtureItems = try discussionContents(fileName: "term-lists-3")
        guard jsonFixtureItems.count == 4 else {
            XCTFail("Discussion section didn't have expected number of contents")
            return
        }
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: nil, sourceLanguage: .swift))
        
        let source = """
        - Not a term list, and
          spans multiple lines.

        - term  First term item :First definition.

          It has _multiple_ paragraphs.
        
        - Term
          Second term
          item: Second definition.
        
        - TERM Another `term` : list item.
        
        - terminology not: a term list item either.

        - **Final** non-term list item
        
        - term : A paragraph
        
        - term without definition:
        """
        let document = Document(parsing: source)
        
        // Verifies that a markdown term list renders correctly.
        
        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!) as? [RenderBlockContent])
        XCTAssertEqual(result.count, 4)
        
        let firstUnorderedList = result[0]
        let firstTermList = result[1]
        let secondUnorderedList = result[2]
        let secondTermList = result[3]
        
        switch firstUnorderedList {
        case .unorderedList(let l):
            XCTAssertEqual(l.items.count, 1)
        default: XCTFail("Unexpected element")
        }
        
        switch firstTermList {
        case .termList(let l):
            XCTAssertEqual(l.items.count, 3)
        default: XCTFail("Unexpected element")
        }
        
        switch secondUnorderedList {
        case .unorderedList(let l):
            XCTAssertEqual(l.items.count, 2)
        default: XCTFail("Unexpected element")
        }
        
        switch secondTermList {
        case .termList(let l):
            XCTAssertEqual(l.items.count, 2)
        default: XCTFail("Unexpected element")
        }
        
        XCTAssertEqual(jsonFixtureItems, result)
    }
}
