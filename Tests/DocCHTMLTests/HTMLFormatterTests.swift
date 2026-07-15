/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import DocCHTML
import DocCCommon

struct HTMLFormatterTests {
    
    @Test
    func quotesAttributesByDefault() {
        let html = p(.class("something")) { "Some text" }
        
        #expect(htmlString(for: html) == #"<p class="something">Some text</p>"#, "The formatter quotes attributes by default")
        #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<p class=something>Some text</p>"#, "The quotes around this attributes are optional and can be omitted.")
    }
    
    @Test
    func quotesAttributesContainingWhitespace() {
        let html = p(.class("first second")) { "Some text" }
        
        #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<p class="first second">Some text</p>"#, "The quotes around this attribute are necessary and can't be omitted.")
    }
    
    @Test
    func formatsBooleanAttributesWithoutValue() {
        let html = p(.autoFocus, .hidden(.hidden)) { "Some text" }
        
        #expect(htmlString(for: html) == #"<p autofocus hidden>Some text</p>"#, "The quotes around this attribute are necessary and can't be omitted.")
    }
    
    @Test
    func formatsAttributesInOrder() {
        do {
            let html = input(.type("radio"), .name("color-scheme"), .value("light"), .checked, .hidden(.hidden))
            #expect(htmlString(for: html) == #"<input type="radio" name="color-scheme" value="light" checked hidden>"#, "Formats attributes in order")
            #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<input type=radio name=color-scheme value=light checked hidden>"#, "Formats attributes in order")
        }
        do {
            let html = input(.name("color-scheme"), .value("light"), .checked, .hidden(.hidden), .type("radio"))
            #expect(htmlString(for: html) == #"<input name="color-scheme" value="light" checked hidden type="radio">"#, "Formats attributes in order")
            #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<input name=color-scheme value=light checked hidden type=radio>"#, "Formats attributes in order")
        }
        do {
            let html = input(.value("light"), .checked, .hidden(.hidden), .type("radio"), .name("color-scheme"))
            #expect(htmlString(for: html) == #"<input value="light" checked hidden type="radio" name="color-scheme">"#, "Formats attributes in order")
            #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<input value=light checked hidden type=radio name=color-scheme>"#, "Formats attributes in order")
        }
        do {
            let html = input(.checked, .hidden(.hidden), .type("radio"), .name("color-scheme"), .value("light"))
            #expect(htmlString(for: html) == #"<input checked hidden type="radio" name="color-scheme" value="light">"#, "Formats attributes in order")
            #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<input checked hidden type=radio name=color-scheme value=light>"#, "Formats attributes in order")
        }
        do {
            let html = input(.hidden(.hidden), .type("radio"), .name("color-scheme"), .value("light"), .checked)
            #expect(htmlString(for: html) == #"<input hidden type="radio" name="color-scheme" value="light" checked>"#, "Formats attributes in order")
            #expect(htmlString(for: html, options: .omitOptionalQuotesAroundAttributeValues) == #"<input hidden type=radio name=color-scheme value=light checked>"#, "Formats attributes in order")
        }
    }
    
