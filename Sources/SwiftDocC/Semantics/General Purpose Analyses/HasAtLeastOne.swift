/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

extension Semantic.Analyses {
    /**
     Checks to see if a parent directive has at least one child directive of a specified type. If so, return those that match and those that don't.
     */
    public struct HasAtLeastOne<Parent: Semantic & DirectiveConvertible, Child: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfNotFound: DiagnosticSeverity?
        public init(severityIfNotFound: DiagnosticSeverity?) {
            self.severityIfNotFound = severityIfNotFound
        }
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> ([Child], remainder: MarkupContainer) where Children.Element == Markup {
            
            let (matches, remainder) = children.categorize { child -> BlockDirective? in
                guard let childDirective = child as? BlockDirective,
                    Child.canConvertDirective(childDirective) else {
                        return nil
                }
                return childDirective
            }
            
            if matches.isEmpty,
                let severity = severityIfNotFound {
                let diagnostic = Diagnostic(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.HasAtLeastOne<\(Parent.self), \(Child.self)>", summary: "The \(Parent.directiveName.singleQuoted) directive requires at least one \(Child.directiveName.singleQuoted) child directive")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
            
            let converted = matches.compactMap { childDirective -> Child? in
                return Child(from: childDirective, source: source, for: bundle, in: context, problems: &problems)
            }
            return (converted, remainder: MarkupContainer(remainder))
        }
    }
}

