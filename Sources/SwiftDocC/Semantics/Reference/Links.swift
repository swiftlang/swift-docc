/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive for authoring authoring embedded
/// previews of documentation links (similar to how links are currently
/// rendered in Topics sections) anywhere on the page without affecting page
/// curation behavior.
///
/// `@Links` gives authors flexibility in choosing how they want to highlight
/// documentation on the page itself versus in the navigation sidebar.
/// It also allows for mixing and matching different visual styles of
/// topics.
///
/// ```md
/// ...
///
/// ### What's New in SlothCreator
///
/// @Links(visualStyle: compactGrid) {
///    - <doc:get-started-preparing-sloth-food>
///    - <doc:feeding-your-sloth-in-winter>
///    - <doc:ordering-food-delivery>
/// }
///
/// ...
/// ```
public final class Links: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public let originalMarkup: BlockDirective
    
    /// The inline markup contained in this 'Links' directive.
    ///
    /// This content should not be rendered directly, instead the individual documentation links
    /// inside the first bulleted list should be extracted and previews of the linked
    /// pages should be rendered.
    @ChildMarkup(numberOfParagraphs: .zeroOrMore)    // ← Set to '.zeroOrMore' because the 'validate()'
    public private(set) var content: MarkupContainer //   method below already handles errors for missing
                                                     //   or extraneous content.
    
    /// The specified style that should be used when rendering the specified links.
    @DirectiveArgumentWrapped
    public private(set) var visualStyle: VisualStyle
    
    /// A visual style for the links in a 'Links' directive.
    public enum VisualStyle: String, CaseIterable, DirectiveArgumentValueConvertible {
        /// A list of the linked pages, including their full declaration and abstract.
        case list
        
        /// A grid of items based on the card image for the linked pages.
        ///
        /// Includes each page’s title and card image but excludes their abstracts.
        case compactGrid
        
        /// A grid of items based on the card image for the linked pages.
        ///
        /// Unlike ``compactGrid``, this style includes the abstract for each page.
        case detailedGrid
    }
    
    static var keyPaths: [String : AnyKeyPath] = [
        "content"       : \Links._content,
        "visualStyle"   : \Links._visualStyle,
    ]
    
    override var children: [Semantic] {
        return [content]
    }
    
    var childMarkup: [Markup] {
        return content.elements
    }
    
    func validate(source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Bool {
        _ = Semantic.Analyses.HasExactlyOneUnorderedList<Links, AnyLink>(
            severityIfNotFound: .warning
        ).analyze(
            originalMarkup,
            children: originalMarkup.children,
            source: source,
            for: bundle,
            in: context,
            problems: &problems
        )
        
        return true
    }
    
    @available(*, deprecated,
        message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'."
    )
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
}

extension Links: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent] {
        guard let firstList = originalMarkup.children.first(where: { child in
            child is UnorderedList
        }) else {
            return []
        }
        
        var linksExtractor = ExtractLinks(mode: .linksDirective)
        _ = linksExtractor.visit(firstList)
        
        contentCompiler.context.diagnosticEngine.emit(linksExtractor.problems)
        
        let resolvedLinks = linksExtractor.links
            .compactMap(\.destination)
            .compactMap { contentCompiler.resolveTopicReference($0) }
            .map(\.absoluteString)
        
        guard !resolvedLinks.isEmpty else {
            return []
        }
        
        let style: RenderBlockContent.Links.Style
        switch visualStyle {
        case .compactGrid:
            style = .compactGrid
        case .detailedGrid:
            style = .detailedGrid
        case .list:
            style = .list
        }
        
        let renderedLinks = RenderBlockContent.Links(style: style, items: resolvedLinks)
        return [RenderBlockContent.links(renderedLinks)]
    }
}
