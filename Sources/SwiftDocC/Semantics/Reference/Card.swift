/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// A directive that renders its content as a card with separate head and content sections.
///
/// The `@Card` directive partitions its child markup into two sections:
/// - **head**: The first heading and the first paragraph following it.
/// - **content**: All remaining block elements.
///
/// ```md
/// @Card {
///     ### Example heading
///
///     Some head content.
///
///     Some body content.
///
///     Another body paragraph.
/// }
/// ```
public final class Card: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public static let introducedVersion = "6.4"
    public let originalMarkup: BlockDirective

    /// The markup content inside this card.
    @ChildMarkup(numberOfParagraphs: .oneOrMore, supportsStructure: true)
    public private(set) var content: MarkupContainer

    static var keyPaths: [String : AnyKeyPath] = [
        "content" : \Card._content,
    ]

    override var children: [Semantic] {
        return [content]
    }

    var childMarkup: [any Markup] {
        return content.elements
    }

    @available(*, deprecated,
        message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
    )
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

extension Card: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [any RenderContent] {
        // partition flat list of markdown blocks into 2 lists:
        // 1. elements before thematic break
        // 2. elements after thematic break (if any)
        let (before, after) = partition(
            elements: content.elements,
            separatedBy: ThematicBreak.self
        )

        // if there was a thematic break, use the elements before it as the
        // head of the card
        // 
        // use the rest of the elements as the content (will be the original,
        // full list if a thematic break is never encountered)
        //
        // if there are multiple thematic breaks, subsequent ones after the
        // initial one will just be included in the content
        let head = after.count > 0 ? before : []
        let content = after.count > 0 ? after : before

        let card = RenderBlockContent.Card(
            head: render(blocks: head, with: &contentCompiler),
            content: render(blocks: content, with: &contentCompiler)
        )
        return [RenderBlockContent.card(card)]
    }

    private func render(
        blocks: [any Markup],
        with contentCompiler: inout RenderContentCompiler
    ) -> [RenderBlockContent] {
        blocks.flatMap { block in
            (contentCompiler.visit(block) as? [RenderBlockContent]) ?? []
        }
    }

    private func partition<Separator: Markup>(
        elements: [any Markup],
        separatedBy separator: Separator.Type
    ) -> (before: [any Markup], after: [any Markup]) {
        var beforeSeparator = true
        return elements.reduce((before: [], after: [])) { partitioned, element in
            if beforeSeparator && type(of: element) == separator.self {
                beforeSeparator = false
                return partitioned
            } else if beforeSeparator {
                return (
                    before: partitioned.before + [element],
                    after: partitioned.after
                )
            } else {
                return (
                    before: partitioned.before,
                    after: partitioned.after + [element]
                )
            }
        }
    }
}
