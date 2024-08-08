/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

public struct PossibleValuesSection {
    public static var title: String {
        return "Possible Values"
    }
    
    /// The list of possible values.
    public let possibleValues: [PossibleValueTag]
    
    public struct Validator {
        /// The engine that collects problems encountered while validating the possible values documentation.
        var diagnosticEngine: DiagnosticEngine
        
        /// Creates a new problem about documentation for a possible value that's not known to that symbol.
        ///
        /// ## Example
        ///
        /// ```swift
        /// /// - PossibleValues:
        /// ///   - someValue: Some description of this value.
        /// ///   - anotherValue: Some description of a non-defined value.
        /// ///     ^~~~~~~~~~~~
        /// ///     Possible value 'anotherValue' not found in the possible values defined for this symbol.
        /// /// Known values:
        /// /// - someValue
        /// ```
        ///
        /// - Parameters:
        ///   - unknownPossibleValue: The authored documentation for the unknown possible value name.
        ///   - knownPossibleValues: All known possible value names for that symbol.
        /// - Returns: A new problem that suggests that the developer removes the documentation for the unknown possible value.
        func makeExtraPossibleValueProblem(_ unknownPossibleValue: PossibleValueTag, knownPossibleValues: Set<String>) -> Problem {
            let source = unknownPossibleValue.range?.source
            
            let summary = """
            Possible value \(unknownPossibleValue.value) not found in the possible values defined for this symbol.
            \(!knownPossibleValues.isEmpty ? "Known Values:\n" : "")
            \(knownPossibleValues.sorted().map { "- \($0)" }.joined(separator: "\n"))\n
            """
            let identifier = "org.swift.docc.DocumentedPossibleValueNotFound"
            
            let nearMisses = NearMiss.bestMatches(for: knownPossibleValues, against: unknownPossibleValue.value)
            
            if nearMisses.isEmpty {
                // If this possible value doesn't resemble any of this symbols possible values, suggest to remove it.
                return Problem(
                    diagnostic: Diagnostic(source: source, severity: .warning, range: unknownPossibleValue.range, identifier: identifier, summary: summary),
                    possibleSolutions: [
                        Solution(
                            summary: "Remove \(unknownPossibleValue.value.singleQuoted) possible value documentation",
                            replacements: unknownPossibleValue.range.map { [Replacement(range: $0, replacement: "")] } ?? []
                        )
                    ]
                )
            }
            // Otherwise, suggest to replace the documented possible value name with the one of the similarly named possible values.
            return Problem(
                diagnostic: Diagnostic(source: source, severity: .warning, range: unknownPossibleValue.nameRange, identifier: identifier, summary: summary),
                possibleSolutions: nearMisses.map { candidate in
                    Solution(
                        summary: "Replace \(unknownPossibleValue.value.singleQuoted) with \(candidate.singleQuoted)",
                        replacements: unknownPossibleValue.nameRange.map { [Replacement(range: $0, replacement: candidate)] } ?? []
                    )
                }
            )
        }
    }

}

