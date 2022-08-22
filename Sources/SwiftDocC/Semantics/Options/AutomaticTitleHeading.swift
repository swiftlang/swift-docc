/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive for specifying Swift-DocC's automatic behavior when generating a page's
/// title heading.
///
/// A title heading is also known as a page eyebrow or kicker.
public class AutomaticTitleHeading: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The specified behavior for automatic title heading generation.
    @DirectiveArgumentWrapped(name: .unnamed)
    public private(set) var behavior: Behavior
    
    /// A behavior for automatic title heading generation.
    public enum Behavior: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// No title heading should be created for the page.
        case disabled
        
        /// A title heading based on the page's kind should be automatically created.
        case pageKind
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "behavior"  : \AutomaticTitleHeading._behavior,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
