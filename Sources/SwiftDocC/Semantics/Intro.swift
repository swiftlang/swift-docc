/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 An introductory section for instructional pages.
 */
public final class Intro: Semantic, DirectiveConvertible {
    public static let directiveName = "Intro"
    
    public let originalMarkup: BlockDirective
    
    /// The title of the containing ``Tutorial``.
    public let title: String
    
    /// An optional video, displayed as a modal.
    public let video: VideoMedia?
    
    /// An optional standout image.
    public let image: ImageMedia?
    
    /// The child markup content.
    public let content: MarkupContainer
    
    override var children: [Semantic] {
        return [content, image, video].compactMap { $0 }
    }
    
    enum Semantics {
        enum Title: DirectiveArgument {
            static let argumentName = "title"
        }
        enum Time: DirectiveArgument {
            typealias ArgumentValue = Int
            static let argumentName = "time"
        }
    }
    
    init(originalMarkup: BlockDirective, title: String, image: ImageMedia?, video: VideoMedia?, content: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.title = title
        self.image = image
        self.video = video
        self.content = content
    }

    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Intro.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .warning, allowedArguments: [Semantics.Title.argumentName, Semantics.Time.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .warning, allowedDirectives: [VideoMedia.directiveName, ImageMedia.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)

        let (optionalVideo, remainder) = Semantic.Analyses.HasExactlyOne<Intro, VideoMedia>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let (optionalImage, remainder2) = Semantic.Analyses.HasExactlyOne<Intro, ImageMedia>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredTitle = Semantic.Analyses.HasArgument<Intro, Semantics.Title>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        guard let title = requiredTitle else {
            return nil
        }
        
        self.init(originalMarkup: directive, title: title, image: optionalImage, video: optionalVideo, content: remainder2)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitIntro(self)
    }
}
