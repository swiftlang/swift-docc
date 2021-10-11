/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension BlockDirective {
    /// Attempt to parse directive arguments, emitting parse errors as diagnostics.
    ///
    /// - parameter problems: An `inout` array of `Problem` values to accept directive argument parsing errors.
    func arguments(problems: inout [Problem]) -> [String: Markdown.DirectiveArgument] {
        var parseErrors = [DirectiveArgumentText.ParseError]()
        let parsedArguments = self.argumentText.parseNameValueArguments(parseErrors: &parseErrors)

        problems.append(contentsOf: parseErrors.compactMap { error -> Problem? in
            switch error {
            case let .duplicateArgument(name, firstLocation, duplicateLocation):
                // If we already emitted a diagnostic for the original argument we don't do that a second time.
                // Additionally we search the existing problems in reverse order to find more recent ones faster.
                guard !problems.reversed().contains(where: { problem -> Bool in
                    return problem.diagnostic.identifier == "org.swift.docc.Directive.DuplicateArgument" && problem.diagnostic.range?.lowerBound == firstLocation
                }) else {
                    return nil
                }
                return Problem(
                    diagnostic: Diagnostic(
                        source: duplicateLocation.source,
                        severity: .warning,
                        range: duplicateLocation..<duplicateLocation,
                        identifier: "org.swift.docc.Directive.DuplicateArgument",
                        summary: "Duplicate argument for \(name.singleQuoted)"
                    ),
                    possibleSolutions: []
                )
            case let .missingExpectedCharacter(character, location):
                // We search the existing problems in reverse order to find more recent ones faster.
                guard !problems.reversed().contains(where: { problem -> Bool in
                    return problem.diagnostic.identifier == "org.swift.docc.Directive.MissingExpectedCharacter" && problem.diagnostic.range?.lowerBound == location
                }) else {
                    return nil
                }
                return Problem(
                    diagnostic: Diagnostic(
                        source: location.source,
                        severity: .warning,
                        range: location..<location,
                        identifier: "org.swift.docc.Directive.MissingExpectedCharacter",
                        summary: "Missing expected character '\(character)'",
                        explanation: "Arguments that use special characters or spaces should be wrapped in '\"' quotes"
                    ),
                    possibleSolutions: [
                        Solution(summary: "Insert a '\(character) character", replacements: [
                            Replacement(range: location..<location, replacement: String(character))
                        ])
                    ])
            case let .unexpectedCharacter(character, location):
                // We search the existing problems in reverse order to find more recent ones faster.
                guard !problems.reversed().contains(where: { problem -> Bool in
                    return problem.diagnostic.identifier == "org.swift.docc.Directive.UnexpectedCharacter" && problem.diagnostic.range?.lowerBound == location
                }) else {
                    return nil
                }
                return Problem(
                    diagnostic: Diagnostic(
                        source: location.source,
                        severity: .warning,
                        range: location..<location,
                        identifier: "org.swift.docc.Directive.UnexpectedCharacter",
                        summary: "Unexpected character '\(character)'",
                        explanation: "Arguments that use special characters or spaces should be wrapped in '\"' quotes"
                    ), possibleSolutions: [
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
        var problems = [Problem]()
        return arguments(problems: &problems)
    }
}
