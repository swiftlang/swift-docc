/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
        return DocumentationNode(reference: ResolvedTopicReference(bundleID: "org.swift.docc", path: "/blah", sourceLanguage: .swift), kind: .article, sourceLanguage: .swift, name: .conceptual(title: "Title"), markup: document, semantic: Semantic())
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
    
    func testSupportedLanguages() throws {
        let markupSource = """
            # Title
            
            Abstract.
            
            ## Topics
            
            ### Something Swift only
            
            This link is only for Swift
            
            @SupportedLanguage(swift)
            
            - ``Link1``
            
            ### Something Objective-C only
                        
            This link is only for Objective-C
            
            @SupportedLanguage(objc)
            
            - ``Link1``
            
            ### Something for both
                        
            This link is for both Swift and Objective-C
            
            @SupportedLanguage(objc)
            @SupportedLanguage(swift)
            
            - ``Link3``
                            
            ### Something without a language filter
                        
            This link is for all languages
            
            - ``Link4``
            """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        let markupModel = DocumentationMarkup(markup: document)
        
        XCTAssertEqual("Abstract.", Paragraph(markupModel.abstractSection?.content.compactMap { $0 as? InlineMarkup } ?? []).detachedFromParent.format())
        
        let topicSection = try XCTUnwrap(markupModel.topicsSection)
        XCTAssertEqual(topicSection.taskGroups.count, 4)
        
        do {
            let taskGroup = try XCTUnwrap(topicSection.taskGroups.first)
            XCTAssertEqual(taskGroup.heading?.detachedFromParent.format(), "### Something Swift only")
            XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "This link is only for Swift")
            XCTAssertEqual(taskGroup.directives.count, 1)
            XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.count, 1)
            for directive in taskGroup.directives[SupportedLanguage.directiveName] ?? [] {
                XCTAssertEqual(directive.name, "SupportedLanguage")
                XCTAssertEqual(directive.arguments().count, 1)
            }
            XCTAssertEqual(taskGroup.links.count, 1)
        }
        
        do {
            let taskGroup = try XCTUnwrap(topicSection.taskGroups.dropFirst().first)
            XCTAssertEqual(taskGroup.heading?.detachedFromParent.format(), "### Something Objective-C only")
            XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "This link is only for Objective-C")
            XCTAssertEqual(taskGroup.directives.count, 1)
            XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.count, 1)
            for directive in taskGroup.directives[SupportedLanguage.directiveName] ?? [] {
                XCTAssertEqual(directive.name, "SupportedLanguage")
                XCTAssertEqual(directive.arguments().count, 1)
            }
            XCTAssertEqual(taskGroup.links.count, 1)
        }
        
        do {
            let taskGroup = try XCTUnwrap(topicSection.taskGroups.dropFirst(2).first)
            XCTAssertEqual(taskGroup.heading?.detachedFromParent.format(), "### Something for both")
            XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "This link is for both Swift and Objective-C")
            XCTAssertEqual(taskGroup.directives.count, 1)
            XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.count, 2)
            for directive in taskGroup.directives[SupportedLanguage.directiveName] ?? [] {
                XCTAssertEqual(directive.name, "SupportedLanguage")
                XCTAssertEqual(directive.arguments().count, 1)
            }
            XCTAssertEqual(taskGroup.links.count, 1)
        }
        
        do {
            let taskGroup = try XCTUnwrap(topicSection.taskGroups.dropFirst(3).first)
            XCTAssertEqual(taskGroup.heading?.detachedFromParent.format(), "### Something without a language filter")
            XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "This link is for all languages")
            XCTAssert(taskGroup.directives.isEmpty)
            XCTAssertEqual(taskGroup.links.count, 1)
        }
    }
    
    func testOtherDirectivesAreIgnored() throws {
        let markupSource = """
            # Title
            
            Abstract.
            
            ## Topics
            
            ### Something
            
            A mix of different directives that aren't supported in task groups.
            
            @Comment {
              Some commented out markup
            }
            
            @Metadata {
            }
            
            @SomeUnknownDirective()
            
            @SupportedLanguage(swift)
            
            - ``SomeLink``
            
            """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        let markupModel = DocumentationMarkup(markup: document)
        
        XCTAssertEqual("Abstract.", Paragraph(markupModel.abstractSection?.content.compactMap { $0 as? InlineMarkup } ?? []).detachedFromParent.format())
        
        let topicSection = try XCTUnwrap(markupModel.topicsSection)
        XCTAssertEqual(topicSection.taskGroups.count, 1)
        
        let taskGroup = try XCTUnwrap(topicSection.taskGroups.first)
        XCTAssertEqual(taskGroup.heading?.detachedFromParent.format(), "### Something")
        XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "A mix of different directives that aren’t supported in task groups.")
        XCTAssertEqual(taskGroup.directives.count, 4)
        
        XCTAssertEqual(taskGroup.directives[Comment.directiveName]?.count, 1)
        if let comment = taskGroup.directives[Comment.directiveName]?.first {
            XCTAssertEqual(comment.name, "Comment")
            XCTAssertEqual(comment.childCount, 1)
            XCTAssert(comment.arguments().isEmpty)
        }
        
        XCTAssertEqual(taskGroup.directives[Metadata.directiveName]?.count, 1)
        if let metadata = taskGroup.directives[Metadata.directiveName]?.first {
            XCTAssertEqual(metadata.name, "Metadata")
            XCTAssertEqual(metadata.childCount, 0)
                XCTAssertEqual(metadata.childCount, 0)
            XCTAssert(metadata.arguments().isEmpty)
        }
        
        if let directive = taskGroup.directives["SomeUnknownDirective"]?.first {
            XCTAssertEqual(directive.childCount, 0)
            XCTAssert(directive.arguments().isEmpty)
        }
        XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.count, 1)
        if let supportedLanguage = taskGroup.directives[SupportedLanguage.directiveName]?.first {
            XCTAssertEqual(supportedLanguage.name, "SupportedLanguage")
            XCTAssertEqual(supportedLanguage.childCount, 0)
            XCTAssertEqual(supportedLanguage.arguments().count, 1)
        }
        
        XCTAssertEqual(taskGroup.links.count, 1)
    }
    
    func testTopicContentOrder() throws {
        func assertExpectedParsedTaskGroupContent(_ content: String, file: StaticString = #filePath, line: UInt = #line) throws {
            let document = Document(parsing: """
                # Title
                
                Abstract.
                
                ## Topics
                
                \(content)
                
                """, options: [.parseBlockDirectives, .parseSymbolLinks])
            let markupModel = DocumentationMarkup(markup: document)
            
            let topicSection = try XCTUnwrap(markupModel.topicsSection, file: file, line: line)
            XCTAssertEqual(topicSection.taskGroups.count, 1, file: file, line: line)
            
            let taskGroup = try XCTUnwrap(topicSection.taskGroups.first, file: file, line: line)
            
            XCTAssertEqual(taskGroup.heading?.title, "Topic name", file: file, line: line)
            XCTAssertEqual(taskGroup.abstract?.paragraph.detachedFromParent.format(), "Abstract paragraph", file: file, line: line)
            XCTAssertEqual(taskGroup.discussion?.content.map { $0.detachedFromParent.format() }, [
                "Discussion paragraph 1",
                "Discussion paragraph 2",
            ], file: file, line: line)
            XCTAssertEqual(taskGroup.directives.count, 1, file: file, line: line)
            XCTAssertEqual(taskGroup.directives.keys.first, SupportedLanguage.directiveName, file: file, line: line)
            XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.first?.name, "SupportedLanguage", file: file, line: line)
            XCTAssertEqual(taskGroup.directives[SupportedLanguage.directiveName]?.first?.arguments().count, 1, file: file, line: line)
            XCTAssertEqual(taskGroup.links.map(\.destination), ["Link1", "Link2"], file: file, line: line)
        }
        
        try assertExpectedParsedTaskGroupContent("""
            ### Topic name
            
            Abstract paragraph
            
            Discussion paragraph 1
            
            Discussion paragraph 2
            
            @SupportedLanguage(swift)
            
            - ``Link1``
            - ``Link2``
            """)
        
        try assertExpectedParsedTaskGroupContent("""
            ### Topic name
            
            Abstract paragraph
            
            @SupportedLanguage(swift)
            
            Discussion paragraph 1
            
            Discussion paragraph 2
            
            - ``Link1``
            - ``Link2``
            """)
        
        try assertExpectedParsedTaskGroupContent("""
            ### Topic name
            
            @SupportedLanguage(swift)
            
            Abstract paragraph
            
            Discussion paragraph 1
            
            Discussion paragraph 2
            
            - ``Link1``
            - ``Link2``
            """)
        
        try assertExpectedParsedTaskGroupContent("""
            ### Topic name
            
            Abstract paragraph
            
            Discussion paragraph 1
            
            @SupportedLanguage(swift)
            
            Discussion paragraph 2
            
            - ``Link1``
            - ``Link2``
            """)
        
        try assertExpectedParsedTaskGroupContent("""
            ### Topic name
            
            Abstract paragraph
            
            Discussion paragraph 1
            
            Discussion paragraph 2
            
            - ``Link1``
            - ``Link2``
            
            @SupportedLanguage(swift)
            """)
        
    }
}
