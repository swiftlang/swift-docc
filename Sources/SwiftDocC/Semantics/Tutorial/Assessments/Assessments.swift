/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A collection of questions about the concepts the documentation presents.
public final class Assessments: Semantic, DirectiveConvertible {
    public static let directiveName = "Assessments"
    public let originalMarkup: BlockDirective
    
    /// The multiple-choice questions that make up the assessment.
    public let questions: [MultipleChoice]
    
    override var children: [Semantic] {
        return questions
    }
    
    init(originalMarkup: BlockDirective, questions: [MultipleChoice]) {
        self.originalMarkup = originalMarkup
        self.questions = questions
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Assessments.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<Assessments>(severityIfFound: .warning, allowedArguments: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Assessments>(severityIfFound: .warning, allowedDirectives: [MultipleChoice.directiveName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let (questions, _) = Semantic.Analyses.HasAtLeastOne<Assessments, MultipleChoice>(severityIfNotFound: .warning).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        self.init(originalMarkup: directive, questions: questions)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitAssessments(self)
    }
}
