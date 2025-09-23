/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SwiftDocC
import SwiftDocCTestUtilities

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
    
    func testLinksAndCodeVoiceAsTerms() async throws {
        let catalog =
            Folder(name: "unit-test.docc", content: [
                TextFile(name: "Article.md", utf8Content: """
                # Article
                
                An article with a term definition list with links as terms.
                
                - term ``someFunction(_:)``: First definition
                - term <doc:ModuleName>: Second definition
                - term `someFunction(_:)`: Third definition
                - term <doc://unit-test/documentation/ModuleName>: Fourth definition
                - term <doc://com.external.testbundle/path/to/something>: Fifth definition
                                                
                """),
            
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                    moduleName: "ModuleName",
                    symbols: [
                        .init(
                            identifier: .init(precise: "some-symbol-id", interfaceLanguage: SourceLanguage.swift.id),
                            names: .init(title: "someFunction(_:)", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["someFunction(_:)"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .func, displayName: "Kind Display Name"),
                            mixins: [:]
                        )
                    ]
                )),
            ])
            
        let resolver = TestMultiResultExternalReferenceResolver()
        resolver.entitiesToReturn["/path/to/something"] = .success(
            .init(referencePath: "/path/to/something")
        )
        
        var configuration = DocumentationContext.Configuration()
        configuration.externalDocumentationConfiguration.sources = ["com.external.testbundle": resolver]
        let context = try await load(catalog: catalog, configuration: configuration)
        
        let reference = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/unit-test/Article", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(entity)
        
        let overviewSection = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection)
        
        guard case RenderBlockContent.termList(let termList) = try XCTUnwrap(overviewSection.content.dropFirst(/* the "Overview" heading */).first) else {
            XCTFail("Unexpected kind of rendered content. Expected term list. Got \(overviewSection.content.dropFirst().first ?? "<nil>")")
            return
        }
        
        XCTAssertEqual(termList.items.count, 5)
        
        do {
            let item = termList.items.first
            XCTAssertEqual(item?.term.inlineContent, [
                .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/ModuleName/someFunction(_:)"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            XCTAssertEqual(item?.definition.content, [
                .paragraph(.init(inlineContent: [.text("First definition")]))
            ])
        }
        
        do {
            let item = termList.items.dropFirst().first
            XCTAssertEqual(item?.term.inlineContent, [
                .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/ModuleName"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            XCTAssertEqual(item?.definition.content, [
                .paragraph(.init(inlineContent: [.text("Second definition")]))
            ])
        }
        
        do {
            let item = termList.items.dropFirst(2).first
            XCTAssertEqual(item?.term.inlineContent, [
                .codeVoice(code: "someFunction(_:)")
            ])
            XCTAssertEqual(item?.definition.content, [
                .paragraph(.init(inlineContent: [.text("Third definition")]))
            ])
        }
        
        do {
            let item = termList.items.dropFirst(3).first
            XCTAssertEqual(item?.term.inlineContent, [
                .reference(identifier: RenderReferenceIdentifier("doc://unit-test/documentation/ModuleName"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            XCTAssertEqual(item?.definition.content, [
                .paragraph(.init(inlineContent: [.text("Fourth definition")]))
            ])
        }
        
        do {
            let item = termList.items.dropFirst(4).first
            XCTAssertEqual(item?.term.inlineContent, [
                .reference(identifier: RenderReferenceIdentifier("doc://com.external.testbundle/path/to/something"), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)
            ])
            XCTAssertEqual(item?.definition.content, [
                .paragraph(.init(inlineContent: [.text("Fifth definition")]))
            ])
        }
    }
    
    func testRenderingListWithAllTermListItems() async throws {
        let jsonFixtureItems = try discussionContents(fileName: "term-lists-2")
        guard jsonFixtureItems.count == 1 else {
            XCTFail("Discussion section didn't have expected number of contents")
            return
        }
        
        let context = try await makeEmptyContext()
        var renderContentCompiler = RenderContentCompiler(context: context, identifier: ResolvedTopicReference(bundleID: context.inputs.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        
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
    
    func testRenderingListWithInterleavedListItems() async throws {
        let jsonFixtureItems = try discussionContents(fileName: "term-lists-3")
        guard jsonFixtureItems.count == 4 else {
            XCTFail("Discussion section didn't have expected number of contents")
            return
        }
        
        let context = try await makeEmptyContext()
        var renderContentCompiler = RenderContentCompiler(context: context, identifier: ResolvedTopicReference(bundleID: context.inputs.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        
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
