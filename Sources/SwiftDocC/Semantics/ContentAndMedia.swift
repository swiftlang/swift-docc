/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A piece of media, such as an image or video, with an attached description.
public final class ContentAndMedia: Semantic, DirectiveConvertible {
    public static let directiveName = "ContentAndMedia"
    public static let introducedVersion = "5.5"
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
    public let media: (any Media)?
    
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
    
    init(originalMarkup: BlockDirective, title: String?, layout: Layout?, eyebrow: String?, content: MarkupContainer, media: (any Media)?, mediaPosition: MediaPosition) {
        self.originalMarkup = originalMarkup
        self.title = title
        self.layout = layout
        self.eyebrow = eyebrow
        self.content = content
        self.media = media
        self.mediaPosition = mediaPosition
    }
    
    @available(*, deprecated, renamed: "init(from:source:for:featureFlags:diagnostics:)", message: "Use 'init(from:source:for:featureFlags:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, problems: inout [Problem]) {
        var diagnostics = [Diagnostic]()
        defer {
            problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
        }
        self.init(from: directive, source: source, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, diagnostics: inout [Diagnostic]) {
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<ContentAndMedia>(severityIfFound: .warning, allowedArguments: [Semantics.Title.argumentName, Semantics.Layout.argumentName, Semantics.Eyebrow.argumentName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        Semantic.Analyses.HasOnlyKnownDirectives<ContentAndMedia>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, VideoMedia.directiveName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        let optionalEyebrow = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Eyebrow>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
        let optionalTitle = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Title>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
        
        let layout = Semantic.Analyses.DeprecatedArgument<ContentAndMedia, Semantics.Layout>.unused(severityIfFound: .warning).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
        
        let (media, remainder) = Semantic.Analyses.HasExactlyOneMedia<ContentAndMedia>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: directive.children, source: source, for: bundle, diagnostics: &diagnostics)
        
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
