/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that allows you to set the color that should be used to
/// represent a documentation page.
///
/// Use the `PageColor` directive to tell Swift-DocC a specific color to use when representing the
/// given documentation page. For example, Swift-DocC-Render will use this color for the background
/// color of a page's introduction section.
///
/// This directive is only valid within a ``Metadata`` directive:
///
/// ```markdown
/// @Metadata {
///     @PageColor(red: 233, green: 58, blue: 43)
/// }
/// ```
public final class PageColor: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// An integer value between `0` and `255` that represents the
    /// amount of red in the color.
    @DirectiveArgumentWrapped
    public var red: Int
    
    /// An integer value between `0` and `255` that represents the
    /// amount of green in the color.
    @DirectiveArgumentWrapped
    public var green: Int
    
    /// An integer value between `0` and `255` that represents the
    /// amount of blue in the color.
    @DirectiveArgumentWrapped
    public var blue: Int
    
    /// A floating-point value between `0.0` and `1.0` that
    /// represents the opacity of the color.
    ///
    /// Defaults to 1.0.
    @DirectiveArgumentWrapped
    public var opacity: Double = 1.0
    
    static var keyPaths: [String : AnyKeyPath] = [
        "red"       : \PageColor._red,
        "green"     : \PageColor._green,
        "blue"      : \PageColor._blue,
        "opacity"   : \PageColor._opacity,
    ]

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
