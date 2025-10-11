/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import HTML
@testable import SwiftDocC
import Markdown

final class MarkupRendererTests: XCTestCase {
 
    func testRenderParagraphsWithFormattedText() async throws {
        try assert(
            rendering: "This is a paragraph with _emphasized_ and **strong** text.",
            matches: "<p>This is a paragraph with <i>emphasized</i> and <b>strong</b> text.</p>"
        )
        
        try assert(
            rendering: "This is a paragraph with ~strikethrough~ and `pre-formatted` text.",
            matches: "<p>This is a paragraph with <s>strikethrough</s> and <code>pre-formatted</code> text.</p>"
        )
        
        try assert(
            rendering: #"This is a paragraph with "double" and 'single' quoted text."#,
            matches: "<p>This is a paragraph with “double” and ‘single’ quoted text.</p>"
        )
    }
    
    func testRenderHeadings() async throws {
        try assert(
            rendering: """
            # One
            
            ## Two
            
            ### Three
            """,
            prettyFormatted: true,
            matches: """
            <h1>One</h1>
            <h2>Two</h2>
            <h3>Three</h3>
            """
        )
        
        try assert(
            rendering: """
            One
            ===
            
            Two
            ---
            """,
            prettyFormatted: true,
            matches: """
            <h1>One</h1>
            <h2>Two</h2>
            """
        )
        
        try assert(
            rendering: """
            # _One_
            
            ## **Two**
            
            ### `Three`
            """,
            prettyFormatted: true,
            matches: """
            <h1>
            <i>One</i>
            </h1>
            <h2>
            <b>Two</b>
            </h2>
            <h3>
            <code>Three</code>
            </h3>
            """
        )
    }
    
    func testRenderTables() async throws {
        try assert(
            rendering: """
            First   | Second  | 
            ------- | ------- |
            **One** | _Two_   | 
            """,
            prettyFormatted: true,
            // It's weird that XMLNode doesn't indent the <table> children
            matches: """
            <table>
            <thead>
                <tr>
                    <th>First</th>
                    <th>Second</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>
                        <b>One</b>
                    </td>
                    <td>
                        <i>Two</i>
                    </td>
                </tr>
            </tbody>
            </table>
            """
        )
        
        try assert(
            rendering: """
            First | Second | Third |
            ----- | ------ | ----- |
            One           || Two   |
            Three | Four          ||
            Five                 |||
            """,
            prettyFormatted: true,
            // It's weird that XMLNode doesn't indent the <table> children
            matches: """
            <table>
            <thead>
                <tr>
                    <th>First</th>
                    <th>Second</th>
                    <th>Third</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td colspan="2">One</td>
                    <td>Two</td>
                </tr>
                <tr>
                    <td>Three</td>
                    <td colspan="2">Four</td>
                </tr>
                <tr>
                    <td colspan="3">Five</td>
                </tr>
            </tbody>
            </table>
            """
        )
        
        try assert(
            rendering: """
            First | Second | Third | Fourth 
            ----- | ------ | ----- | ------
            One   | Two    | Three | Four
            ^     | Five   | ^     | Six
            Seven | ^      | ^     | Eight
            """,
            prettyFormatted: true,
            // It's weird that XMLNode doesn't indent the <table> children
            matches: """
            <table>
            <thead>
                <tr>
                    <th>First</th>
                    <th>Second</th>
                    <th>Third</th>
                    <th>Fourth</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td rowspan="2">One</td>
                    <td>Two</td>
                    <td rowspan="3">Three</td>
                    <td>Four</td>
                </tr>
                <tr>
                    <td rowspan="2">Five</td>
                    <td>Six</td>
                </tr>
                <tr>
                    <td>Seven</td>
                    <td>Eight</td>
                </tr>
            </tbody>
            </table>
            """
        )
    }
    
