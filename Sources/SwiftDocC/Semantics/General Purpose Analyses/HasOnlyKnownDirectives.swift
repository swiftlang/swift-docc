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
    /// Checks for any directives that are not valid as direct children of the parent directive.
    public struct HasOnlyKnownDirectives<Parent: Semantic & DirectiveConvertible> {
        let severityIfFound: DiagnosticSeverity?
        let allowedDirectives: [String]
        let allowsMarkup: Bool
        public init(
            severityIfFound: DiagnosticSeverity?,
            allowedDirectives: [String],
            allowsMarkup: Bool = true,
            allowsStructuredMarkup: Bool = false
        ) {
            self.severityIfFound = severityIfFound
            var allowedDirectives = allowedDirectives
                /* Comments are always allowed because they are ignored. */
                + [Comment.directiveName]
            
            if allowsStructuredMarkup {
                allowedDirectives += DirectiveIndex.shared.renderableDirectives.values.map {
                    return $0.directiveName
                }
            }
            self.allowedDirectives = allowedDirectives
            
            self.allowsMarkup = allowsMarkup
        }
        
        
        @available(*, deprecated, renamed: "analyze(_:children:source:diagnostics:)", message: "Use 'analyze(_:children:source:diagnostics:)' instead. This deprecated API will be removed after 6.5 is released.")
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, problems: inout [Problem]) {
            var diagnostics = [Diagnostic]()
            defer {
                problems.append(contentsOf: diagnostics.map { .init(diagnostic: $0) })
            }
            analyze(directive, children: children, source: source, diagnostics: &diagnostics)
        }
        
        public func analyze(_ directive: BlockDirective, children: some Sequence<any Markup>, source: URL?, diagnostics: inout [Diagnostic]) {
            if let severity = severityIfFound {
                let allowedDirectivesList = allowedDirectives.sorted().map { "'\($0)'" }.joined(separator: ", ")
                
                for child in children {
                    let summary: String?
                    if let childDirective = child as? BlockDirective {
                        if allowedDirectives.contains(childDirective.name) {
                            summary = nil // This directive is allowed
                        } else {
                            summary = "\(childDirective.name.singleQuoted) directive is unsupported as a child of the \(directive.name.singleQuoted) directive"
                        }
                    } else if !allowsMarkup {
                        summary = "Arbitrary markup content is not allowed as a child of \(directive.name.singleQuoted)."
                    } else {
                        summary = nil
                    }
                    
                    if let summary {
                        
                        let solutions: [Solution] = if let childRange = child.range {
                            [Solution(
                                summary: "Remove unsupported child content",
                                replacements: [
                                    Replacement(range: childRange, replacement: "")
                                ]
                            )]
                        } else {
                            []
                        }
                        
                        let diagnostic = Diagnostic(source: source, severity: severity, range: child.range, identifier: "org.swift.docc.HasOnlyKnownDirectives", summary: summary, explanation: "These directives are allowed: \(allowedDirectivesList)", solutions: solutions)
                        diagnostics.append(diagnostic)
                    }
                }
            }
        }
    }
}

