/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A chapter containing ``Tutorial``s to complete.
public final class Chapter: Semantic, DirectiveConvertible, Abstracted, Redirected {
    public static let directiveName = "Chapter"
    
    public let originalMarkup: BlockDirective
    
    /// The name of the chapter.
    public let name: String
    
    /// Content describing the contents of the chapter.
    public let content: MarkupContainer
    
    /// A companion media element next to the chapter's contents.
    public let image: ImageMedia?
    
    /// The list of tutorials and articles categorized under this chapter.
    ///
    /// > Note: Topics may be referenced by multiple chapters.
    public let topicReferences: [TutorialReference]
    
    override var children: [Semantic] {
        return topicReferences
    }
    
    public var abstract: Paragraph? {
        return content.first as? Paragraph
    }
    
    enum Semantics {
        enum Name: DirectiveArgument {
            static let argumentName = "name"
        }
    }
    
    public let redirects: [Redirect]?
    
    init(originalMarkup: BlockDirective, name: String, content: MarkupContainer, image: ImageMedia?, tutorialReferences: [TutorialReference], redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.name = name
        self.content = content
        self.image = image
        self.topicReferences = tutorialReferences
        self.redirects = redirects
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Chapter>(severityIfFound: .warning, allowedArguments: [Semantics.Name.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Chapter>(severityIfFound: .warning, allowedDirectives: [TutorialReference.directiveName, ImageMedia.directiveName, VideoMedia.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredName = Semantic.Analyses.HasArgument<Chapter, Semantics.Name>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        let tutorialReferences: [TutorialReference]
        var remainder: MarkupContainer
        (tutorialReferences, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, TutorialReference>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let image: ImageMedia?
        (image, remainder) = Semantic.Analyses.HasExactlyOne<Chapter, ImageMedia>(severityIfNotFound: .warning).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let redirects: [Redirect]
        (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        guard let name = requiredName else {
            return nil
        }
        self.init(originalMarkup: directive, name: name, content: remainder, image: image, tutorialReferences: tutorialReferences, redirects: redirects.isEmpty ? nil : redirects)
    }
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitChapter(self)
    }
}
