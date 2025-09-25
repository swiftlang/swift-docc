/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/**
 A section containing steps to complete to finish a ``Tutorial``.
 */
public final class TutorialSection: Semantic, DirectiveConvertible, Abstracted, Landmark, Redirected {
    public static let directiveName = "Section"
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// The title of the section.
    public let title: String
    
    /// The content in the task section.
    public let introduction: [MarkupLayout]
    
    /// The ``Steps`` necessary to complete this section.
    public let stepsContent: Steps?
    
    public override var children: [Semantic] {
        var allChildren: [Semantic] = introduction.map { element in
            switch element {
                case .markup(let markup): return markup
                case .contentAndMedia(let contentAndMedia): return contentAndMedia
                case .stack(let stack): return stack
            }
        }
        
        if let steps = stepsContent {
            allChildren.append(steps)
        }
        
        return allChildren
    }
    
    public var abstract: Paragraph? {
        // Only contentAndMedia as the first element contributes an abstract.
        guard case .some(.contentAndMedia(let contentAndMedia)) = introduction.first else {
            return nil
        }
        
        return contentAndMedia.content.first as? Paragraph
    }
    
    public var range: SourceRange? {
        return originalMarkup.range
    }
    
    public var markup: any Markup {
        return originalMarkup
    }
    
    public let redirects: [Redirect]?
    
    init(originalMarkup: BlockDirective, title: String, introduction: [MarkupLayout], stepsContent: Steps?, redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.title = title
        self.introduction = introduction
        self.stepsContent = stepsContent
        self.redirects = redirects
    }
    
    enum Semantics {
        enum Title: DirectiveArgument {
            static let argumentName = "title"
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for inputs: DocumentationContext.Inputs, problems: inout [Problem]) {
        precondition(directive.name == TutorialSection.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<TutorialSection>(severityIfFound: .warning, allowedArguments: [Semantics.Title.argumentName]).analyze(directive, children: directive.children, source: source, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<TutorialSection>(severityIfFound: .warning, allowedDirectives: [ContentAndMedia.directiveName, Stack.directiveName, Steps.directiveName, Redirect.directiveName]).analyze(directive, children: directive.children, source: source, problems: &problems)
        
        let requiredTitle = Semantic.Analyses.HasArgument<TutorialSection, Semantics.Title>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
        
        var remainder: MarkupContainer
        let optionalSteps: Steps?
        (optionalSteps, remainder) = Semantic.Analyses.HasExactlyOne<TutorialSection, Steps>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: inputs, problems: &problems)
        
        Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(directive, children: remainder, source: source, for: inputs, problems: &problems)
        
        let redirects: [Redirect]
            (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: inputs, problems: &problems)
        
        let content = StackedContentParser.topLevelContent(from: remainder, source: source, for: inputs, problems: &problems)
        
        guard let title = requiredTitle else {
            return nil
        }
        
        self.init(originalMarkup: directive, title: title, introduction: content, stepsContent: optionalSteps, redirects: redirects.isEmpty ? nil : redirects)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorialSection(self)
    }
}
