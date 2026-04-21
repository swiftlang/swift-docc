/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// A directive that renders its content as a card with an optional head section.
///
/// If a thematic break is present within the `@Card` block,
/// all elements before the thematic break are considered part of the "head"
/// section, with all elements after the break being considered the "content"
/// section.
///
/// If no thematic break is present within the `@Card` block, all elements are
/// considered the "content" section.
///
/// Example with no head section:
/// ```md
/// @Card {
///     ### Example heading
///
///     Example content
/// }
/// ```
///
/// Example with a head section:
/// ```md
/// @Card {
///     ### Example heading
///
///     Example head content
///
///     ---
///
///     Example body content.
///
///     More body content.
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
        // Render all inner content blocks
        let renderedContent = content.elements.flatMap { block in
            (contentCompiler.visit(block) as? [RenderBlockContent]) ?? []
        }

        // Gate the Card directive behind its feature flag.
        // If the flag is not enabled, just render its inner contents.
        guard contentCompiler.context.configuration.featureFlags.isExperimentalCardDirectiveEnabled else {
            return renderedContent
        }

        // If the feature flag _is_ enabled, render a card.
        // 
        // If a thematic break is present, all blocks before it will be
        // presented in the `head` section and all remaining blocks will be
        // presented in the `content` section.
        //
        // If no thematic break is present, all blocks are presented in the
        // `content` section.
        if let thematicBreakIndex = renderedContent.firstIndex(of: .thematicBreak) {
            let rangeBeforeBreak = 0..<thematicBreakIndex
            let rangeAfterBreak = thematicBreakIndex.advanced(by: 1)...
            return [
                RenderBlockContent.card(
                    RenderBlockContent.Card(
                        head: Array(renderedContent[rangeBeforeBreak]),
                        content: Array(renderedContent[rangeAfterBreak])
                    )
                ),
            ]
        } else {
            return [
                RenderBlockContent.card(
                    RenderBlockContent.Card(content: renderedContent)
                ),
            ]
        }
    }
}
