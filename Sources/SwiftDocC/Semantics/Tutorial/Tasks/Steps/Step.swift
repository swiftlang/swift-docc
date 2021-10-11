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
 An instructional step to complete as a part of a ``TutorialSection``. ``DirectiveConvertible``
 */
public final class Step: Semantic, DirectiveConvertible {
    public static let directiveName = "Step"
    /// The original `Markup` node that was parsed into this semantic step,
    /// or `nil` if it was created elsewhere.
    public let originalMarkup: BlockDirective
    
    /// A piece of media associated with the step to display when selected.
    public let media: Media?
    
    /// A code file associated with the step to display when selected.
    public let code: Code?
    
    /// `Markup` content inside the step.
    public let content: MarkupContainer
    
    /// The step's caption.
    public let caption: MarkupContainer
    
    override var children: [Semantic] {
        let contentChild: [Semantic] = [content]
        let captionChild: [Semantic] = [caption]
        let codeChild: [Semantic] = code.map { [$0] } ?? []
        return contentChild + captionChild + codeChild
    }
    
    init(originalMarkup: BlockDirective, media: Media?, code: Code?, content: MarkupContainer, caption: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.media = media
        self.code = code
        self.content = content
        self.caption = caption
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Step.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<Step>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Step>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, VideoMedia.directiveName, Code.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        var remainder: MarkupContainer
        let optionalMedia: Media?
        (optionalMedia, remainder) = Semantic.Analyses.HasExactlyOneMedia<Step>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let optionalCode: Code?
        (optionalCode, remainder) = Semantic.Analyses.HasExactlyOne<Step, Code>(severityIfNotFound: nil).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let paragraphs: [Paragraph]
        (paragraphs, remainder) = Semantic.Analyses.ExtractAllMarkup<Paragraph>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        let content: MarkupContainer
        let caption: MarkupContainer
        
        func diagnoseExtraneousContent(element: Markup) -> Problem {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: element.range, identifier: "org.swift.docc.\(Step.self).ExtraneousContent", summary: "Extraneous element: \(Step.directiveName.singleQuoted) directive should only have a single paragraph for its instructional content and an optional paragraph to serve as a caption")
            let solutions = element.range.map {
                return [Solution(summary: "Remove extraneous element", replacements: [Replacement(range: $0, replacement: "")])]
            } ?? []
            return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
        }
        
        // The first paragraph participates in the step's main `content`.
        // The second paragraph becomes the step's caption.
        // Only ``Aside``s may also additionally participate in the step's main `content`.
        
        switch paragraphs.count {
        case 0:
            content = MarkupContainer()
            caption = MarkupContainer()
        case 1:
            content = MarkupContainer(paragraphs[0])
            caption = MarkupContainer()
        case 2:
            content = MarkupContainer(paragraphs[0])
            caption = MarkupContainer(paragraphs[1])
        default:
            content = MarkupContainer(paragraphs[0])
            caption = MarkupContainer(paragraphs[1])
            for extraneousElement in paragraphs.suffix(from: 2) {
                problems.append(diagnoseExtraneousContent(element: extraneousElement))
            }
        }
        
        let blockQuotes: [BlockQuote]
        (blockQuotes, remainder) = Semantic.Analyses.ExtractAllMarkup<BlockQuote>().analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
        
        for extraneousElement in remainder {
            guard (extraneousElement as? BlockDirective)?.name != Comment.directiveName else {
                continue
            }
            problems.append(diagnoseExtraneousContent(element: extraneousElement))
        }
        
        if content.isEmpty {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.HasContent", summary: "\(Step.directiveName.singleQuoted) has no content; \(Step.directiveName.singleQuoted) directive should at least have an instructional sentence")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
        
        self.init(originalMarkup: directive, media: optionalMedia, code: optionalCode, content: MarkupContainer(content.elements), caption: MarkupContainer(caption.elements + blockQuotes as [Markup]))
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStep(self)
    }
}

