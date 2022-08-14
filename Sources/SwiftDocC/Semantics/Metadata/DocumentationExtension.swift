/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that controls how the documentation-extension file merges with or overrides the in-source documentation.
///
/// When the ``behavior-swift.property`` property is ``Behavior-swift.enum/append``, the content from the documentation-extension file is added after the content from
/// the in-source documentation for that symbol.
/// If a documentation-extension file doesn't have a `DocumentationExtension` directive, then it has the ``Behavior-swift.enum/append`` behavior.
///
/// When the ``behavior-swift.property`` property is ``Behavior-swift.enum/override``, the content from the documentation-extension file completely replaces the content
/// from the in-source documentation for that symbol
///
/// This directive is only valid within a ``Metadata`` directive:
/// ```
/// @Metadata {
///    @DocumentationExtension(mergeBehavior: override)
/// }
/// ```
public final class DocumentationExtension: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    /// The merge behavior for this documentation extension.
    @DirectiveArgumentWrapped(name: .custom("mergeBehavior"))
    public var behavior: Behavior
    
    static var keyPaths: [String : AnyKeyPath] = [
        "behavior" : \DocumentationExtension._behavior,
    ]
    
    /// The merge behavior in a documentation extension.
    public enum Behavior: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// Append the documentation-extension content to the in-source content and process them together.
        case append
        
        /// Completely override any in-source content with the content from the documentation-extension.
        case override
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
