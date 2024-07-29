/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that specifies a custom deprecation summary message to an already deprecated symbol.
///
/// Many in-source deprecation annotations—such as the `@available` attribute in Swift—allow you to specify a plain text deprecation message.
/// You can use the `@DeprecationSummary` directive to override that deprecation message with one or more paragraphs of formatted documentation markup.
/// For example,
///
/// ```md
/// @DeprecationSummary {
///     This method is unsafe because it could potentially cause buffer overruns.
///     Use ``getBytes(_:length:)`` or ``getBytes(_:range:)`` instead.
/// }
/// ```
///
/// You can use the `@DeprecationSummary` directive top-level in both articles and documentation extension files.
///
/// > Tip:
/// > If you are writing a custom deprecation summary message for an API or documentation page that isn't already deprecated,
/// > you should also deprecate it—using in-source annotations when possible or ``Available`` directives when in-source annotations aren't available—so that the reader knows the version when you deprecated that API or documentation page.
public final class DeprecationSummary: Semantic, AutomaticDirectiveConvertible {
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective

    /// The contents of the summary.
    @ChildMarkup
    public private(set) var content: MarkupContainer
    
    override var children: [Semantic] {
        return [content]
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "content" : \DeprecationSummary._content
    ]
    
    /// Creates a new deprecation summary from the content of the given directive.
    /// - Parameters:
    ///   - originalMarkup: The source markup as a directive.
    ///   - content: The markup content for the summary.
    init(originalMarkup: BlockDirective, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        super.init()
        self.content = content
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
        super.init()
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitDeprecationSummary(self)
    }
}