    func testRenderLists() async throws {
        try assert(
            rendering: """
            - First
            - Second
              + A
              + B
            - Third
              1. One
              2. Two
                 * Inner
            """,
            prettyFormatted: true,
            // It's weird that XMLNode doesn't indent the outmost <ul> children
            matches: """
            <ul>
            <li>
                <p>First</p>
            </li>
            <li>
                <p>Second</p>
                <ul>
                    <li>
                        <p>A</p>
                    </li>
                    <li>
                        <p>B</p>
                    </li>
                </ul>
            </li>
            <li>
                <p>Third</p>
                <ol>
                    <li>
                        <p>One</p>
                    </li>
                    <li>
                        <p>Two</p>
                        <ul>
                            <li>
                                <p>Inner</p>
                            </li>
                        </ul>
                    </li>
                </ol>
            </li>
            </ul>
            """
        )
    }
    
    func testRenderAsides() async throws {
        try assert(
            rendering: """
            > Note: Something noteworthy
            >
            > > Important: Something important
            """,
            prettyFormatted: true,
            // It's weird that XMLNode doesn't indent the <ul> children
            matches: """
            <blockquote class="aside note">
            <p class="label">Note</p>
            <p>Something noteworthy</p>
            <blockquote class="aside important">
                <p class="label">Important</p>
                <p>Something important</p>
            </blockquote>
            </blockquote>
            """
        )
    }
    
    func testRenderCodeBlocks() async throws {
        try assert(
            rendering: """
            ~~~
            Some block of code
            ~~~
            """,
            prettyFormatted: true,
            matches: """
            <pre>
            <code>Some block of code
            </code>
            </pre>
            """
        )
        
        try assert(
            rendering: """
                Some block of code
            """,
            prettyFormatted: true,
            matches: """
            <pre>
            <code>Some block of code
            </code>
            </pre>
            """
        )
        
        try assert(
            rendering: """
            ```lang
            Some block of code
            ```
            """,
            prettyFormatted: true,
            matches: """
            <pre class="lang">
            <code>Some block of code
            </code>
            </pre>
            """
        )
        
    }
    
    func testRenderMiscellaneousElements() async throws {
        try assert(
            rendering: "First\nSecond", // new lines usually have no special meaning in markdown...
            matches: "<p>First Second</p>"
        )
        
        try assert(
            rendering: "First  \nSecond", // ... but with two trailing spaces they are treated as line breaks
            matches: "<p>First<br/>Second</p>"
        )
        
        try assert(
            rendering: """
            -------
            """,
            matches: "<hr/>"
        )
    }
    
