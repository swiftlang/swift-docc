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
 A short justification as to whether a ``Choice`` is correct for a question.
 */
public final class Justification: Semantic, DirectiveConvertible {
    public static let directiveName = "Justification"
    public let originalMarkup: BlockDirective
    
    /// The explanatory content for this justification.
    public let content: MarkupContainer
    
    /// The reaction to the reader selecting the containing ``Choice``. Defaults to nil.
    public let reaction: String?
    
    override var children: [Semantic] {
        return [content]
    }
    
    init(originalMarkup: BlockDirective, content: MarkupContainer, reaction: String?) {
        self.originalMarkup = originalMarkup
        self.content = content
        self.reaction = reaction
    }
    
    enum Semantics {
        enum Reaction: DirectiveArgument {
            static let argumentName = "reaction"
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Justification.directiveName)
        
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<Justification>(severityIfFound: .warning, allowedArguments: [Semantics.Reaction.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<Justification>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        let reaction = Semantic.Analyses.HasArgument<Justification, Semantics.Reaction>(severityIfNotFound: .none).analyze(directive, arguments: arguments, problems: &problems)
        
        self.init(originalMarkup: directive, content: MarkupContainer(directive.children), reaction: reaction)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitJustification(self)
    }
}
