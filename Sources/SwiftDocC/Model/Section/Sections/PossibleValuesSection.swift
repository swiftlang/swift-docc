/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

public struct PossibleValuesSection {
    
    static var title: String {
        return "Possible Values"
    }
    
    /// The list of possible values.
    let possibleValues: [PossibleValueTag]
    
    struct Validator {
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
        /// ///     'anotherValue' is not a known possible value for 'SymbolName'.
        /// ```
        ///
        /// - Parameters:
        ///   - unknownPossibleValue: The authored documentation for the unknown possible value name.
        ///   - knownPossibleValues: All known possible value names for that symbol.
        /// - Returns: A new problem that suggests that the developer removes the documentation for the unknown possible value.
        func makeExtraPossibleValueProblem(_ unknownPossibleValue: PossibleValueTag, knownPossibleValues: Set<String>, symbolName: String) -> Problem {
            
            let source = unknownPossibleValue.range?.source
            let summary = """
            \(unknownPossibleValue.value.singleQuoted) is not a known possible value for \(symbolName.singleQuoted).
            """
            let identifier = "org.swift.docc.DocumentedPossibleValueNotFound"
            let solutionSummary = """
            Remove \(unknownPossibleValue.value.singleQuoted) possible value documentation or replace it with a known value.
            """
            let nearMisses = NearMiss.bestMatches(for: knownPossibleValues, against: unknownPossibleValue.value)
            
            if nearMisses.isEmpty {
                // If this possible value doesn't resemble any of this symbols possible values, suggest to remove it.
                return Problem(
                    diagnostic: Diagnostic(source: source, severity: .warning, range: unknownPossibleValue.range, identifier: identifier, summary: summary),
                    possibleSolutions: [
                        Solution(
                            summary: solutionSummary,
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

