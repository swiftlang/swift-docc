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
    /// Checks for any directives that are not valid as direct children of the parent directive.
    public struct HasOnlyKnownDirectives<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfFound: DiagnosticSeverity?
        let allowedDirectives: [String]
        let allowsMarkup: Bool
        public init(severityIfFound: DiagnosticSeverity?, allowedDirectives: [String], allowsMarkup: Bool = true) {
            self.severityIfFound = severityIfFound
            self.allowedDirectives = allowedDirectives
                /* Comments are always allowed because they are ignored. */
                + [Comment.directiveName]
            self.allowsMarkup = allowsMarkup
        }
        
        public func analyze<Children>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) where Children: Sequence, Children.Element == Markup {
            if let severity = severityIfFound {
                let allowedDirectivesList = allowedDirectives.sorted().map { "'\($0)'" }.joined(separator: ", ")
                
                for child in children {
                    let summary: String?
                    if let childDirective = child as? BlockDirective {
                        if allowedDirectives.contains(childDirective.name) {
                            summary = nil // This directive is allowed
                        } else {
                            summary = "Block directive \(childDirective.name.singleQuoted) is unknown or invalid as a child of directive \(directive.name.singleQuoted)."
                        }
                    } else if !allowsMarkup {
                        summary = "Arbitrary markup content is not allowed as a child of \(directive.name.singleQuoted)."
                    } else {
                        summary = nil
                    }
                    
                    if let summary = summary {
                        let diagnostic = Diagnostic(source: source, severity: severity, range: child.range, identifier: "org.swift.docc.HasOnlyKnownDirectives", summary: summary, explanation: "These directives are allowed: \(allowedDirectivesList)")
                        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                    }
                }
            }
        }
    }
}

