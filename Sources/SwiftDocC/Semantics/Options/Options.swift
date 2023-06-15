/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive to adjust Swift-DocC's default behaviors when rendering a page.
///
/// ## Topics
///
/// ### Adjusting Automatic Behaviors
///
/// - ``AutomaticSeeAlso``
/// - ``AutomaticTitleHeading``
/// - ``AutomaticArticleSubheading``
///
/// ### Adjusting Visual Style
///
/// - ``TopicsVisualStyle``
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
    public private(set) var _automaticArticleSubheading: AutomaticArticleSubheading? = nil
    
    @ChildDirective
    public private(set) var _topicsVisualStyle: TopicsVisualStyle? = nil
    
    /// If given, whether or not automatic See Also section generation is enabled.
    public var automaticSeeAlsoEnabled: Bool? {
        return _automaticSeeAlso?.enabled
    }
    
    /// If given, whether or not automatic Title Heading generation is enabled.
    public var automaticTitleHeadingEnabled: Bool? {
        return _automaticTitleHeading?.enabled
    }
    
    /// If given, whether or not automatic article subheading generation is enabled.
    public var automaticArticleSubheadingEnabled: Bool? {
        return _automaticArticleSubheading?.enabled
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
        "_automaticArticleSubheading"   : \Options.__automaticArticleSubheading,
    ]
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    required init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}
