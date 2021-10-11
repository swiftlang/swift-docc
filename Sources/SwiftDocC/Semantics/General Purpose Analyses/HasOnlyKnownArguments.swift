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
    public struct HasOnlyKnownArguments<Parent: Semantic & DirectiveConvertible>: SemanticAnalysis {
        let severityIfFound: DiagnosticSeverity?
        let allowedArguments: [String]
        public init(severityIfFound: DiagnosticSeverity?, allowedArguments: [String]) {
            self.severityIfFound = severityIfFound
            self.allowedArguments = allowedArguments
        }
        
        public func analyze<Children>(_ directive: BlockDirective, children: Children, source: URL?, for bundle: DocumentationBundle, in context: DocumentationContext, problems: inout [Problem]) -> [String: Markdown.DirectiveArgument] where Children: Sequence, Children.Element == Markup {
            let arguments = directive.arguments(problems: &problems)
            if let severity = severityIfFound {
                let unknownKeys = Set(arguments.keys).subtracting(allowedArguments)
                let unusedKeys = Set(allowedArguments).subtracting(arguments.keys)
                let unknownKeyIssues: [String] = unknownKeys.lazy.map { unknownKey in
                    var summary = "Unknown argument '\(unknownKey)' in \(Parent.directiveName)."
                    if !unusedKeys.isEmpty {
                        let unusedKeyList = unusedKeys.sorted().map { "'\($0)'"}.joined(separator: ", ")
                        summary += " These arguments are currently unused but allowed: \(unusedKeyList)."
                    }
                    
                    return summary
                }
                let newProblems: [Problem] = unknownKeyIssues.map { summary in
                    let diagnostic = Diagnostic(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.UnknownArgument", summary: summary)
                    return Problem(diagnostic: diagnostic, possibleSolutions: [])
                }
                problems.append(contentsOf: newProblems)
            }
            return arguments
        }
    }
}

