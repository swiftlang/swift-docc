/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A grouping of chapters within a larger collection of tutorials.
public final class Volume: Semantic, DirectiveConvertible, Abstracted, Redirected {
    // DirectiveConvertible
    public static let directiveName = "Volume"
    public let originalMarkup: BlockDirective

    /// The name of this volume.
    public let name: String?
    
    /// An image representing this volume.
    public let image: ImageMedia?
    
    /// The content describing what you'll learn in this volume.
    public let content: MarkupContainer?
    
    /// A list of chapters to complete.
    public let chapters: [Chapter]
    
    override var children: [Semantic] {
        return content.map { [$0] } ?? [] + chapters
    }
    
    var abstract: Paragraph? {
        return content?.first as? Paragraph
    }

    public let redirects: [Redirect]?
    
    /// Creates a new volume from the given parameters.
    ///
    /// - Parameters:
    ///   - originalMarkup: A directive representation of the volume.
    ///   - name: The volume's name.
    ///   - image: An image that represents the volume.
    ///   - content: The volume's content.
    ///   - chapters: A list of chapters to complete.
    ///   - redirects: A list of URLs that redirect to the volume.
    public init(originalMarkup: BlockDirective, name: String?, image: ImageMedia?, content: MarkupContainer?, chapters: [Chapter], redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.name = name
        self.image = image
        self.content = content
        self.chapters = chapters
        self.redirects = redirects
    }
    
    enum Semantics {
        enum Name: DirectiveArgument {
            static let argumentName = "name"
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Volume.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Volume>(severityIfFound: .warning, allowedArguments: [Semantics.Name.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Volume>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, Chapter.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredName = Semantic.Analyses.HasArgument<Volume, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let image: ImageMedia?
        var remainder: MarkupContainer
        (image, remainder) = Semantic.Analyses.HasExactlyOne<Volume, ImageMedia>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let chapters: [Chapter]
        (chapters, remainder) = Semantic.Analyses.HasAtLeastOne<Volume, Chapter>(severityIfNotFound: .warning).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        _ = Semantic.Analyses.HasContent<Volume>(additionalContext: "A \(Volume.directiveName.singleQuoted) directive should at least have a sentence summarizing what the reader will learn").analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let redirects: [Redirect]
        (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        guard let name = requiredName else {
            return nil
        }
        self.init(originalMarkup: directive, name: name, image: image, content: remainder, chapters: chapters, redirects: redirects.isEmpty ? nil : redirects)
    }
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitVolume(self)
    }
}
