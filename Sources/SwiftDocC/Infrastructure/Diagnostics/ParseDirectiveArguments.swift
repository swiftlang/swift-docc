/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension BlockDirective {
    /// Attempt to parse directive arguments, emitting parse errors as diagnostics.
    ///
    /// - Parameter diagnostics: A mutable collection of diagnostics to update with any additional issues from parsing the directive arguments.
    func arguments(diagnostics: inout [Diagnostic]) -> [String: Markdown.DirectiveArgument] {
        var parseErrors = [DirectiveArgumentText.ParseError]()
        let parsedArguments = self.argumentText.parseNameValueArguments(parseErrors: &parseErrors)

        diagnostics.append(contentsOf: parseErrors.compactMap { error -> Diagnostic? in
            switch error {
            case let .duplicateArgument(name, firstLocation, duplicateLocation):
                // If we already emitted a diagnostic for the original argument we don't do that a second time.
                // Additionally we search the existing diagnostics in reverse order to find more recent ones faster.
                guard !diagnostics.reversed().contains(where: { diagnostic -> Bool in
                    return diagnostic.identifier == "org.swift.docc.Directive.DuplicateArgument" && diagnostic.range?.lowerBound == firstLocation
                }) else {
                    return nil
                }
                return Diagnostic(
                    source: duplicateLocation.source,
                    severity: .warning,
                    range: duplicateLocation..<duplicateLocation,
                    identifier: "org.swift.docc.Directive.DuplicateArgument",
                    summary: "Duplicate argument for \(name.singleQuoted)"
                )
            case let .missingExpectedCharacter(character, location):
                // Search the existing diagnostics in reverse order to find more recent ones faster.
                guard !diagnostics.reversed().contains(where: { diagnostic -> Bool in
                    return diagnostic.identifier == "org.swift.docc.Directive.MissingExpectedCharacter" && diagnostic.range?.lowerBound == location
                }) else {
                    return nil
                }
                return Diagnostic(
                    source: location.source,
                    severity: .warning,
                    range: location..<location,
                    identifier: "org.swift.docc.Directive.MissingExpectedCharacter",
                    summary: "Missing expected character '\(character)'",
                    explanation: "Arguments that use special characters or spaces should be wrapped in '\"' quotes",
                    possibleSolutions: [
                        Solution(summary: "Insert a '\(character) character", replacements: [
                            Replacement(range: location..<location, replacement: String(character))
                        ])
                    ])
            case let .unexpectedCharacter(character, location):
                // Search the existing diagnostics in reverse order to find more recent ones faster.
                guard !diagnostics.reversed().contains(where: { diagnostic -> Bool in
                    return diagnostic.identifier == "org.swift.docc.Directive.UnexpectedCharacter" && diagnostic.range?.lowerBound == location
                }) else {
                    return nil
                }
                return Diagnostic(
                    source: location.source,
                    severity: .warning,
                    range: location..<location,
                    identifier: "org.swift.docc.Directive.UnexpectedCharacter",
                    summary: "Unexpected character '\(character)'",
                    explanation: "Arguments that use special characters or spaces should be wrapped in '\"' quotes",
                    possibleSolutions: [
                    Solution(summary: "Remove the '\(character) character", replacements: [
                        Replacement(range: location..<SourceLocation(line: location.line, column: location.column+1, source: location.source), replacement: "")
                    ])
                ])
            }
        })

        var arguments = [String: Markdown.DirectiveArgument]()
        for argument in parsedArguments {
            arguments[argument.name] = argument
        }
        return arguments
    }

    /// Attempt to parse directive arguments, discarding parse errors.
    func arguments() -> [String: Markdown.DirectiveArgument] {
        var diagnostics = [Diagnostic]()
        return arguments(diagnostics: &diagnostics)
    }
}
