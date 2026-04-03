/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct CardTests {
    @Test
    func noContent() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
            """
            @Card
            """
        }

        #expect(card != nil)
        #expect(problems == ["1: warning – org.swift.docc.Card.HasContent"])
        #expect(renderBlockContent == [
            .card(RenderBlockContent.Card(head: [], content: []))
        ])
    }

    @Test
    func basicCard() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
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

        #expect(card != nil)
        #expect(problems == [])

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
    func cardWithNoHeading() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
            """
            @Card {
                First paragraph.

                Second paragraph.
            }
            """
        }

        #expect(card != nil)
        #expect(problems == [])

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
    func cardWithMultipleHeadings() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
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

        #expect(card != nil)
        #expect(problems == [])

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
    func cardWithMultipleThematicBreaks() async throws {
        let (renderBlockContent, problems, card) = try await parseDirective(Card.self) {
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

        #expect(card != nil)
        #expect(problems == [])

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
    func jsonRoundTrip() throws {
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
}
