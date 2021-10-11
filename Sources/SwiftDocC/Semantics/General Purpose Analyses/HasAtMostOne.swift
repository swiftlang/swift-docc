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
     Checks to see if a parent directive has at most one child directive of a specified type. If so, return that child and the remainder.
     */
    public struct HasAtMostOne<Parent: Semantic & DirectiveConvertible, Child: Semantic & DirectiveConvertible>: SemanticAnalysis {
        
        public func analyze<Children: Sequence>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> (Child?, remainder: MarkupContainer) where Children.Element == Markup {
            
            let (matches, remainder) = children.categorize { child -> BlockDirective? in
                guard let childDirective = child as? BlockDirective,
                      Child.canConvertDirective(childDirective) else {
                    return nil
                }
                return childDirective
            }
            
            guard let match = matches.first else {
                return (nil, MarkupContainer(remainder))
            }
            
            // Even if a single child is optional, having duplicates is thus far always an error
            // because it would become ambiguous which child to choose as the one.
            for match in matches.suffix(from: 1) {
                let diagnostic = Diagnostic(source: source, severity: .warning, range: match.range, identifier: "org.swift.docc.HasAtMostOne<\(Parent.self), \(Child.self)>.DuplicateChildren", summary: "Duplicate \(Child.directiveName.singleQuoted) child directive", explanation: "The \(Parent.directiveName.singleQuoted) directive must have at most one \(Child.directiveName.singleQuoted) child directive")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
            }
            
            
            return (Child(from: match, source: source, for: bundle, in: context, problems: &problems), MarkupContainer(remainder))
        }
    }
}

