/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown
@testable import SwiftDocC

class DocumentationMarkupTests: XCTestCase {
    func testTitle() throws {
        // Plain text title
        do {
            let source = """
            # Title
            """
            let expected = """
            Heading level: 1
            └─ Text \"Title\"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.titleHeading?.detachedFromParent.debugDescription())
        }
        // Link title
        do {
            let source = """
            # <doc:MyArticle>
            """
            let expected = """
            Heading level: 1
            └─ Link destination: "doc:MyArticle"
               └─ Text "doc:MyArticle"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.titleHeading?.detachedFromParent.debugDescription())
        }
        // No title
        do {
            let source = """
            Abstract
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertNil(model.titleHeading)
        }
    }
    
    func testAbstract() throws {
        // Plain text abstract
        do {
            let source = """
            # Title
            My abstract __content__.
            """
            let expected = """
            Text "My abstract "
            Strong
            └─ Text "content"
            Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.abstractSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Directives before the abstract content.
        do {
            let source = """
            # Title
            @Directive {
                @NestedDirective()
            }
            My abstract __content__.
            """
            let expected = """
            BlockDirective name: "Directive"
            └─ BlockDirective name: "NestedDirective"
            Paragraph
            ├─ Text "My abstract "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertNil(model.abstractSection)
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Directives in between sections
        do {
            let source = """
            # Title
            My abstract __content__.
            @Directive {
                @NestedDirective()
            }
            More content that goes into the discussion.
            """
            let expected = """
            Text "My abstract "
            Strong
            └─ Text "content"
            Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertEqual(expected, model.abstractSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        // Missing abstract, straight to non abstract content
        do {
            let source = """
            # Title
            @Directive()
             - List item
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertNil(model.abstractSection)
        }

        // Missing abstract, Discussion heading
        do {
            let source = """
            # Title
            
            ## Discussion
            Discussion content.
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertNil(model.abstractSection)
        }

        // Missing abstract, Custom section heading
        do {
            let source = """
            # Title
            
            ## Hello, world!
            Discussion content.
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertNil(model.abstractSection)
        }
        
        // Abstract contains nested elements
        do {
            let source = """
            # Title
            ![Image title](image.jpg) Abstract.

            ## Hello, world!
            Discussion content.
            """
            let expected = """
            Image source: "image.jpg" title: ""
            └─ Text "Image title"
            Text " Abstract."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertEqual(expected, model.abstractSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Contains an HTMLBlock comment and a BlockDirective comment before the abstract
        do {
            let source = """
            # Title
            <!--Line a-->
            @Comment{
                Line b
            }
            Line c
            ## Hello, world!
            Discussion content.
            """
            let expected = """
            Text \"Line c\"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertEqual(expected, model.abstractSection?.content.map{ $0.detachedFromParent.debugDescription() }.joined(separator: "\n"))
        }
    }
    
    func testDeprecation() throws {
        // Deprecation before the abstract content.
        do {
            let source = """
            # Title
            @DeprecationSummary {
              Deprecated!
            }
            My abstract __content__.
            """
            let expected = """
            Deprecated!
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertEqual(expected, model.deprecation?.elements.map({ $0.format() }).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Deprecation after the abstract content.
        do {
            let source = """
            # Title
            My abstract __content__.

            @DeprecationSummary {
              Deprecated!
            }
            """
            let expected = """
            Deprecated!
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertEqual(expected, model.deprecation?.elements.map({ $0.format() }).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Deprecation in the discussion
        do {
            let source = """
            # Title
            My abstract __content__.

            My discussion content.
            @DeprecationSummary {
              Deprecated!
            }
            """
            let model = DocumentationMarkup(markup: Document(parsing: source, options: .parseBlockDirectives))
            XCTAssertNil(model.deprecation)
        }
    }
    
    func testDiscussion() throws {
        // Discussion heading
        do {
            let source = """
            # Title
            My abstract __content__.
            ## Discussion
            Discussion __content__.
            """
            let expected = """
            Heading level: 2
            └─ Text "Discussion"
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        
        // Overview heading
        do {
            let source = """
            # Title
            My abstract __content__.
            ## Overview
            Overview __content__.
            """
            let expected = """
            Heading level: 2
            └─ Text "Overview"
            Paragraph
            ├─ Text "Overview "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        
        // Custom heading
        do {
            let source = """
            # Title
            My abstract __content__.
            ## Hello World!
            Discussion __content__.
            """
            let expected = """
            Heading level: 2
            └─ Text "Hello World!"
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        
        // Missing heading
        do {
            let source = """
            # Title
            My abstract __content__.

            Discussion __content__.
            """
            let expected = """
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        
        // Ended by Topics
        do {
            let source = """
            # Title
            My abstract __content__.

            Discussion __content__.
            ## Topics
            ### Basics
             - <doc:link>
            """
            let expected = """
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Ended by See Also
        do {
            let source = """
            # Title
            My abstract __content__.

            Discussion __content__.
            ## See Also
             - <doc:link>
            """
            let expected = """
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Contains level-2 sub-sections
        do {
            let source = """
            # Title
            My abstract __content__.

            Discussion __content__.
            ## Sub-Section
            Sub-section content

            ## See Also
             - <doc:link>
            """
            let expected = """
            Paragraph
            ├─ Text "Discussion "
            ├─ Strong
            │  └─ Text "content"
            └─ Text "."
            Heading level: 2
            └─ Text "Sub-Section"
            Paragraph
            └─ Text "Sub-section content"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.discussionSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
    }
    
    func testTopics() throws {
        // Topics with task groups
        do {
            let source = """
            # Title
            My abstract __content__.
            ## Topics
            ### Basics
             - <doc:link>
            ### Intermediate
             - <doc:link>
            ## See Also
             - <doc:link>
            """
            let expected = """
            Heading level: 3
            └─ Text "Basics"
            UnorderedList
            └─ ListItem
               └─ Paragraph
                  └─ Link destination: "doc:link"
                     └─ Text "doc:link"
            Heading level: 3
            └─ Text "Intermediate"
            UnorderedList
            └─ ListItem
               └─ Paragraph
                  └─ Link destination: "doc:link"
                     └─ Text "doc:link"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.topicsSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }
        
        // Empty Topics section
        do {
            let source = """
            # Title
            My abstract __content__.
            ## Topics
            ## See Also
             - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertNil(model.topicsSection)
        }
    }
    
    func testSeeAlso() throws {
        // See Also with links
        do {
            let source = """
            # Title
            My abstract __content__.
            ## See Also
            See Also abstract.

            See Also discussion.
             - <doc:link>
             - <doc:link>
             - <doc:link>
            """
            let expected = """
            Paragraph
            └─ Text "See Also abstract."
            Paragraph
            └─ Text "See Also discussion."
            UnorderedList
            ├─ ListItem
            │  └─ Paragraph
            │     └─ Link destination: "doc:link"
            │        └─ Text "doc:link"
            ├─ ListItem
            │  └─ Paragraph
            │     └─ Link destination: "doc:link"
            │        └─ Text "doc:link"
            └─ ListItem
               └─ Paragraph
                  └─ Link destination: "doc:link"
                     └─ Text "doc:link"
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertEqual(expected, model.seeAlsoSection?.content.map({ $0.detachedFromParent.debugDescription() }).joined(separator: "\n"))
        }

        // Empty See Also
        do {
            let source = """
            # Title
            My abstract __content__.
            ## See Also
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertNil(model.seeAlsoSection)
        }
    }
    
    func testSkipSections() throws {
        // Parse only abstract
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source), parseUpToSection: .abstract)
            
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNil(model.discussionSection)
            XCTAssertNil(model.topicsSection)
            XCTAssertNil(model.seeAlsoSection)
        }
 
        // Parse abstract & discussion
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source), parseUpToSection: .discussion)
            
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNotNil(model.discussionSection)
            XCTAssertNil(model.topicsSection)
            XCTAssertNil(model.seeAlsoSection)
        }

        // Parse abstract & discussion & topics
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source), parseUpToSection: .topics)
            
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNotNil(model.discussionSection)
            XCTAssertNotNil(model.topicsSection)
            XCTAssertNil(model.seeAlsoSection)
        }

        // Parse abstract & discussion & topics & see also
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source), parseUpToSection: .seeAlso)
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNotNil(model.discussionSection)
            XCTAssertNotNil(model.topicsSection)
            XCTAssertNotNil(model.seeAlsoSection)
        }
        
        // Parse up to end of content
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source), parseUpToSection: .end)
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNotNil(model.discussionSection)
            XCTAssertNotNil(model.topicsSection)
            XCTAssertNotNil(model.seeAlsoSection)
        }

        // Implicitly parse up to end of content
        do {
            let source = """
            # Title
            My Abstract
            ## Discussion
            My Discussion
            ## Topics
            ### Basics
            - <doc:link>
            ## See Also
            - <doc:link>
            """
            let model = DocumentationMarkup(markup: Document(parsing: source))
            XCTAssertNotNil(model.titleHeading)
            XCTAssertNotNil(model.abstractSection)
            XCTAssertNotNil(model.discussionSection)
            XCTAssertNotNil(model.topicsSection)
            XCTAssertNotNil(model.seeAlsoSection)
        }
    }
    
    /// Test Markup.children(at:) variants.
    func testMarkupChildren() {
        let source = """
        # One
        # Two
        # Three
        # Four
        # Five
        # Six
        # Seven
        # Eight
        # Nine
        # Ten
        """
        
        let doc = Document(parsing: source)
        let lines = source.components(separatedBy: .newlines).filter({ !$0.isEmpty })
        
        // Verify that Markup.children(at:) returns the same ranges as Collection[Range]
        for index in 0 ..< lines.count {
            // Verify with half-closed ranges
            XCTAssertEqual(
                lines[index..<lines.count].joined(separator: ","),
                doc.children(at: index..<lines.count).map({ $0.format().trimmingCharacters(in: .newlines) }).joined(separator: ",")
            )
            
            // Verify with closed ranges
            XCTAssertEqual(
                lines[index...lines.count-1].joined(separator: ","),
                doc.children(at: index...lines.count-1).map({ $0.format().trimmingCharacters(in: .newlines) }).joined(separator: ",")
            )
        }
    }
    
    func testComments() {
        let source = """
        # Title
        <!--Line a-->
        
        Line b
        
        @Comment { Line c This is a single-line comment }
        
        Line d
        
        @Comment{
            Line e
        }
        
        Line f
        """
        let documentation = Document(parsing: source, options: .parseBlockDirectives)
        let expected = """
        Document
        ├─ Heading level: 1
        │  └─ Text "Title"
        ├─ HTMLBlock
        │  <!--Line a-->
        ├─ Paragraph
        │  └─ Text "Line b"
        ├─ BlockDirective name: "Comment"
        │  └─ Paragraph
        │     └─ Text "Line c This is a single-line comment"
        ├─ Paragraph
        │  └─ Text "Line d"
        ├─ BlockDirective name: "Comment"
        │  └─ Paragraph
        │     └─ Text "Line e"
        └─ Paragraph
           └─ Text "Line f"
        """
        XCTAssertEqual(expected, documentation.debugDescription())
        
        let model = DocumentationMarkup(markup: documentation)
        let expectedAbstract = """
        Text \"Line b\"
        """
        let expectedDiscussion = """
        Paragraph
        └─ Text "Line d"
        BlockDirective name: "Comment"
        └─ Paragraph
           └─ Text "Line e"
        Paragraph
        └─ Text "Line f"
        """
        XCTAssertEqual(expectedAbstract, model.abstractSection?.content.map{ $0.detachedFromParent.debugDescription() }.joined(separator: "\n"))
        XCTAssertEqual(expectedDiscussion, model.discussionSection?.content.map{ $0.detachedFromParent.debugDescription() }.joined(separator: "\n"))
    }
}
