/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A directive for specifying small print text like legal, license, or copyright text that
/// should be rendered in a smaller font size.
///
/// The `@Small` directive is based on HTML's small tag (`<small>`). It supports any inline markup
/// formatting like bold and italics but does not support more structured markup like ``Row``
/// and ``Row/Column``.
///
/// ```md
/// You can create a sloth using the ``init(name:color:power:)``
/// initializer, or create randomly generated sloth using a
/// ``SlothGenerator``:
///    
///    let slothGenerator = MySlothGenerator(seed: randomSeed())
///    let habitat = Habitat(isHumid: false, isWarm: true)
///
///    // ...
///
/// @Small {
///     _Licensed under Apache License v2.0 with Runtime Library Exception._
/// }
/// ```
public final class Small: Semantic, AutomaticDirectiveConvertible, MarkupContaining {
    public let originalMarkup: BlockDirective
    
    /// The inline markup that should be rendered in a small font.
    @ChildMarkup(numberOfParagraphs: .oneOrMore)
    public private(set) var content: MarkupContainer
    
    static var keyPaths: [String : AnyKeyPath] = [
        "content" : \Small._content,
    ]
    
    override var children: [Semantic] {
        return [content]
    }
    
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

extension Small: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent] {
        // Render the content normally
        let renderBlockContent = content.elements.flatMap { markupElement in
            return contentCompiler.visit(markupElement) as! [RenderBlockContent]
        }
        
        // Transform every paragraph in the render block content to a small paragraph
        let transformedRenderBlockContent = renderBlockContent.map { block -> RenderBlockContent in
            guard case let .paragraph(paragraph) = block else {
                return block
            }
            
            return .small(RenderBlockContent.Small(inlineContent: paragraph.inlineContent))
        }
        
        return transformedRenderBlockContent
    }
}