    func testRelativeLinksToOtherPages() async throws {
        // Link to article
        try assert(
            rendering: "<doc://com.example.test/documentation/Something/SomeArticle>", // Simulate a link that's been locally resolved already
            elementToReturn: .init(
                path: try XCTUnwrap(URL(string: "doc://com.example.test/documentation/Something/SomeArticle/index.html")),
                names: .single(.conceptual("Some Article Title")),
                subheadings: .single(.conceptual("Some Article Title")), // Not relevant for inline links
                abstract: nil // Not relevant for inline links
            ),
            prettyFormatted: true,
            matches: """
            <p>
            <a href="../../SomeArticle/index.html">Some Article Title</a>
            </p>
            """
        )
        
        // Link to single-language symbol
        try assert(
            rendering: "<doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)>", // Simulate a link that's been locally resolved already
            elementToReturn: .init(
                path: try XCTUnwrap(URL(string: "doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)/index.html")),
                names: .single(.symbol("someMethod(_:_:)")),
                subheadings: .single(.symbol([ // Not relevant for inline links
                    .init(text: "func ", kind: .decorator),
                    .init(text: "someMethod", kind: .identifier),
                    .init(text: "(_:_:)", kind: .decorator),
                ])),
                abstract: nil // Not relevant for inline links
            ),
            prettyFormatted: true,
            matches: """
            <p>
            <a href="../../SomeClass/someMethod(_:_:)/index.html">
                <code>some<wbr/>
                    Method(<wbr/>
                    _:<wbr/>
                    _:)</code>
            </a>
            </p>
            """
        )
        
        // Link to symbol with multiple language representation
        try assert(
            rendering: "<doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)>", // Simulate a link that's been locally resolved already
            elementToReturn: makeExampleMethodWithDifferentLanguageRepresentations(),
            prettyFormatted: true,
            matches: """
            <p>
            <a href="../../SomeClass/someMethod(_:_:)/index.html">
                <code class="swift-only">do<wbr/>
                    Something(<wbr/>
                    with:<wbr/>
                    and:)</code>
                <code class="occ-only">do<wbr/>
                    Something<wbr/>
                    With<wbr/>
                    First:<wbr/>
                    and<wbr/>
                    Second:</code>
            </a>
            </p>
            """
        )
        
        // Link with custom title
        try assert(
            rendering: "[Custom _formatted_ title](doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:))", // Simulate a link that's been locally resolved already
            elementToReturn: makeExampleMethodWithDifferentLanguageRepresentations(),
            matches: """
            <p><a href="../../SomeClass/someMethod(_:_:)/index.html">Custom <i>formatted</i> title</a></p>
            """
        )
        
        // Link with custom symbol-like title
        try assert(
            rendering: "[Some `CustomSymbolName` title](doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:))", // Simulate a link that's been locally resolved already
            elementToReturn: makeExampleMethodWithDifferentLanguageRepresentations(),
            matches: """
            <p><a href="../../SomeClass/someMethod(_:_:)/index.html">Some <code>Custom<wbr/>Symbol<wbr/>Name</code> title</a></p>
            """
        )
    }
    
    func testRelativeLinksToImages() async throws {
        // Only a single image representation
        try assert(
            rendering: "![Some alt text](some-image.png)",
            assetToReturn: .init(images: [
                .light: [1: try XCTUnwrap(URL(string: "images/com.test.example/some-image.png"))]
            ]),
            prettyFormatted: true,
            matches: """
            <p>
            <picture>
                <img alt="Some alt text" decoding="async" loading="lazy" src="../../../../../images/com.test.example/some-image.png"/>
            </picture>
            </p>
            """
        )
        
        // Only light mode image representations
        try assert(
            rendering: "![Some alt text](some-image.png)",
            assetToReturn: .init(images: [
                .light: [
                    1: try XCTUnwrap(URL(string: "images/com.test.example/some-image.png")),
                    2: try XCTUnwrap(URL(string: "images/com.test.example/some-image@2x.png")),
                ]
            ]),
            prettyFormatted: true,
            matches: """
            <p>
            <picture>
                <img alt="Some alt text" decoding="async" loading="lazy" srcset="../../../../../images/com.test.example/some-image@2x.png 2x, ../../../../../images/com.test.example/some-image.png 1x"/>
            </picture>
            </p>
            """
        )
        
        // Only a single scale factor
        try assert(
            rendering: "![Some alt text](some-image.png)",
            assetToReturn: .init(images: [
                .light: [1: try XCTUnwrap(URL(string: "images/com.test.example/some-image.png"))],
                .dark:  [1: try XCTUnwrap(URL(string: "images/com.test.example/some-image~dark.png"))],
            ]),
            prettyFormatted: true,
            matches: """
            <p>
            <picture>
                <source media="(prefers-color-scheme: light)" src="../../../../../images/com.test.example/some-image.png"/>
                <source media="(prefers-color-scheme: dark)" src="../../../../../images/com.test.example/some-image~dark.png"/>
                <img alt="Some alt text" decoding="async" loading="lazy"/>
            </picture>
            </p>
            """
        )
        
        // Multiple styles and scale factors
        try assert(
            rendering: "![Some alt text](some-image.png)",
            assetToReturn: .init(images: [
                .light: [
                    1: try XCTUnwrap(URL(string: "images/com.test.example/some-image.png")),
                    2: try XCTUnwrap(URL(string: "images/com.test.example/some-image@2x.png")),
                ],
                .dark: [
                    1: try XCTUnwrap(URL(string: "images/com.test.example/some-image~dark.png")),
                    2: try XCTUnwrap(URL(string: "images/com.test.example/some-image~dark@2x.png")),
                ],
            ]),
            prettyFormatted: true,
            matches: """
            <p>
            <picture>
                <source media="(prefers-color-scheme: light)" srcset="../../../../../images/com.test.example/some-image@2x.png 2x, ../../../../../images/com.test.example/some-image.png 1x"/>
                <source media="(prefers-color-scheme: dark)" srcset="../../../../../images/com.test.example/some-image~dark@2x.png 2x, ../../../../../images/com.test.example/some-image~dark.png 1x"/>
                <img alt="Some alt text" decoding="async" loading="lazy"/>
            </picture>
            </p>
            """
        )
    }
    
