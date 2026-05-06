/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

extension Semantic.Analyses {
    public struct HasOnlyKnownArguments<Parent: Semantic & DirectiveConvertible> {
        let severityIfFound: DiagnosticSeverity?
        let allowedArguments: [String]
        public init(severityIfFound: DiagnosticSeverity?, allowedArguments: [String]) {
            self.severityIfFound = severityIfFound
            self.allowedArguments = allowedArguments
        }
        
        @available(*, deprecated, renamed: "analyze(_:children:source:diagnostics:)", message: "Use 'analyze(_:children:source:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, problems: inout [Problem]) -> [String: Markdown.DirectiveArgument] {
            var diagnostics = [Diagnostic]()
            defer {
                problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
            }
            return analyze(directive, children: children, source: source, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, diagnostics: inout [Diagnostic]) -> [String: Markdown.DirectiveArgument] {
            let arguments = directive.arguments(diagnostics: &diagnostics)
            if let severity = severityIfFound {
                let unknownKeys = Set(arguments.keys).subtracting(allowedArguments)
                let unusedKeys = Set(allowedArguments).subtracting(arguments.keys)
                let unknownKeyIssues: [String] = unknownKeys.map { unknownKey in
                    var summary = "Unknown argument '\(unknownKey)' in \(Parent.directiveName)."
                    if !unusedKeys.isEmpty {
                        let unusedKeyList = unusedKeys.sorted().map { "'\($0)'"}.joined(separator: ", ")
                        summary += " These arguments are currently unused but allowed: \(unusedKeyList)."
                    }
                    
                    return summary
                }
                for summary in unknownKeyIssues {
                    diagnostics.append(.init(source: source, severity: severity, range: directive.range, identifier: "org.swift.docc.UnknownArgument", summary: summary))
                }
            }
            return arguments
        }
    }
}

