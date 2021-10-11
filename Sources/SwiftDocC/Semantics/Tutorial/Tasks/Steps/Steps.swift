/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// Wraps a series of ``Step``s in a tutorial task section.
public final class Steps: Semantic, DirectiveConvertible {
    public static let directiveName = "Steps"

    public let originalMarkup: BlockDirective
    
    /// The ``Steps`` necessary to complete this section.
    public let content: [Semantic]
    
    public override var children: [Semantic] {
        return content
    }
    
    /// The child ``Step``s in this section.
    public var steps: [Step] {
        return content.compactMap { $0 as? Step }
    }
    
    init(originalMarkup: BlockDirective, content: [Semantic]) {
        self.originalMarkup = originalMarkup
        self.content = content
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        precondition(directive.name == Steps.directiveName)
        
        _ = Semantic.Analyses.HasOnlyKnownArguments<Steps>(severityIfFound: .warning, allowedArguments: [])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<TutorialSection>(severityIfFound: .warning, allowedDirectives: [Step.directiveName])
            .analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
            
        let stepsContent: [Semantic] = directive.children.compactMap { child -> Semantic? in
            if let directive = child as? BlockDirective,
                directive.name == Step.directiveName {
                return Step(from: directive, source: source, for: bundle, in: context, problems: &problems)
            } else {
                return MarkupContainer(child)
            }
        }
        
        self.init(originalMarkup: directive, content: stepsContent)
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitSteps(self)
    }
}
