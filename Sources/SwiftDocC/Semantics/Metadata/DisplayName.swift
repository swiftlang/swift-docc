/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/// A directive that controls how the documentation-extension file overrides the symbol's display name.
///
/// The ``name`` property will override the symbol's default display name.
///
/// When the ``style`` property is ``Style/conceptual``, the symbol's name is rendered as "conceptual"---same as article names or tutorial names---where applicable. The default style is ``Style/conceptual``.
///
/// When the ``style`` property is ``Style/symbol``, the symbol's name is rendered as "symbol"---same as article names or tutorial names---where applicable. The default style is ``Style/conceptual``.
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @DisplayName("Custom Symbol Name", style: conceptual)
/// }
/// ```
public final class DisplayName: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.7"
    public let originalMarkup: BlockDirective
    
    /// The custom display name for this symbol.
    @DirectiveArgumentWrapped(name: .unnamed)
    public var name: String
    
    /// The style of the display name for this symbol.
    ///
    /// Defaults to ``Style/conceptual``.
    @DirectiveArgumentWrapped
    public var style: Style = .conceptual
    
    static var keyPaths: [String : AnyKeyPath] = [
        "style" : \DisplayName._style,
        "name"  : \DisplayName._name,
    ]
    
    /// The style of the display name for this symbol.
    public enum Style: String, CaseIterable, DirectiveArgumentValueConvertible {
        case conceptual
        
        /// Completely override any in-source content with the content from the documentation-extension.
        case symbol
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
