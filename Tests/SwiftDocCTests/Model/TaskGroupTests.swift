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

class SectionExtractionTests: XCTestCase {
    func testSectionHeadingIndex() {
        // No headings -> nil
        XCTAssertNil(Document(parsing: "", options: []).sectionHeadingIndex(level: 2, named: "Topics"))
        
        // Wrong level -> nil
        XCTAssertNil(Document(parsing: "# Topics", options: []).sectionHeadingIndex(level: 2, named: "Topics"))
    
        // Wrong name -> nil
        XCTAssertNil(Document(parsing: "## Topicz", options: []).sectionHeadingIndex(level: 2, named: "Topics"))

        // Correct level and name -> index 0
        XCTAssertEqual(0, Document(parsing: "## Topics", options: []).sectionHeadingIndex(level: 2, named: "Topics"))
        
        // Correct level and name -> index 1
        XCTAssertEqual(1, Document(parsing: "# Title\n\n## Topics", options: []).sectionHeadingIndex(level: 2, named: "Topics"))
    }
    
    func testIndexToNextHeading() {
        // No headings -> nil
        XCTAssertNil(Document(parsing: "", options: []).indexToNextHeading(from: 0, level: 1))
        XCTAssertNil(Document(parsing: "", options: []).indexToNextHeading(from: 0, level: 2))
        
        // Start -> wrong level -> nil
        XCTAssertNil(Document(parsing: "# Title", options: []).indexToNextHeading(from: 0, level: 2))
        
        // Start -> correct level -> index 0
        XCTAssertEqual(0, Document(parsing: "# Title", options: []).indexToNextHeading(from: 0, level: 1))
        
        // Middle -> correct level -> index 2
        do {
            let markupSource = """
                # Title

                This is a paragraph.

                ## Topics

                Topics would go here.
                """
            XCTAssertEqual(2, Document(parsing: markupSource, options: []).indexToNextHeading(from: 1, level: 2))
        }
        
        // End -> correct level -> index n
        do {
            let markupSource = """
                # Title

                This is a paragraph.

                ## Topics
                """
            XCTAssertEqual(2, Document(parsing: markupSource, options: []).indexToNextHeading(from: 2, level: 2))
        }
    }
    
    private func testNode(with document: Document) -> DocumentationNode {
        return DocumentationNode(reference: ResolvedTopicReference(bundleIdentifier: "org.swift.docc", path: "/blah", sourceLanguage: .swift), kind: .article, sourceLanguage: .swift, name: .conceptual(title: "Title"), markup: document, semantic: Semantic())
    }
    
    func testSection() {
        // Empty -> nil
        do {
            let document = Document(parsing: "", options: [])
            let markupModel = DocumentationMarkup(markup: document)
            XCTAssertNil(markupModel.discussionSection)
        }
        
        // Level != 2 -> nil
        do {
            let document = Document(parsing: "# Topics\n\nHey.\n", options: [])
            let markupModel = DocumentationMarkup(markup: document)
            XCTAssertEqual("Hey.", Paragraph(markupModel.abstractSection?.content.compactMap { $0 as? InlineMarkup } ?? []).format())
            XCTAssertNil(markupModel.discussionSection)
            XCTAssertNil(markupModel.topicsSection)
            XCTAssertNil(markupModel.seeAlsoSection)
        }
        
        // Correct heading at end, empty content
        do {
            let markupSource = """
                # Title

                Abstract.

                Some stuff.

                ## Topics
                """
            let document = Document(parsing: markupSource, options: [])
            let markupModel = DocumentationMarkup(markup: document)
            XCTAssertEqual("Abstract.", Paragraph(markupModel.abstractSection?.content.compactMap { $0 as? InlineMarkup } ?? []).format())
            XCTAssertEqual("Some stuff.", Document(markupModel.discussionSection?.content.compactMap { $0 as? Paragraph } ?? []).format())
            XCTAssertNil(markupModel.topicsSection)
            XCTAssertNil(markupModel.seeAlsoSection)
        }
        
        // Correct heading, has content
        do {
            let markupSource = """
                # Title

                Abstract.

                Some stuff.

                ## Topics

                ### A

                This is a topic about A.

                ## See Also
                
                This stuff.
                """
            let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
            let markupModel = DocumentationMarkup(markup: document)

            XCTAssertEqual("Abstract.", Paragraph(markupModel.abstractSection?.content.compactMap { $0 as? InlineMarkup } ?? []).detachedFromParent.format())
            XCTAssertEqual("Some stuff.", Document(markupModel.discussionSection?.content.compactMap { $0 as? Paragraph } ?? []).detachedFromParent.format())
            XCTAssertEqual("### A\nThis is a topic about A.", markupModel.topicsSection?.content.map { $0.detachedFromParent.format() }.joined(separator: "\n"))
            XCTAssertEqual("This stuff.", markupModel.seeAlsoSection?.content.map { $0.detachedFromParent.format() }.joined(separator: "\n"))
        }
    }
}

class TaskGroupTests: XCTestCase {
    func testTopicLinks() {
        // Empty content -> no links
        XCTAssertTrue(TaskGroup(heading: Heading(level: 1), content: []).links.isEmpty)
        
        // Content without links -> []
        do {
            let markupSource = """
                # Title

                # Topics

                - Not a link? Uh oh!
                - Not a link either!

                OWO what's this? A paragraph?
                """
            let taskGroup = TaskGroup(heading: Heading(level: 1), content: Array(Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks]).children))
            XCTAssertTrue(taskGroup.links.isEmpty)
        }
        
        // Content with links at the wrong level -> []
        do {
            let markupSource = """
                # Title

                # Topics

                - Not a link? Uh oh!
                  - <doc:/foo>
                  - <doc:/foo>
                """
            let taskGroup = TaskGroup(heading: Heading(level: 1), content: Array(Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks]).children))
            XCTAssertTrue(taskGroup.links.isEmpty)
        }
        
        // Content with links
        do {
            let markupSource = """
                # Title

                # Topics

                - <doc:/foo>
                - <notadoc:/foo>
                """
            let taskGroup = TaskGroup(heading: Heading(level: 1), content: Array(Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks]).children))
            let links = taskGroup.links
            XCTAssertEqual(1, links.count)
            
            for link in links {
                XCTAssertEqual("doc:/foo", link.destination)
            }
            
            XCTAssertEqual(3, taskGroup.content.count)
            guard let list = taskGroup.content[2] as? UnorderedList,
                list.childCount == 1,
                let remainingItem = (list.child(at: 0) as? ListItem)?.format(),
                remainingItem == "- <notadoc:/foo>" else {
                    XCTFail("Stripping task group links didn't preserve non-topic-link bullet")
                    return
            }
        }

        // Content with link links
        do {
            let markupSource = """
                # Title

                # Topics

                - [Example](http://www.example.com)
                - [Example](https://www.example.com)
                """
            let taskGroup = TaskGroup(heading: Heading(level: 1), content: Array(Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks]).children))
            let links = taskGroup.links
            XCTAssertEqual(2, links.count)
            
            XCTAssertEqual("http://www.example.com", links[0].destination)
            XCTAssertEqual("https://www.example.com", links[1].destination)
        }
    }
}