    private func assert(
        rendering markdownContent: String,
        elementToReturn: LinkedElement? = nil,
        assetToReturn: LinkedAsset? = nil,
        prettyFormatted: Bool = false,
        matches expectedHTML: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let renderer = MarkupRenderer(
            path: URL(string: "/documentation/Something/ThisPage/index.html")!,
            linkProvider: SingleValueLinkProvider(
                elementToReturn: elementToReturn,
                assetToReturn: assetToReturn
            )
        )
        let htmlNodes = Document(parsing: markdownContent).children.map { renderer.visit($0) }
        let htmlString = htmlNodes.rendered(prettyFormatted: prettyFormatted)
        
        XCTAssertEqual(htmlString, expectedHTML, file: file, line: line)
    }
    
    private func makeExampleMethodWithDifferentLanguageRepresentations()  -> LinkedElement {
        LinkedElement(
            path: URL(string: "doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)/index.html")!,
            names: .languageSpecificSymbol([
                SourceLanguage.swift.id : "doSomething(with:and:)",
                SourceLanguage.objectiveC.id: "doSomethingWithFirst:andSecond:",
            ]),
            subheadings: .languageSpecificSymbol([ // Not relevant for inline links
                SourceLanguage.swift.id: [
                    .init(text: "func ", kind: .decorator),
                    .init(text: "doSomething", kind: .identifier),
                    .init(text: "(", kind: .decorator),
                    .init(text: "with", kind: .identifier),
                    .init(text: ":", kind: .decorator),
                    .init(text: "and", kind: .identifier),
                    .init(text: ")", kind: .decorator),
                ],
                SourceLanguage.objectiveC.id: [
                    .init(text: "doSomethingWithFirst", kind: .identifier),
                    .init(text: ":", kind: .decorator),
                    .init(text: "andSecond", kind: .identifier),
                    .init(text: ":", kind: .decorator),
                ]
            ]),
            abstract: nil // Not relevant for inline links
        )
    }
}

// MARK: Helpers

extension XMLNode {
    func rendered(prettyFormatted: Bool) -> String {
        if prettyFormatted {
            xmlString(options: [.nodePrettyPrint, .nodeCompactEmptyElement])
        } else {
            xmlString(options: .nodeCompactEmptyElement)
        }
    }
}

extension Sequence<XMLNode> {
    func rendered(prettyFormatted: Bool) -> String {
        map { $0.rendered(prettyFormatted: prettyFormatted) }
            .joined(separator: prettyFormatted ? "\n" : "")
    }
}

struct SingleValueLinkProvider: LinkProvider {
    var elementToReturn: LinkedElement?
    func element(for path: URL) -> LinkedElement? {
        elementToReturn
    }
    
    var assetToReturn: LinkedAsset?
    func assetNamed(_ assetName: String) -> LinkedAsset? {
        assetToReturn
    }
}
