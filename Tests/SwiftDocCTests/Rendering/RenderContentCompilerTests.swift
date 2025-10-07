/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
@testable import SwiftDocC
import XCTest

typealias Position = RenderBlockContent.CodeBlockOptions.Position

class RenderContentCompilerTests: XCTestCase {
    func testLinkOverrideTitle() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = """
        [Example](http://example.com)
        
        [Custom Title](doc:UNRESOVLED)
        
        [Custom Title](doc:article)
        
        [Custom Image Content ![random image](https://example.com/test.png)](doc:article2)
        
        <doc:UNRESOVLED>
        
        <doc:article3>
        """
        let document = Document(parsing: source)
        let expectedDump = """
        Document
        ├─ Paragraph
        │  └─ Link destination: "http://example.com"
        │     └─ Text "Example"
        ├─ Paragraph
        │  └─ Link destination: "doc:UNRESOVLED"
        │     └─ Text "Custom Title"
        ├─ Paragraph
        │  └─ Link destination: "doc:article"
        │     └─ Text "Custom Title"
        ├─ Paragraph
        │  └─ Link destination: "doc:article2"
        │     ├─ Text "Custom Image Content "
        │     └─ Image source: "https://example.com/test.png"
        │        └─ Text "random image"
        ├─ Paragraph
        │  └─ Link destination: "doc:UNRESOVLED"
        │     └─ Text "doc:UNRESOVLED"
        └─ Paragraph
           └─ Link destination: "doc:article3"
              └─ Text "doc:article3"
        """
        XCTAssertEqual(document.debugDescription(), expectedDump)

        let result = document.children.flatMap { compiler.visit($0) }
        XCTAssertEqual(result.count, 6)
        
