/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that modifies Swift-DocC's default behavior for automatic subheading generation on
/// article pages.
///
/// By default, articles receive a second-level "Overview" heading unless the author explicitly writes
/// some other H2 heading below the abstract. This allows for opting out of that behavior.
public class AutomaticArticleSubheading: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// Whether or not DocC generates automatic second-level "Overview" subheadings.
    @DirectiveArgumentWrapped(
        name: .unnamed,
        trueSpelling: "enabled",
        falseSpelling: "disabled")
    public private(set) var enabled: Bool
    
    static var keyPaths: [String : AnyKeyPath] = [
        "enabled"  : \AutomaticArticleSubheading._enabled,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
