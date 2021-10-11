/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A piece of media, such as an image or video, with an attached description.
public final class ContentAndMedia: Semantic, DirectiveConvertible {
    public static let directiveName = "ContentAndMedia"
    
    public let originalMarkup: BlockDirective
    
    /// The title of this slide.
    public let title: String?
    
    /// The ``Layout`` of the slide.
    public let layout: Layout?
    
    /// The visual position of a semantic object's piece of media in relation to its prose content.
    public let mediaPosition: MediaPosition
    
    /// Constants that represent the media's position in relation to prose content.
    public enum MediaPosition: String, Codable {
        /// The media's position is at the leading, or front, edge of the prose content.
        case leading
        
        /// The media's position is at the trailing, or rear, edge of the prose content.
        case trailing
    }
    
    /// An optional eyebrow to display at the top of the slide.
    public let eyebrow: String?
    
    /// The prose content of the slide.
    public let content: MarkupContainer
    
    /// A ``Media`` item to display next to the ``content``.
    public let media: Media?
    
    override var children: [Semantic] {
        return [content] + (media.map { [$0] } ?? [])
    }
    
    enum Semantics {
        enum Title: DirectiveArgument {
            static let argumentName = "title"
        }
        enum Layout: DirectiveArgument {
            typealias ArgumentValue = SwiftDocC.Layout
            static let argumentName = "layout"
            
            static func allowedValues() -> [String]? {
                return SwiftDocC.Layout.allCases.map { $0.rawValue }
            }
        }
        enum Eyebrow: DirectiveArgument {
            static let argumentName = "eyebrow"
        }
    }
    
    init(originalMarkup: BlockDirective, title: String?, layout: Layout?, eyebrow: String?, content: MarkupContainer, media: Media?, mediaPosition: MediaPosition) {
        self.originalMarkup = originalMarkup
        self.title = title
        self.layout = layout
        self.eyebrow = eyebrow
        self.content = content
        self.media = media
        self.mediaPosition = mediaPosition
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<ContentAndMedia>(severityIfFound: .warning, allowedArguments: [Semantics.Title.argumentName, Semantics.Layout.argumentName, Semantics.Eyebrow.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<ContentAndMedia>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, VideoMedia.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalEyebrow = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Eyebrow>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        let optionalTitle = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Title>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let layout = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Layout>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let (media, remainder) = Semantic.Analyses.HasExactlyOneMedia<ContentAndMedia>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let mediaPosition: MediaPosition
        if let firstChildDirective = directive.child(at: 0) as? BlockDirective,
           firstChildDirective.name == ImageMedia.directiveName || firstChildDirective.name == VideoMedia.directiveName {
            mediaPosition = .leading
        } else {
            mediaPosition = .trailing
        }

        self.init(originalMarkup: directive, title: optionalTitle, layout: layout, eyebrow: optionalEyebrow, content: remainder, media: media, mediaPosition: mediaPosition)
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitContentAndMedia(self)
    }
}
