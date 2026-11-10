/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
@testable import SwiftDocC
import DocCCommon
import Testing

struct TermListRenderingTests {
    @Test
    func definitionKeepsFurtherColons() async throws {
        let content = try await renderedContent("- term A: b: c")
        #expect(content == [
            .termList(.init(items: [
                termItem([.text("A")], [paragraph([.text("b: c")])]),
            ])),
        ])
    }

    @Test
    func detectsTermListNestedInDefinition() async throws {
        let content = try await renderedContent("""
        - term A: x
          - term B: y
        """)
        #expect(content == [
            .termList(.init(items: [
                termItem([.text("A")], [
                    paragraph([.text("x")]),
                    .termList(.init(items: [
                        termItem([.text("B")], [paragraph([.text("y")])]),
                    ])),
                ]),
            ])),
        ])
    }

    @Test
    func doesNotDetectTermsWithoutLeadingKeywordAndColon() async throws {
        let content = try await renderedContent("""
        - A term: not at the start
        - term without a colon
        - ```
          term Foo: in a code block
          ```
        """)
        #expect(content == [
            .unorderedList(.init(items: [
                .init(content: [paragraph([.text("A term: not at the start")])]),
                .init(content: [paragraph([.text("term without a colon")])]),
                .init(content: [
                    .codeListing(.init(
                        syntax: nil,
                        code: ["term Foo: in a code block"],
                        metadata: nil,
                        options: .init(parsingLanguageString: nil)
                    )),
                ]),
            ])),
        ])
    }

    @Test
    func orderedListIsNeverATermList() async throws {
        let content = try await renderedContent("1. term Foo: Bar.")
        #expect(content == [
            .orderedList(.init(items: [
                .init(content: [paragraph([.text("term Foo: Bar.")])]),
            ])),
        ])
    }

    @Test
    func detectsTermInTaskListItem() async throws {
        let content = try await renderedContent("- [x] term Foo: Bar.")
        #expect(content == [
            .termList(.init(items: [
                termItem([.text("Foo")], [paragraph([.text("Bar.")])]),
            ])),
        ])
    }

    @Test
    func dropsHTMLCommentFromTerm() async throws {
        let content = try await renderedContent("- term <!-- c -->Foo: Bar.")
        #expect(content == [
            .termList(.init(items: [
                termItem([.text("Foo")], [paragraph([.text("Bar.")])]),
            ])),
        ])
    }

    private func renderedContent(_ markdown: String) async throws -> [RenderBlockContent] {
        let context = try await makeEmptyContext()
        var compiler = RenderContentCompiler(
            context: context,
            identifier: ResolvedTopicReference(
                bundleID: context.inputs.id,
                path: "/path",
                sourceLanguage: .swift
            )
        )
        let list = try #require(Document(parsing: markdown).child(at: 0))
        return try #require(compiler.visit(list) as? [RenderBlockContent])
    }

    private func termItem(
        _ term: [RenderInlineContent],
        _ definition: [RenderBlockContent]
    ) -> RenderBlockContent.TermListItem {
        .init(term: .init(inlineContent: term), definition: .init(content: definition))
    }

    private func paragraph(_ inlineContent: [RenderInlineContent]) -> RenderBlockContent {
        .paragraph(.init(inlineContent: inlineContent))
    }
}
