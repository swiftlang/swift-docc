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
 One of possibly many choices in a ``MultipleChoice`` question.
 */
public final class Choice: Semantic, DirectiveConvertible {
    public static let directiveName = "Choice"
    public let originalMarkup: BlockDirective
    
    /// `true` if this choice is a correct one; there can be multiple correct choices.
    public let isCorrect: Bool
    
    /// The markup content of the choice, what the user examines to decide to select this choice.
    public let content: MarkupContainer
    
    /// Optional image illustrating the answer.
    public let image: ImageMedia?
    
    /// A justification as to whether this choice is correct.
    public let justification: Justification
    
    override var children: [Semantic] {
        var elements: [Semantic] = [content]
        if let image = image {
            elements.append(image)
        }
        elements.append(justification)
        return elements
    }
    
    init(originalMarkup: BlockDirective, isCorrect: Bool, content: MarkupContainer, image: ImageMedia?, justification: Justification) {
        self.originalMarkup = originalMarkup
        self.isCorrect = isCorrect
        self.content = content
        self.image = image
        self.justification = justification
    }
    
    enum Semantics {
        enum IsCorrect: DirectiveArgument {
            typealias ArgumentValue = Bool
            static let argumentName = "isCorrect"
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Choice.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Choice>(severityIfFound: .warning, allowedArguments: [Semantics.IsCorrect.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Choice>(severityIfFound: .warning, allowedDirectives: [ImageMedia.directiveName, Justification.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        var remainder: MarkupContainer
        let codeBlocks = directive.children.compactMap { $0 as? CodeBlock }
        
        let images: [ImageMedia]
        (images, remainder) = Semantic.Analyses.ExtractAll<ImageMedia>().analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let requiredJustification: Justification?
        (requiredJustification, remainder) = Semantic.Analyses.HasExactlyOne<Choice, Justification>(severityIfNotFound: .warning).analyze(directive, children: remainder, source: source, for: bundle, in: context, problems: &problems)
                
        if remainder.isEmpty && codeBlocks.isEmpty && images.isEmpty {
            let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.\(Choice.self).Empty", summary: "\(Choice.directiveName.singleQuoted) answer content must consist of a paragraph, code block, or \(ImageMedia.directiveName.singleQuoted) directive")
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }

        guard let justification = requiredJustification,
            let isCorrect = Semantic.Analyses.HasArgument<Choice, Semantics.IsCorrect>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems) else {
                return nil
        }
        
        self.init(originalMarkup: directive, isCorrect: isCorrect, content: remainder, image: images.first, justification: justification)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitChoice(self)
    }
}