        do {
            guard case let .paragraph(paragraph) = result[0] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let link = RenderInlineContent.reference(
                identifier: .init(forExternalLink: "http://example.com"),
                isActive: true,
                overridingTitle: nil,
                overridingTitleInlineContent: nil
            )
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [link]))
        }
        do {
            guard case let .paragraph(paragraph) = result[1] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let text = RenderInlineContent.text("Custom Title")
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [text]))
        }
        do {
            guard case let .paragraph(paragraph) = result[2] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let link = RenderInlineContent.reference(
                identifier: .init("doc://org.swift.docc.example/documentation/Test-Bundle/article"),
                isActive: true,
                overridingTitle: "Custom Title",
                overridingTitleInlineContent: [.text("Custom Title")])
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [link]))
        }
        do {
            guard case let .paragraph(paragraph) = result[3] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let link = RenderInlineContent.reference(
                identifier: .init("doc://org.swift.docc.example/documentation/Test-Bundle/article2"),
                isActive: true,
                overridingTitle: "Custom Image Content ",
                overridingTitleInlineContent: [
                    RenderInlineContent.text("Custom Image Content "),
                    RenderInlineContent.image(identifier: .init(forExternalLink: "https://example.com/test.png"), metadata: nil)
                ]
            )
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [link]))
        }
        do {
            guard case let .paragraph(paragraph) = result[4] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let text = RenderInlineContent.text("doc:UNRESOVLED")
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [text]))
        }
        do {
            guard case let .paragraph(paragraph) = result[5] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let link = RenderInlineContent.reference(
                identifier: .init("doc://org.swift.docc.example/documentation/Test-Bundle/article3"),
                isActive: true,
                overridingTitle: nil,
                overridingTitleInlineContent: nil
            )
            XCTAssertEqual(paragraph, RenderBlockContent.Paragraph(inlineContent: [link]))
        }
    }
    
    func testLineBreak() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        Backslash before new line\
        is an explicit hard line break.

        Two spaces before new line  
        is a hard line break.

        Paragraph can't end with hard line break.\

        # Headings can't end with hard line break.\

            Code blocks ignore\
            hard line breaks.

        A single space before new line
        is a soft line break.
        """#
        let document = Document(parsing: source)
        let expectedDump = #"""
        Document
        ├─ Paragraph
        │  ├─ Text "Backslash before new line"
        │  ├─ LineBreak
        │  └─ Text "is an explicit hard line break."
        ├─ Paragraph
        │  ├─ Text "Two spaces before new line"
        │  ├─ LineBreak
        │  └─ Text "is a hard line break."
        ├─ Paragraph
        │  └─ Text "Paragraph can’t end with hard line break.\"
        ├─ Heading level: 1
        │  └─ Text "Headings can’t end with hard line break.\"
        ├─ CodeBlock language: none
        │  Code blocks ignore\
        │  hard line breaks.
        └─ Paragraph
           ├─ Text "A single space before new line"
           ├─ SoftBreak
           └─ Text "is a soft line break."
        """#
        XCTAssertEqual(document.debugDescription(), expectedDump)
        let result = document.children.flatMap { compiler.visit($0) }
        XCTAssertEqual(result.count, 6)
        do {
            guard case let .paragraph(paragraph) = result[0] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let text = RenderInlineContent.text("\n")
            XCTAssertEqual(paragraph.inlineContent[1], text)
        }
        do {
            guard case let .paragraph(paragraph) = result[1] as? RenderBlockContent else {
                XCTFail("RenderContent result is not the expected RenderBlockContent.paragraph(Paragraph)")
                return
            }
            let text = RenderInlineContent.text("\n")
            XCTAssertEqual(paragraph.inlineContent[1], text)
        }
    }
    
    func testThematicBreak() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        

        let source = #"""
        
        ---
        
        """#
        let document = Document(parsing: source)
        let expectedDump = #"""
        Document
        └─ ThematicBreak
        """#
        XCTAssertEqual(document.debugDescription(), expectedDump)
        let result = document.children.flatMap { compiler.visit($0) }
        XCTAssertEqual(result.count, 1)
        do {
            let thematicBreak = RenderBlockContent.thematicBreak
            
            let documentThematicBreak = try XCTUnwrap(result[0] as? RenderBlockContent)
            
            XCTAssertEqual(documentThematicBreak, thematicBreak)
        }
    }

    func testCopyToClipboard() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift
        let x = 1
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.options?.copyToClipboard, true)
    }

    func testNoCopyToClipboard() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, nocopy
        let x = 1
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.options?.copyToClipboard, false)
    }

    func testCopyToClipboardNoLang() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```nocopy
        let x = 1
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, nil)
        XCTAssertEqual(codeListing.options?.copyToClipboard, false)
    }

    func testCopyToClipboardNoFeatureFlag() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift
        let x = 1
        ```
        """#
        let document = Document(parsing: source)
        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.options?.copyToClipboard, nil)
    }

    func testNoCopyToClipboardNoFeatureFlag() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, nocopy
        let x = 1
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift, nocopy")
        XCTAssertEqual(codeListing.options?.copyToClipboard, nil)
    }

    func testShowLineNumbers() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, showLineNumbers
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.options?.showLineNumbers, true)
    }

    func testLowercaseShowLineNumbers() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, showlinenumbers
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#
        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.options?.showLineNumbers, true)
    }

    func testWrapAndHighlight() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, wrap=20, highlight=[2]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift")
        XCTAssertEqual(codeListing.options?.wrap, 20)
        let line = Position(line: 2)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
            [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line..<line
                )
            ])
    }

    func testHighlight() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, highlight=[2]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift")
        let line = Position(line: 2)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
            [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line..<line
            )])
    }

    func testHighlightNoFeatureFlag() async throws {
        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, highlight=[2]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift, highlight=[2]")
        XCTAssertEqual(codeListing.options?.lineAnnotations, nil)
    }

    func testMultipleHighlight() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, highlight=[1, 2, 3]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift")

        let line1 = Position(line: 1)
        let line2 = Position(line: 2)
        let line3 = Position(line: 3)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
            [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line1..<line1
            ),
             RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line2..<line2
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line3..<line3
            )
            ])
    }

    func testMultipleHighlightMultipleStrikeout() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```swift, strikeout=[3,5], highlight=[1, 2, 3]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        XCTAssertEqual(codeListing.syntax, "swift")

        let line1 = Position(line: 1)
        let line2 = Position(line: 2)
        let line3 = Position(line: 3)
        let line5 = Position(line: 5)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
         [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line1..<line1
            ),
             RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line2..<line2
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line3..<line3
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "strikeout",
                range: line3..<line3
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "strikeout",
                range: line5..<line5
            )
            ])
    }

    func testLanguageNotFirstOption() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```showLineNumbers, highlight=[1, 2, 3], swift, wrap=20, strikeout=[3]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        // we expect the language to be the first option in the language line, otherwise it remains nil.
        XCTAssertEqual(codeListing.syntax, nil)
        XCTAssertEqual(codeListing.options?.showLineNumbers, true)
        XCTAssertEqual(codeListing.options?.wrap, 20)

        let line1 = Position(line: 1)
        let line2 = Position(line: 2)
        let line3 = Position(line: 3)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
            [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line1..<line1
            ),
             RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line2..<line2
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line3..<line3
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "strikeout",
                range: line3..<line3
            )
            ])
    }

    func testUnorderedArrayOptions() async throws {
        enableFeatureFlag(\.isExperimentalCodeBlockAnnotationsEnabled)

        let (bundle, context) = try await testBundleAndContext()
        var compiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = #"""
        ```highlight=[5,3,4], strikeout=[3,1]
        let a = 1
        let b = 2
        let c = 3
        let d = 4
        let e = 5
        ```
        """#

        let document = Document(parsing: source)

        let result = document.children.flatMap { compiler.visit($0) }

        let renderCodeBlock = try XCTUnwrap(result[0] as? RenderBlockContent)
        guard case let .codeListing(codeListing) = renderCodeBlock else {
            XCTFail("Expected RenderBlockContent.codeListing")
            return
        }

        let line1 = Position(line: 1)
        let line3 = Position(line: 3)
        let line4 = Position(line: 4)
        let line5 = Position(line: 5)
        XCTAssertEqual(codeListing.options?.lineAnnotations,
            [RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line5..<line5
            ),
             RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line3..<line3
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "highlight",
                range: line4..<line4
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "strikeout",
                range: line3..<line3
            ),
            RenderBlockContent.CodeBlockOptions.LineAnnotation(
                style: "strikeout",
                range: line1..<line1
            )
            ])
    }
}
