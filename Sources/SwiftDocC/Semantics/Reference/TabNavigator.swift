/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A container directive that arranges content into a tab-based layout.
///
/// Create a new tab navigator by writing a `@TabNavigator` directive that contains child
/// `@Tab` directives.
///
/// ```md
/// @TabNavigator {
///    @Tab("Powers") {
///       ![A diagram with the five sloth power types.](sloth-powers)
///    }
///
///    @Tab("Excerise routines") {
///       ![A sloth relaxing and enjoying a good book.](sloth-exercise)
///    }
///
///    @Tab("Hats") {
///       ![A sloth discovering newfound confidence after donning a fedora.](sloth-hats)
///    }
/// }
/// ```
public final class TabNavigator: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public let originalMarkup: BlockDirective
    
    /// The tabs that make up this tab navigator.
    @ChildDirective(requirements: .oneOrMore)
    public private(set) var tabs: [Tab]
    
    static var keyPaths: [String : AnyKeyPath] = [
        "tabs" : \TabNavigator._tabs,
    ]
    
    var childMarkup: [Markup] {
        return tabs.flatMap(\.childMarkup)
    }
    
    @available(*, deprecated,
        message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
    )
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

extension TabNavigator {
    /// A container directive that holds general markup content describing an individual
    /// tab within a tab-based layout.
    public final class Tab: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
        public let originalMarkup: BlockDirective
        
        /// The title that should identify the content in this tab when rendered.
        @DirectiveArgumentWrapped(name: .unnamed)
        public private(set) var title: String
        
        /// The markup content in this tab.
        @ChildMarkup(numberOfParagraphs: .oneOrMore, supportsStructure: true)
        public private(set) var content: MarkupContainer
        
        static var keyPaths: [String : AnyKeyPath] = [
            "title"      : \Tab._title,
            "content"   : \Tab._content,
        ]
        
        var childMarkup: [Markup] {
            return content.elements
        }
        
        @available(*, deprecated,
            message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
        )
        init(originalMarkup: BlockDirective) {
            self.originalMarkup = originalMarkup
        }
    }
}

extension TabNavigator: RenderableDirectiveConvertible {
     func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent] {
         let renderedTabs = tabs.map { tab in
             return RenderBlockContent.TabNavigator.Tab(
                title: tab.title,
                content: tab.content.elements.flatMap { markupElement in
                    return contentCompiler.visit(markupElement) as! [RenderBlockContent]
                }
             )
         }

         let renderedNavigator = RenderBlockContent.TabNavigator(tabs: renderedTabs)
         return [RenderBlockContent.tabNavigator(renderedNavigator)]
     }
 }
