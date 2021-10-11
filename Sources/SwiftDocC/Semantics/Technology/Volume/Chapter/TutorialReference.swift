/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A reference to a ``Tutorial`` or ``TutorialArticle`` by `URL`.
public final class TutorialReference: Semantic, DirectiveConvertible {
    public static let directiveName = "TutorialReference"
    
    public var originalMarkup: BlockDirective
    
    /// The tutorial page or tutorial article to which this refers.
    public let topic: TopicReference
    
    init(originalMarkup: BlockDirective, tutorial: TopicReference) {
        self.originalMarkup = originalMarkup
        self.topic = tutorial
    }
    
    enum Semantics {
        enum Tutorial: DirectiveArgument {
            static let argumentName = "tutorial"
            typealias ArgumentValue = URL
        }
    }
    
    public convenience init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) {
        let arguments = Semantic.Analyses.HasOnlyKnownArguments<TutorialReference>(severityIfFound: .warning, allowedArguments: [Semantics.Tutorial.argumentName]).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        Semantic.Analyses.HasOnlyKnownDirectives<TutorialReference>(severityIfFound: .warning, allowedDirectives: []).analyze(directive, children: directive.children, source: source, for: bundle, in: context, problems: &problems)
        
        guard let requiredTutorial = Semantic.Analyses.HasArgument<TutorialReference, Semantics.Tutorial>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems).flatMap({ tutorialURL -> UnresolvedTopicReference? in
            guard let url = ValidatedURL(tutorialURL), !url.components.path.isEmpty else {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: directive.range, identifier: "org.swift.docc.InvalidTutorialURL", summary: "\(tutorialURL.absoluteString.singleQuoted) isn't a valid Tutorial URL")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                return nil
            }
            return UnresolvedTopicReference(topicURL: url)
        }) else {
            return nil
        }
        self.init(originalMarkup: directive, tutorial: .unresolved(requiredTutorial))
    }
    
    public override func accept<V: SemanticVisitor>(_ visitor: inout V) -> V.Result {
        return visitor.visitTutorialReference(self)
    }
}

