/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A block filled with a video.
public final class VideoMedia: Media, DirectiveConvertible {
    public static let directiveName = "Video"
    
    public let originalMarkup: BlockDirective
    
    /// An image to be shown when the video isn't playing.
    public let poster: ResourceReference?
    
    init(originalMarkup: BlockDirective, source: ResourceReference, poster: ResourceReference?) {
        self.originalMarkup = originalMarkup
        self.poster = poster
        super.init(source: source)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = directive.arguments(problems: &problems)
        let requiredSource = Semantic.Analyses.HasArgument<VideoMedia, Media.Semantics.Source>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems).map { argument in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argument)
        }
        
        let optionalPoster = Semantic.Analyses.HasArgument<VideoMedia, Media.Semantics.Poster>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems).map { argument in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argument)
        }
        
        guard let source = requiredSource else {
            return nil
        }
        self.init(originalMarkup: directive, source: source, poster: optionalPoster)
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitVideoMedia(self)
    }
}

