/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A block filled with an image.
public final class ImageMedia: Semantic, Media, AutomaticDirectiveConvertible {
    public static let directiveName = "Image"
    
    public let originalMarkup: BlockDirective
    
    /// Optional alternate text for an image.
    @DirectiveArgumentWrapped(name: .custom("alt"))
    public private(set) var altText: String? = nil
    
    /// An optional caption that should be rendered alongside the image.
    @ChildMarkup(numberOfParagraphs: .zeroOrOne)
    public private(set) var caption: MarkupContainer
    
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argumentValue)
        }
    )
    public private(set) var source: ResourceReference
    
    static var keyPaths: [String : AnyKeyPath] = [
        "altText" : \ImageMedia._altText,
        "source"  : \ImageMedia._source,
        "caption" : \ImageMedia._caption,
    ]
    
    /// Creates a new image with the given parameters.
    ///
    /// - Parameters:
    ///   - originalMarkup: A directive that represents the image.
    ///   - source: A reference to the source file for the image.
    ///   - altText: A description of the appearance and function of the image.
    init(originalMarkup: BlockDirective, source: ResourceReference, altText: String?) {
        self.originalMarkup = originalMarkup
        self.altText = altText
        super.init()
        self.source = source
    }
    
    @available(*, deprecated, message: "Do not call directly. Required for 'AutomaticDirectiveConvertible'.")
    init(originalMarkup: BlockDirective) {
        self.originalMarkup = originalMarkup
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitImageMedia(self)
    }
}

extension ImageMedia: RenderableDirectiveConvertible {
    func render(with contentCompiler: inout RenderContentCompiler) -> [RenderContent] {
        var renderedCaption: [RenderInlineContent]?
        if let caption = caption.first {
            let blockContent = contentCompiler.visit(caption)
            if case let .paragraph(paragraph) = blockContent.first as? RenderBlockContent {
                renderedCaption = paragraph.inlineContent
            }
        }

        guard let renderedImage = contentCompiler.visitImage(
            source: source.path,
            altText: altText,
            caption: renderedCaption
        ).first as? RenderInlineContent else {
            return []
        }

        return [RenderBlockContent.paragraph(.init(inlineContent: [renderedImage]))]
    }
}
