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
/// See Also section.
public class AutomaticSeeAlso: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// The specified behavior for automatic See Also section generation.
    @DirectiveArgumentWrapped(name: .unnamed)
    public private(set) var behavior: Behavior
    
    /// A behavior for automatic See Also section generation.
    public enum Behavior: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// A See Also section will not be automatically created.
        case disabled
        
        /// A See Also section will be automatically created based on the page's siblings.
        case siblingPages
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "behavior"  : \AutomaticSeeAlso._behavior,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