    @Test
    func prettyFormatsTagsOnTheirOwnLineAndTextInline() {
        let html = section {
            ul {
                li { "First" }
                li { "Second" }
                li {
                    ol {
                        li { "Third" }
                        li { "Fourth" }
                    }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <section>
          <ul>
            <li>First</li>
            <li>Second</li>
            <li>
              <ol>
                <li>Third</li>
                <li>Fourth</li>
              </ol>
            </li>
          </ul>
        </section>
        """)
    }
    
    @Test
    func prettyFormatsTextOnSeparateLineWhenContainerHasAttributes() {
        let html = ul {
            li { "Container without attribute" }
            li(.id("something")) { "Container with attribute" }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <ul>
          <li>Container without attribute</li>
          <li id="something">
            Container with attribute
          </li>
        </ul>
        """)
        
        #expect(htmlString(for: html, options: [.prettyPrint, .omitOptionalQuotesAroundAttributeValues]) == """
        <ul>
          <li>Container without attribute</li>
          <li id=something>
            Container with attribute
          </li>
        </ul>
        """)
    }
    
    @Test
    func preservesSignificantWhitespaceInPreTag() {
        let preTag = pre {
            code { "  first" }
            " "
            code { "second  " }
        }
        
        #expect(htmlString(for: preTag, options: .prettyPrint) == htmlString(for: preTag))
        #expect(htmlString(for: preTag, options: .prettyPrint) == "<pre><code>  first</code> <code>second  </code></pre>")
        
        let html = section {
            hgroup {
                h1 { "Some title" }
                p { "Some subheading" }
            }
            preTag
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <section>
          <hgroup>
            <h1>Some title</h1>
            <p>Some subheading</p>
          </hgroup>
          <pre><code>  first</code> <code>second  </code></pre>
        </section>
        """)
    }
    
    @Test
    func escapesAmpersandAndQuoteInAttribute() {
        let html = span(.title(#"' & " <>"#)) { "Some text" }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <span title="' &amp; &quot; <>">Some text</span>
        """)
    }
    
    @Test
    func escapesAmpersandAndLessThanInText() {
        let html = pre {
            code { """
                func randomACIILetter() -> UTF8.CodeUnit {
                    .random(in: .init(ascii: "a") ..< 123, using: &myGenerator)
                }
                """
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <pre><code>func randomACIILetter() -> UTF8.CodeUnit {
            .random(in: .init(ascii: "a") ..&lt; 123, using: &amp;myGenerator)
        }</code></pre>
        """)
    }
    
    @Test
    func prettyFormatsTextSemanticElementsOnSameNewLine() {
        func makeExample(paragraphAttributes: [HTMLNode.Attribute]) -> HTMLNode {
            ._element(.p, attributes: paragraphAttributes, contents: [
                .text("Some "),
                b { "bold" },
                .text(" and "),
                i { "italicized" },
                .text(" text."),
            ])
        }
        
        #expect(htmlString(for: makeExample(paragraphAttributes: [.id("something")]), options: .prettyPrint) == """
        <p id="something">
          Some <b>bold</b> and <i>italicized</i> text.
        </p>
        """)
        
        #expect(htmlString(for: makeExample(paragraphAttributes: []), options: .prettyPrint) == """
        <p>
          Some <b>bold</b> and <i>italicized</i> text.
        </p>
        """)
    }
    
    @Test
    func prettyFormatsAnchorElementSurroundedByTextOnSeparateLine() {
        // It's common for anchor elements to appear within a paragraph of formatted text.
        // These anchor elements can be hard slightly hard to read if formatted entirely inline.
        // At the same time, these anchor elements can look slightly too verbose and out of place if they take up 3 lines (because the anchor has a "href" attribute).
        // To try and address both these readability issues, the formatter presents the anchor on its own _separate_ line from the contents both before and after.
        
        let html = p(.id("something")) {
            "Some "
            b { "bold" }
            "text before a "
            a(.href("#something")) { "link" }
            " and some "
            i { "italicized" }
            " text after."
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <p id="something">
          Some <b>bold</b>text before a 
          <a href="#something">link</a>
           and some <i>italicized</i> text after.
        </p>
        """)
    }
    
    @Test
    func prettyFormatsTextContentsInlineForAnchorElementWithSingleAttribute() {
        // It's fairly common for anchors with only plain text contents to appear within headings and other elements.
        
        let anchorWithOnlyTextContents = h1(.id("something")) {
            a(.href("#something")) {
                "Some plain text"
            }
        }
        
        #expect(htmlString(for: anchorWithOnlyTextContents, options: .prettyPrint) == """
        <h1 id="something">
          <a href="#something">Some plain text</a>
        </h1>
        """)
        
        let anchorWithTwoAttributes = h1(.id("something")) {
            a(.href("#something"), .class("some-class")) {
                "Some plain text"
            }
        }
        
        #expect(htmlString(for: anchorWithTwoAttributes, options: .prettyPrint) == """
        <h1 id="something">
          <a href="#something" class="some-class">
            Some plain text
          </a>
        </h1>
        """)
        
        let anchorWithFormattedContents = h1(.id("something")) {
            a(.href("#something")) {
                "Some "
                b { "formatted" }
                " text"
            }
        }
        
        #expect(htmlString(for: anchorWithFormattedContents, options: .prettyPrint) == """
        <h1 id="something">
          <a href="#something">
            Some <b>formatted</b> text
          </a>
        </h1>
        """)
    }
    
    @Test
    func prettyFormatsTextContentsInlineForTableCellElementWithSingleAttribute() {
        // It's somewhat common for table cells to only have spanning attributes and plain text content.
        // When these spanning table cells are surrounded by other non-spanning cells, they appear more alike if both formats its plain text contents the same.
        
        let html = table {
            tbody {
                tr {
                    td {
                        "No attribute"
                    }
                    td(.colSpan(2)) {
                        "One attribute"
                    }
                    td(.colSpan(2), .id("some-id")) {
                        "Two attributes"
                    }
                }
            }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <table>
          <tbody>
            <tr>
              <td>No attribute</td>
              <td colspan="2">One attribute</td>
              <td colspan="2" id="some-id">
                Two attributes
              </td>
            </tr>
          </tbody>
        </table>
        """)
        
        #expect(htmlString(for: html, options: [.prettyPrint, .omitOptionalEndTags]) == """
        <table>
          <tbody>
            <tr>
              <td>No attribute
              <td colspan="2">One attribute
              <td colspan="2" id="some-id">
                Two attributes
          </tbody>
        </table>
        """)
    }
    
    @Test
    func prettyFormatsVoidElementContentsOnSeparateLines() {
        let html = picture {
            source(.media("(prefers-color-scheme: light)"), .src("relative/path/to/some-image.png"))
            source(.media("(prefers-color-scheme: dark)"),  .src("relative/path/to/some-image~dark.png"))
            img(.alt("Some alt text"), .decoding(.async), .loading(.lazy))
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <picture>
          <source media="(prefers-color-scheme: light)" src="relative/path/to/some-image.png">
          <source media="(prefers-color-scheme: dark)" src="relative/path/to/some-image~dark.png">
          <img alt="Some alt text" decoding="async" loading="lazy">
        </picture>
        """)
    }
    
    @Test
    func prettyFormatsTextSemanticAfterOtherElementOnSeparateLines() {
        let html = header {
            h2 { "Some header" }
            span { "Some other information" }
        }
        
        #expect(htmlString(for: html, options: .prettyPrint) == """
        <header>
          <h2>Some header</h2>
          <span>Some other information</span>
        </header>
        """)
    }
    
    @Test
    func includesOptionalEndTagsByDefault() {
        let definitionList = dl {
            dt { "range" }
            dd {
                p {
                    "The range in which to create a random value. "
                    code { "range" }
                    " must not be empty."
                }
            }
            
            dt { "range" }
            dd {
                p {
                    "The random number generator to use when creating the new random value."
                }
            }
        }
        
        #expect(htmlString(for: definitionList) == #"<dl><dt>range</dt><dd><p>The range in which to create a random value. <code>range</code> must not be empty.</p></dd><dt>range</dt><dd><p>The random number generator to use when creating the new random value.</p></dd></dl>"#)
        #expect(htmlString(for: definitionList, options: .omitOptionalEndTags) == #"<dl><dt>range<dd><p>The range in which to create a random value. <code>range</code> must not be empty.<dt>range<dd><p>The random number generator to use when creating the new random value.</dl>"#)
        
        #expect(htmlString(for: definitionList, options: .prettyPrint) == """
        <dl>
          <dt>range</dt>
          <dd>
            <p>
              The range in which to create a random value. <code>range</code> must not be empty.
            </p>
          </dd>
          <dt>range</dt>
          <dd>
            <p>The random number generator to use when creating the new random value.</p>
          </dd>
        </dl>
        """)
        #expect(htmlString(for: definitionList, options: [.prettyPrint, .omitOptionalEndTags]) == """
        <dl>
          <dt>range
          <dd>
            <p>
              The range in which to create a random value. <code>range</code> must not be empty.
          <dt>range
          <dd>
            <p>The random number generator to use when creating the new random value.
        </dl>
        """)
        
        let listOfLists = ul {
            li { "First" }
            li { "Second" }
            li {
                ol {
                    li { "Third" }
                    li { "Fourth" }
                }
            }
        }
        
        #expect(htmlString(for: listOfLists) == #"<ul><li>First</li><li>Second</li><li><ol><li>Third</li><li>Fourth</li></ol></li></ul>"#)
        #expect(htmlString(for: listOfLists, options: .omitOptionalEndTags) == #"<ul><li>First<li>Second<li><ol><li>Third<li>Fourth</ol></ul>"#)
        
        #expect(htmlString(for: listOfLists, options: .prettyPrint) == """
        <ul>
          <li>First</li>
          <li>Second</li>
          <li>
            <ol>
              <li>Third</li>
              <li>Fourth</li>
            </ol>
          </li>
        </ul>
        """)
        #expect(htmlString(for: listOfLists, options: [.prettyPrint, .omitOptionalEndTags]) == """
        <ul>
          <li>First
          <li>Second
          <li>
            <ol>
              <li>Third
              <li>Fourth
            </ol>
        </ul>
        """)
    }
}
    
private func htmlString(for element: HTMLNode, options: HTMLFormatter.Options = []) -> String {
    String(decoding: HTMLFormatter.format(element, options: options), as: UTF8.self)
}
