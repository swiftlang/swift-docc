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
    
    // This property exist so that the generated directive documentation makes it
    // clear that "enabled" and "disabled" are then two possible values.
    
    /// Whether or not DocC generates automatic title headings.
    @DirectiveArgumentWrapped(name: .unnamed)
    public private(set) var enabledness: Enabledness
    
    /// A value that represents whether automatic title heading generation is enabled or disabled.
    public enum Enabledness: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// A title heading should be automatically created for the page (the default).
        case enabled
        
        /// No automatic title heading should be created for the page.
        case disabled
    }
    
    /// Whether or not DocC generates automatic title headings.
    public var enabled: Bool {
        return enabledness == .enabled
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "enabledness"  : \AutomaticTitleHeading._enabledness,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
