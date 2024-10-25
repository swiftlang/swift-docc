/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A block filled with an image.
public final class ImageMedia: Semantic, Media, AutomaticDirectiveConvertible {
    public static let directiveName = "Image"
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    @DirectiveArgumentWrapped(
        parseArgument: { bundle, argumentValue in
            ResourceReference(bundleID: bundle.id, path: argumentValue)
        }
    )
    public private(set) var source: ResourceReference
    
    /// Optional alternate text for an image.
    @DirectiveArgumentWrapped(name: .custom("alt"))
    public private(set) var altText: String? = nil
    
    
    /// The name of a device frame that should wrap this image.
    ///
    /// This is an experimental feature – any device frame specified here
    /// must be defined in the `theme-settings.json` file of the containing DocC catalog.
    @DirectiveArgumentWrapped(hiddenFromDocumentation: true)
    public private(set) var deviceFrame: String? = nil
    
    /// An optional caption that should be rendered alongside the image.
    @ChildMarkup(numberOfParagraphs: .zeroOrOne)
    public private(set) var caption: MarkupContainer
    
    static var keyPaths: [String : AnyKeyPath] = [
        "altText" : \ImageMedia._altText,
        "source"  : \ImageMedia._source,
        "caption" : \ImageMedia._caption,
        "deviceFrame" : \ImageMedia._deviceFrame,
    ]
    
    func validate(source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> Bool {
        if !FeatureFlags.current.isExperimentalDeviceFrameSupportEnabled && deviceFrame != nil {
            let diagnostic = Diagnostic(
                source: source,
                severity: .warning, range: originalMarkup.range,
                identifier: "org.swift.docc.UnknownArgument",
                summary: "Unknown argument 'deviceFrame' in \(Self.directiveName)."
            )
            
            problems.append(.init(diagnostic: diagnostic))
            
            deviceFrame = nil
        }
        
        return true
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
            caption: renderedCaption,
            deviceFrame: deviceFrame
        ).first as? RenderInlineContent else {
            return []
        }

        return [RenderBlockContent.paragraph(.init(inlineContent: [renderedImage]))]
    }
}
