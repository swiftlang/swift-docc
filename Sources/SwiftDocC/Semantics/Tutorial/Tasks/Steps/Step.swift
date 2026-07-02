/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/**
 An instructional step to complete as a part of a ``TutorialSection``. ``DirectiveConvertible``
 */
public final class Step: Semantic, DirectiveConvertible {
    public static let directiveName = "Step"
    public static let introducedVersion = "5.5"
    public let originalMarkup: BlockDirective
    
    /// A piece of media associated with the step to display when selected.
    public let media: (any Media)?
    
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
    
    init(originalMarkup: BlockDirective, media: (any Media)?, code: Code?, content: MarkupContainer, caption: MarkupContainer) {
        self.originalMarkup = originalMarkup
        self.media = media
        self.code = code
        self.content = content
        self.caption = caption
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
        precondition(directive.name == Step.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<Step>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Step>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, VideoMedia.directiveName, Code.directiveName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        var remainder: MarkupContainer
        let optionalMedia: (any Media)?
        (optionalMedia, remainder) = Semantic.Analyses.HasExactlyOneMedia<Step>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: directive.children, source: source, for: bundle, diagnostics: &diagnostics)
        
        let optionalCode: Code?
        (optionalCode, remainder) = Semantic.Analyses.HasExactlyOne<Step, Code>(severityIfNotFound: nil, featureFlags: featureFlags).analyze(directive, children: remainder, source: source, for: bundle, diagnostics: &diagnostics)
        
        let paragraphs: [Paragraph]
        (paragraphs, remainder) = Semantic.Analyses.ExtractAllMarkup<Paragraph>().analyze(directive, children: remainder, source: source, diagnostics: &diagnostics)
        
        let content: MarkupContainer
        let caption: MarkupContainer
        
        func diagnoseExtraneousContent(element: any Markup) -> Diagnostic {
            let solutions = element.range.map {
                return [Solution(summary: "Remove extraneous element", replacements: [.init(range: $0, replacement: "")])]
            } ?? []
            return Diagnostic(source: source, severity: .warning, range: element.range, identifier: "org.swift.docc.\(Step.self).ExtraneousContent", summary: "Extraneous element: \(Step.directiveName.singleQuoted) directive should only have a single paragraph for its instructional content and an optional paragraph to serve as a caption", solutions: solutions)
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
                diagnostics.append(diagnoseExtraneousContent(element: extraneousElement))
            }
        }
        
        let blockQuotes: [BlockQuote]
        (blockQuotes, remainder) = Semantic.Analyses.ExtractAllMarkup<BlockQuote>().analyze(directive, children: remainder, source: source, diagnostics: &diagnostics)
        
        for extraneousElement in remainder {
            guard (extraneousElement as? BlockDirective)?.name != Comment.directiveName else {
                continue
            }
            diagnostics.append(diagnoseExtraneousContent(element: extraneousElement))
        }
        
        if content.isEmpty {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.HasContent", summary: "\(Step.directiveName.singleQuoted) has no content; \(Step.directiveName.singleQuoted) directive should at least have an instructional sentence")
            diagnostics.append(diagnostic)
        }
        
        self.init(originalMarkup: directive, media: optionalMedia, code: optionalCode, content: MarkupContainer(content.elements), caption: MarkupContainer(caption.elements + blockQuotes as [any Markup]))
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitStep(self)
    }
}

