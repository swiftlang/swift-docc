/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that controls what programming languages an article is available in.
///
/// By default, an article is available in the languages the module that's being documented is available in. Use
/// this directive to override this behavior in a ``Metadata`` directive:
///
/// ```
/// @Metadata {
///     @SupportedLanguage(swift)
///     @SupportedLanguage(objc)
/// }
/// ```
///
/// This directive supports any language identifier, but only the following are currently supported
/// by Swift-DocC Render:
///
/// | Identifier                                 | Language               |
/// | --------------------------------- | ----------------------|
/// | `swift`                                | Swift                       |
/// | `objc`, `objective-c`   | Objective-C            |
public final class SupportedLanguage: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// A source language that this symbol is available in.
    ///
    /// For supported values, see ``SupportedLanguage``.
    @DirectiveArgumentWrapped(
        name: .unnamed,
        parseArgument: { _, argumentValue in
            SourceLanguage(knownLanguageIdentifier: argumentValue)
                ?? SourceLanguage(id: argumentValue)
        }
    )
    public var language: SourceLanguage
    
    static var keyPaths: [String : AnyKeyPath] = [
        "language": \SupportedLanguage._language,
    ]
    
    @available(*, deprecated,
        message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
    )
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
