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
    
    /// Whether or not DocC generates automatic See Also sections. By default it does.
    @DirectiveArgumentWrapped(name: .unnamed)
    public private(set) var enabledness: Enabledness
    
    /// A value that represent whether automatic See Also section generation is enabled or disabled.
    public enum Enabledness: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// A See Also section should be automatically created (the default).
        case enabled
        
        /// No automatic See Also section should be created.
        case disabled
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "enabledness"  : \AutomaticSeeAlso._enabledness,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
