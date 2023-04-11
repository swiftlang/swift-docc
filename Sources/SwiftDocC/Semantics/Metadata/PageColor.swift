/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that specifies an accent color for a given documentation page.
///
/// Use the `PageColor` directive to provide a hint to the renderer as to how
/// the page should be accented with color. The renderer may use this color,
/// depending on the context, as a foundation for other colors used on the
/// page. For example, Swift-DocC-Render uses this color as the primary
/// background color of a page's introduction section and adjusts other
/// elements in the introduction section to account for the new background.
///
/// This directive is only valid within a ``Metadata`` directive:
///
/// ```markdown
/// @Metadata {
///     @PageColor(orange)
/// }
/// ```
public final class PageColor: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// A context-dependent, standard color.
    @DirectiveArgumentWrapped(name: .unnamed)
    public var color: Color
    
    /// A context-dependent, standard color.
    public enum Color: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// A context-dependent blue color.
        case blue
        
        /// A context-dependent gray color.
        case gray
        
        /// A context-dependent green color.
        case green
        
        /// A context-dependent orange color.
        case orange
        
        /// A context-dependent purple color.
        case purple
        
        /// A context-dependent red color.
        case red
        
        /// A context-dependent yellow color.
        case yellow
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "color": \PageColor._color,
    ]

    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
