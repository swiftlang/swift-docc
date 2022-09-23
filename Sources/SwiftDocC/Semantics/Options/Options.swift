/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive that specifies various options for the page.
public class Options: Semantic, AutomaticDirectiveConvertible {
    public let originalMarkup: BlockDirective
    
    /// Whether the options in this Options directive should apply locally to the page
    /// or globally to the DocC catalog.
    @DirectiveArgumentWrapped
    public private(set) var scope: Scope = .local
    
    @ChildDirective
    public private(set) var _automaticSeeAlso: AutomaticSeeAlso? = nil
    
    @ChildDirective
    public private(set) var _automaticTitleHeading: AutomaticTitleHeading? = nil
    
    @ChildDirective
    public private(set) var _topicsVisualStyle: TopicsVisualStyle? = nil
    
    /// If given, the authored behavior for automatic See Also section generation.
    public var automaticSeeAlsoBehavior: AutomaticSeeAlso.Behavior? {
        return _automaticSeeAlso?.behavior
    }
    
    /// If given, the authored behavior for automatic Title Heading generation.
    public var automaticTitleHeadingBehavior: AutomaticTitleHeading.Behavior? {
        return _automaticTitleHeading?.behavior
    }
    
    /// If given, the authored style for a page's Topics section.
    public var topicsVisualStyle: TopicsVisualStyle.Style? {
        return _topicsVisualStyle?.style
    }
    
    /// A scope for the options provided by an Options directive.
    public enum Scope: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// The directive should only affect the current page.
        case local
        
        /// The directive should affect all pages in the current DocC catalog.
        case global
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "scope"                 : \Options._scope,
        "_automaticSeeAlso"      : \Options.__automaticSeeAlso,
        "_automaticTitleHeading" : \Options.__automaticTitleHeading,
        "_topicsVisualStyle"     : \Options.__topicsVisualStyle,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
