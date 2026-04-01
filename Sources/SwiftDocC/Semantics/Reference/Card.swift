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
        let allBlocks = content.elements.flatMap { element in
            return contentCompiler.visit(element) as! [RenderBlockContent]
        }

        // Partition: first heading + first paragraph after it = head; rest = content
        var head = [RenderBlockContent]()
        var body = [RenderBlockContent]()
        var foundHeading = false
        var foundFirstParagraphAfterHeading = false

        for block in allBlocks {
            if !foundHeading, case .heading = block {
                head.append(block)
                foundHeading = true
            } else if foundHeading && !foundFirstParagraphAfterHeading, case .paragraph = block {
                head.append(block)
                foundFirstParagraphAfterHeading = true
            } else {
                body.append(block)
            }
        }

        return [RenderBlockContent.card(RenderBlockContent.Card(head: head, content: body))]
    }
}
