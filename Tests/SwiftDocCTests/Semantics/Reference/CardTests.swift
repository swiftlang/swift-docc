/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import SwiftDocC
import SymbolKit
import DocCTestUtilities

struct CardTests {
    /// A configuration with the card directive feature flag enabled.
    static var cardEnabledConfiguration: DocumentationContext.Configuration {
        var configuration = DocumentationContext.Configuration()
        configuration.featureFlags.isExperimentalCardDirectiveEnabled = true
        return configuration
    }

    @Test
    func emitsWarningWithNoContent() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self, configuration: Self.cardEnabledConfiguration) {
            """
            @Card
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems == ["1: warning – org.swift.docc.Card.HasContent"])
        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(head: [], content: []))
        ])
    }

    @Test
    func rendersWithHeadAndContentSections() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self, configuration: Self.cardEnabledConfiguration) {
            """
            @Card {
                ### Example heading

                Some head content.

                ---

                Some body content.

                Another body paragraph.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                head: [
                    .heading(.init(level: 3, text: "Example heading", anchor: "Example-heading")),
                    .paragraph(.init(inlineContent: [.text("Some head content.")])),
                ],
                content: [
                    .paragraph(.init(inlineContent: [.text("Some body content.")])),
                    .paragraph(.init(inlineContent: [.text("Another body paragraph.")])),
                ]
            ))
        ])
    }

    @Test
    func rendersWithContentSectionOnly() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self, configuration: Self.cardEnabledConfiguration) {
            """
            @Card {
                First paragraph.

                Second paragraph.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                head: [],
                content: [
                    .paragraph(.init(inlineContent: [.text("First paragraph.")])),
                    .paragraph(.init(inlineContent: [.text("Second paragraph.")])),
                ]
            ))
        ])
    }

    @Test
    func rendersWithHeadingsInBothSections() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self, configuration: Self.cardEnabledConfiguration) {
            """
            @Card {
                ### First heading

                Head paragraph.

                ---

                ### Second heading

                Body paragraph.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                head: [
                    .heading(.init(level: 3, text: "First heading", anchor: "First-heading")),
                    .paragraph(.init(inlineContent: [.text("Head paragraph.")])),
                ],
                content: [
                    .heading(.init(level: 3, text: "Second heading", anchor: "Second-heading")),
                    .paragraph(.init(inlineContent: [.text("Body paragraph.")])),
                ]
            ))
        ])
    }

    @Test
    func onlyPartitionsHeadAndContentSectionsUsingFirstThematicBreak() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self, configuration: Self.cardEnabledConfiguration) {
            """
            @Card {
                ### Heading one

                In head section

                ---

                ### Heading two

                In content section

                ---

                ### Heading three

                Still in content section
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                head: [
                    .heading(.init(level: 3, text: "Heading one", anchor: "Heading-one")),
                    .paragraph(.init(inlineContent: [.text("In head section")])),
                ],
                content: [
                    .heading(.init(level: 3, text: "Heading two", anchor: "Heading-two")),
                    .paragraph(.init(inlineContent: [.text("In content section")])),
                    .thematicBreak,
                    .heading(.init(level: 3, text: "Heading three", anchor: "Heading-three")),
                    .paragraph(.init(inlineContent: [.text("Still in content section")])),
                ]
            ))
        ])
    }

    @Test
    func rendersOnlyInnerContentsWithoutFeatureFlagEnabled() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
            """
            @Card {
                ### Example heading

                Some content.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems == ["1: warning – org.swift.docc.Card.RequiresFeatureFlag"])
        #expect(renderBlockContent == [
            .heading(.init(level: 3, text: "Example heading", anchor: "Example-heading")),
            .paragraph(.init(inlineContent: [.text("Some content.")])),
        ])
    }

    @Test
    func encodesAndDecodesRoundTrip() throws {
        try assertRoundTripCoding(
            RenderBlockContent.card(RenderBlockContent.Card(
                head: [
                    .heading(.init(level: 3, text: "Example heading", anchor: "Example-heading")),
                    .paragraph(.init(inlineContent: [.text("Some head content.")])),
                ],
                content: [
                    .paragraph(.init(inlineContent: [.text("Some body content.")])),
                    .paragraph(.init(inlineContent: [.text("Another body paragraph.")])),
                ]
            ))
        )
    }

    @Test
    func rendersWithResolvedLinkInContent() async throws {
        let catalog = Folder(name: "CardTest.docc", content: [
            TextFile(name: "CardTest.md", utf8Content: """
                # CardTest

                Root page for the test catalog.

                ## Topics

                - <doc:MyArticle>
                """),
            TextFile(name: "MyArticle.md", utf8Content: """
                # My Article

                An article for testing link resolution.
                """),
        ])

        let (renderBlockContent, problems, card, _) = try await parseDirective(
            Card.self,
            catalog: catalog,
            configuration: Self.cardEnabledConfiguration
        ) {
            """
            @Card {
                Read <doc:MyArticle> for more details.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                content: [
                    .paragraph(.init(inlineContent: [
                        .text("Read "),
                        .reference(
                            identifier: RenderReferenceIdentifier("doc://CardTest/documentation/CardTest/MyArticle"),
                            isActive: true,
                            overridingTitle: nil,
                            overridingTitleInlineContent: nil
                        ),
                        .text(" for more details."),
                    ])),
                ]
            ))
        ])
    }

    @Test
    func rendersWithUnresolvedLinkInContent() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(
            Card.self,
            configuration: Self.cardEnabledConfiguration
        ) {
            """
            @Card {
                Read <doc:UnknownArticle> for more details.
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")

        #expect(problems == [
            "2: warning – org.swift.docc.unresolvedTopicReference"
        ])

        // Unresolved doc: links are rendered as plain text.
        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                content: [
                    .paragraph(.init(inlineContent: [
                        .text("Read "),
                        .text("doc:UnknownArticle"),
                        .text(" for more details."),
                    ])),
                ]
            ))
        ])
    }

    @Test
    func rendersWithResolvedSnippetInContent() async throws {
        let catalog = Folder(name: "CardTest.docc", content: [
            JSONFile(name: "snippets.symbols.json", content: makeSymbolGraph(
                moduleName: "Snippets",
                symbols: [
                    makeSymbol(
                        id: "$snippet__snippets.mysnippet",
                        kind: .snippet,
                        pathComponents: ["Snippets", "MySnippet"],
                        otherMixins: [
                            SymbolGraph.Symbol.Snippet(
                                language: "swift",
                                lines: [#"print("Hello, world!")"#],
                                slices: [:]
                            )
                        ]
                    )
                ]
            )),
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName")),
            TextFile(name: "ModuleName.md", utf8Content: """
                # ``ModuleName``

                Module abstract.
                """),
        ])

        let (renderBlockContent, problems, card, _) = try await parseDirective(
            Card.self,
            catalog: catalog,
            configuration: Self.cardEnabledConfiguration
        ) {
            """
            @Card {
                @Snippet(path: "Snippets/MySnippet")
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")
        #expect(problems.isEmpty, "Unexpected problems: \(problems)")

        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                content: [
                    .codeListing(.init(
                        syntax: "swift",
                        code: [#"print("Hello, world!")"#],
                        metadata: nil,
                        options: .init(copyToClipboard: false, showLineNumbers: false, wrap: 0, lineAnnotations: [])
                    )),
                ]
            ))
        ])
    }

    @Test
    func rendersWithUnresolvedSnippetInContent() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(
            Card.self,
            configuration: Self.cardEnabledConfiguration
        ) {
            """
            @Card {
                Some content before the snippet.

                @Snippet(path: "Snippets/Snippets/MySnippet")
            }
            """
        }

        #expect(card != nil, "@Card directive was not parsed as expected")

        #expect(problems == [
            "4: warning – org.swift.docc.unresolvedSnippetPath"
        ])

        // The unresolved snippet is omitted from the rendered content.
        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(
                content: [
                    .paragraph(.init(inlineContent: [.text("Some content before the snippet.")])),
                ]
            ))
        ])
    }
}
