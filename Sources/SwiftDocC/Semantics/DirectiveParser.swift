/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/// A utility type for parsing directives from markup.
struct DirectiveParser<Directive: AutomaticDirectiveConvertible> {
    
    /// Returns a directive of the given type if found in the given sequence of markup elements and the remaining markup.
    ///
    /// If there are multiple instances of the same directive type, this functions returns the first instance
    /// and diagnoses subsequent instances.
    func parseSingleDirective(
        _ directiveType: Directive.Type,
        from markupElements: inout [any Markup],
        parentType: Semantic.Type,
        source: URL?,
        inputs: DocumentationContext.Inputs,
        problems: inout [Problem]
    ) -> Directive? {
        let (directiveElements, remainder) = markupElements.categorize { markup -> Directive? in
            guard let childDirective = markup as? BlockDirective,
                  childDirective.name == Directive.directiveName
            else {
                return nil
            }
            return Directive(
                from: childDirective,
                source: source,
                for: inputs,
                problems: &problems
            )
        }
        
        let directive = directiveElements.first
        
        for extraDirective in directiveElements.dropFirst() {
            problems.append(
                Problem(
                    diagnostic: Diagnostic(
                        source: source,
                        severity: .warning,
                        range: extraDirective.originalMarkup.range,
                        identifier: "org.swift.docc.HasAtMostOne<\(parentType), \(Directive.self)>.DuplicateChildren",
                        summary: "Duplicate \(Metadata.directiveName.singleQuoted) child directive",
                        explanation: nil,
                        notes: []
                    ),
                    possibleSolutions: []
                )
            )
        }
        
        markupElements = remainder
        
        return directive
    }
}
