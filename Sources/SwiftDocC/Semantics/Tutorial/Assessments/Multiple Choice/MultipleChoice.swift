/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A multiple-choice question.
///
/// A collection of multiple-choice questions that form an ``Assessments``.
public final class MultipleChoice: Semantic, DirectiveConvertible {
    public static let introducedVersion = "5.5"
    public static let directiveName = "MultipleChoice"
    
    /// The phrasing of the question.
    public let questionPhrasing: MarkupContainer
    
    public let originalMarkup: BlockDirective
    
    /// Additional introductory content.
    ///
    /// Typically, this content represents a question's code block.
    public let content: MarkupContainer
    
    /// An optional image associated with the question's introduction.
    public let image: ImageMedia?
    
    /// The possible answers to the question.
    public let choices: [Choice]
    
    override var children: [Semantic] {
        var elements: [Semantic] = [content]
        if let image {
            elements.append(image)
        }
        elements.append(contentsOf: choices)
        return elements
    }
    
    init(originalMarkup: BlockDirective, questionPhrasing: MarkupContainer, content: MarkupContainer, image: ImageMedia?, choices: [Choice]) {
        self.originalMarkup = originalMarkup
        self.questionPhrasing = questionPhrasing
        self.content = content
        self.image = image
        self.choices = choices
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
        precondition(directive.name == MultipleChoice.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<MultipleChoice>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        Semantic.Analyses.HasOnlyKnownDirectives<MultipleChoice>(severityIfFound: .warning, allowedDirectives: [Choice.directiveName, ImageMedia.directiveName]).analyze(directive, children: directive.children, source: source, diagnostics: &diagnostics)
        
        var remainder = MarkupContainer(directive.children)
        let requiredPhrasing: Paragraph?
        if let paragraph = remainder.first as? Paragraph {
            requiredPhrasing = paragraph
            remainder = MarkupContainer(remainder.elements.suffix(from: 1))
        } else {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).missingPhrasing", summary: " \(MultipleChoice.directiveName.singleQuoted) directive is missing its initial paragraph that serves as a question's title phrasing")
            diagnostics.append(diagnostic)
            requiredPhrasing = nil
        }
        
        let choices: [Choice]
        (choices, remainder) = Semantic.Analyses.ExtractAll<Choice>(featureFlags: featureFlags).analyze(directive, children: remainder, source: source, for: bundle, diagnostics: &diagnostics)
        
        if choices.count < 2 || choices.count > 4 {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).CorrectNumberOfChoices", summary: "`\(MultipleChoice.directiveName)` should contain 2-4 `\(Choice.directiveName)` child directives")
            diagnostics.append(diagnostic)
        }
        
        let correctAnswers = choices.filter({ $0.isCorrect })
        
        if correctAnswers.isEmpty {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).CorrectChoiceProvided", summary: "`\(MultipleChoice.directiveName)` should contain `\(Choice.directiveName)` directive marked as the correct option")
            diagnostics.append(diagnostic)
        } else if correctAnswers.count > 1 {
            var diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).MultipleCorrectChoicesProvided", summary: "`\(MultipleChoice.directiveName)` should contain exactly one `\(Choice.directiveName)` directive marked as the correct option")
            for answer in correctAnswers {
                guard let range = answer.originalMarkup.range else {
                    continue
                }
                if let source {
                    let note = DiagnosticNote(source: source, range: range, message: "This `\(Choice.directiveName)` directive is marked as the correct option")
                    diagnostic.notes.append(note)
                }
            }
            diagnostics.append(diagnostic)
        }
        
        let codeBlocks = remainder.compactMap { $0 as? CodeBlock }
        
        func removeExtraneous(_ elementName: String, range: SourceRange) -> Solution {
            return Solution(summary: "Remove extraneous code", replacements: [
                Replacement(range: range, replacement: "")
            ])
        }
        
        if codeBlocks.count > 1 {
            for extraneousCode in codeBlocks.suffix(from: 1) {
                guard let range = extraneousCode.range else {
                    continue
                }
                let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).ExtraneousCode", summary: "`\(MultipleChoice.directiveName)` may contain only one markup code block following the question's phrasing.", possibleSolutions: [removeExtraneous("code block", range: range)])
                diagnostics.append(diagnostic)
            }
        }
        
        let images: [ImageMedia]
        (images, remainder) = Semantic.Analyses.ExtractAll<ImageMedia>(featureFlags: featureFlags).analyze(directive, children: remainder, source: source, for: bundle, diagnostics: &diagnostics)
        
        if images.count > 1 {
            for extraneousImage in images.suffix(from: 1) {
                guard let range = extraneousImage.originalMarkup.range else {
                    continue
                }
                let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).ExtraneousImage", summary: "`\(MultipleChoice.directiveName)` may contain only one '\(ImageMedia.directiveName)' directive following the question's phrasing", possibleSolutions: [removeExtraneous(ImageMedia.directiveName, range: range)])
                diagnostics.append(diagnostic)
            }
        }
        
        if codeBlocks.count == 1 && images.count == 1 {
            let codeBlock = codeBlocks.first!
            let image = images.first!
            let solutions = [
                codeBlock.range.map { range -> Solution in
                    removeExtraneous("code", range: range)
                },
                image.originalMarkup.range.map { range -> Solution in
                    removeExtraneous(ImageMedia.directiveName, range: range)
                },
            ].compactMap { $0 }
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(MultipleChoice.self).CodeOrImage", summary: "`\(MultipleChoice.directiveName)` may contain an `\(ImageMedia.directiveName)` or markup code block following the question's phrasing", possibleSolutions: solutions)
            diagnostics.append(diagnostic)
        }
        
        guard let questionPhrasing = requiredPhrasing else {
            return nil
        }

        self.init(originalMarkup: directive, questionPhrasing: MarkupContainer(questionPhrasing), content: MarkupContainer(remainder), image: images.first, choices: choices)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitMultipleChoice(self)
    }
}
