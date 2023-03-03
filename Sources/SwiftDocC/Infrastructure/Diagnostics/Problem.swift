/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

/**
 A problem with a document along with possible solutions to the problem.
 */
public struct Problem {
    /// A diagnostic describing the problem.
    public var diagnostic: Diagnostic
    
    /// The possible solutions to the problem if there are any.
    public var possibleSolutions: [Solution]
    public init<Solutions: Sequence>(diagnostic: Diagnostic, possibleSolutions: Solutions) where Solutions.Element == Solution {
        self.diagnostic = diagnostic
        self.possibleSolutions = Array(possibleSolutions)
    }

    public init(diagnostic: Diagnostic) {
        self.init(diagnostic: diagnostic, possibleSolutions: [])
    }
}

extension Problem {
    /// Offsets the problem using a certain SymbolKit `SourceRange`.
    ///
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    mutating func offsetWithRange(_ docRange: SymbolGraph.LineList.SourceRange) {
        diagnostic.offsetWithRange(docRange)
        
        for i in possibleSolutions.indices {
            for j in possibleSolutions[i].replacements.indices {
                possibleSolutions[i].replacements[j].offsetWithRange(docRange)
            }
        }
    }
}

extension Sequence where Element == Problem {
    /// Returns `true` if there are problems with diagnostics with `error` severity.
    public var containsErrors: Bool {
        return self.contains {
            $0.diagnostic.severity == .error
        }
    }
}

// MARK: Deprecated

extension Problem {
    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    var localizedDescription: String {
        return DiagnosticConsoleWriter.formattedDescription(for: self)
    }

    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    func formattedLocalizedDescription(withOptions options: DiagnosticFormattingOptions = []) -> String {
        return DiagnosticConsoleWriter.formattedDescription(for: self, options: options)
    }
}

extension Sequence where Element == Problem {
    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    public var localizedDescription: String {
        return map { $0.localizedDescription }.joined(separator: "\n")
    }

    @available(*, deprecated, message: "Use 'DiagnosticConsoleWriter.formattedDescription(for:options:)' instead.")
    public func formattedLocalizedDescription(withOptions options: DiagnosticFormattingOptions) -> String {
        return map { $0.formattedLocalizedDescription(withOptions: options) }.joined(separator: "\n")
    }
}
