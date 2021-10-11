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
public final class ImageMedia: Media, DirectiveConvertible {
    public static let directiveName = "Image"
    
    public let originalMarkup: BlockDirective
    
    /// Optional alternate text for an image.
    public let altText: String?
    
    /// Creates a new image with the given parameters.
    ///
    /// - Parameters:
    ///   - originalMarkup: A directive that represents the image.
    ///   - source: A reference to the source file for the image.
    ///   - altText: A description of the appearance and function of the image.
    init(originalMarkup: BlockDirective, source: ResourceReference, altText: String?) {
        self.originalMarkup = originalMarkup
        self.altText = altText
        super.init(source: source)
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = directive.arguments(problems: &problems)
        let optionalAlt = Semantic.Analyses.HasArgument<ImageMedia, Semantics.Alt>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let requiredSource = Semantic.Analyses.HasArgument<ImageMedia, Media.Semantics.Source>(severityIfNotFound: .warning).analyze(directive, arguments:arguments, problems: &problems).map { argument in
            ResourceReference(bundleIdentifier: bundle.identifier, path: argument)
        }
        guard let source = requiredSource else {
            return nil
        }
        self.init(originalMarkup: directive, source: source, altText: optionalAlt)
    }
    
    public override func accept<V>(_ visitor: inout V) -> V.Result where V : SemanticVisitor {
        return visitor.visitImageMedia(self)
    }
}
