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
An article alongside tutorial content, with the following structure:

```plain
Article (time)
    Intro
    Markup | Stack | ContentAndMedia
```

See ``Stack`` for more information about how to construct layouts. Markup outside of a stack is assumed full width.
 */
public final class TutorialArticle: Semantic, DirectiveConvertible, Abstracted, Titled, Timed, Redirected {
    public static let directiveName = "Article"
    public let originalMarkup: BlockDirective
    
    public let durationMinutes: Int?
    
    /// The introductory section of the tutorial article.
    public let intro: Intro?
    
    /// The body content of the tutorial article.
    public let content: [MarkupLayout]
    
    /// A collection of questions related to the article's content.
    public let assessments: Assessments?
    
    /// An image you use to encourage readers to visit another piece of documentation.
    public let callToActionImage: ImageMedia?
    
    public var abstract: Paragraph? {
        return intro?.content.first as? Paragraph
    }
    
    public var title: String? {
        return intro?.title
    }
    
    /// The linkable parts of the tutorial article.
    ///
    /// Use these elements to create direct links to discrete sections within the tutorial.
    public var landmarks: [Landmark]
    
    override var children: [Semantic] {
        var semanticContent: [Semantic] = []
        
        if let intro = intro {
            semanticContent.append(intro)
        }
        
        let bodyContent: [Semantic] = content.map { element in
            switch element {
                case .markup(let markup): return markup
                case .contentAndMedia(let contentAndMedia): return contentAndMedia
                case .stack(let stack): return stack
            }
        }
        
        semanticContent.append(contentsOf: bodyContent)
        
        if let assessments = assessments {
            semanticContent.append(assessments)
        }
        
        if let image = callToActionImage {
            semanticContent.append(image)
        }
        
        return semanticContent
    }
    
    enum Semantics {
        enum Time: DirectiveArgument {
            typealias ArgumentValue = Int
            static let argumentName = "time"
        }
    }
    
    public let redirects: [Redirect]?
    
    init(originalMarkup: BlockDirective, durationMinutes: Int?, intro: Intro?, content: [MarkupLayout], assessments: Assessments?, callToActionImage: ImageMedia?, landmarks: [Landmark], redirects: [Redirect]?) {
        self.originalMarkup = originalMarkup
        self.durationMinutes = durationMinutes
        self.intro = intro
        self.content = content
        self.assessments = assessments
        self.callToActionImage = callToActionImage
        self.landmarks = landmarks
        self.redirects = redirects
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == TutorialArticle.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<TutorialArticle>(severityIfFound: .warning, allowedArguments: [Semantics.Time.argumentName])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
            
        Semantic.Analyses.HasOnlyKnownDirectives<TutorialArticle>(severityIfFound: .warning, allowedDirectives: [Intro.directiveName, Stack.directiveName, ContentAndMedia.directiveName, Assessments.directiveName, ImageMedia.directiveName, Redirect.directiveName])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalTime = Semantic.Analyses.HasArgument<TutorialArticle, Semantics.Time>(severityIfNotFound: .warning)
            .analyze(directive, arguments: arguments, problems: &problems)
            
        var remainder: MarkupContainer
        let optionalIntro: Intro?
        (optionalIntro, remainder) = Semantic.Analyses.HasExactlyOne<TutorialArticle, Intro>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let headings = Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let content = StackedContentParser.topLevelContent(from: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalAssessments: Assessments?
        (optionalAssessments, remainder) = Semantic.Analyses.HasAtMostOne<Tutorial, Assessments>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalCallToActionImage: ImageMedia?
        (optionalCallToActionImage, remainder) = Semantic.Analyses.HasExactlyOne<Technology, ImageMedia>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let redirects: [Redirect]
            (redirects, remainder) = Semantic.Analyses.HasAtLeastOne<Chapter, Redirect>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        self.init(originalMarkup: directive, durationMinutes: optionalTime, intro: optionalIntro, content: content, assessments: optionalAssessments, callToActionImage: optionalCallToActionImage, landmarks: headings, redirects: redirects.isEmpty ? nil : redirects)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorialArticle(self)
    }
}

/// A collection of markup elements that you arrange with a specified layout.
public enum MarkupLayout {
    /// A general-purpose markup container.
    case markup(MarkupContainer)
    
    /// A piece of media with an attached description.
    case contentAndMedia(ContentAndMedia)
    
    /// A view that arranges its children in a row.
    case stack(Stack)
}

struct StackedContentParser {
    static func topLevelContent<MarkupCollection: Sequence>(from markup: MarkupCollection, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> [MarkupLayout] where MarkupCollection.Element == Markup {
        return markup.reduce(into: []) { (accumulation, nextBlock) in
            if let directive = nextBlock as? BlockDirective {
                if directive.name == Stack.directiveName,
                    let stack = Stack(from: directive, source: source, for: bundle, in: context, problems: &problems) {
                    accumulation.append(.stack(stack))
                } else if directive.name == ContentAndMedia.directiveName,
                    let contentAndMedia = ContentAndMedia(from: directive, source: source, for: bundle, in: context, problems: &problems) {
                    accumulation.append(.contentAndMedia(contentAndMedia))
                }
            } else {
                if case .some(.markup(let lastContainer)) = accumulation.last {
                    accumulation[accumulation.endIndex - 1] = .markup(MarkupContainer(Array(lastContainer) + [nextBlock]))
                } else {
                    accumulation.append(.markup(MarkupContainer(nextBlock)))
                }
            }
        }
    }
}

extension TutorialArticle {
    static func analyze(_ node: TopicGraph.Node, completedContext context: DocumentationContext, engine: DiagnosticEngine) {
        let technologyParent = context.parents(of: node.reference)
            .compactMap({ context.topicGraph.nodeWithReference($0) })
            .first(where: { $0.kind == .technology || $0.kind == .chapter || $0.kind == .volume })
        guard technologyParent != nil else {
            let url = context.documentURL(for: node.reference)
            engine.emit(.init(
                diagnostic: Diagnostic(source: url, severity: .warning, range: nil, identifier: "org.swift.docc.Unreferenced\(TutorialArticle.self)", summary: "The article \(node.reference.path.components(separatedBy: "/").last!.singleQuoted) must be referenced from a Tutorial Table of Contents"),
                possibleSolutions: [
                    Solution(summary: "Use a \(TutorialReference.directiveName.singleQuoted) directive inside \(Technology.directiveName.singleQuoted) to reference the article.", replacements: [])
                ]
            ))
            return
        }
    }
}


