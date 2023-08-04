/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive for customizing the text of a page's title heading.
/// 
/// The ``heading`` property will override the page's default title heading.
///
/// The `@TitleHeading` directive accepts an unnamed parameter containing containing the page's title heading.
///
/// This directive is only valid within a top-level ``Metadata`` directive:
/// ```markdown
/// @Metadata {
///    @TitleHeading("Release Notes")
/// }
/// ```
public final class TitleHeading: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective

    /// An unnamed parameter containing containing the page-title’s heading text.
    @DirectiveArgumentWrapped(name: .unnamed)
    public var heading: String

    static var keyPaths: [String : AnyKeyPath] = [
        "heading" : \TitleHeading._heading,
    ]

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
