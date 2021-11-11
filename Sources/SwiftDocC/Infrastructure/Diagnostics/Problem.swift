/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

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
    var localizedDescription: String {
        return formattedLocalizedDescription(withOptions: [])
    }

    func formattedLocalizedDescription(withOptions options: DiagnosticFormattingOptions = []) -> String {
        let description = diagnostic.localizedDescription

        guard let source = diagnostic.source, options.contains(.showFixits) else {
            return description
        }

        let fixitString = possibleSolutions.reduce("", { string, solution -> String in
            return solution.replacements.reduce(string, {
                $0 + "\n\(source.path):\($1.range.lowerBound.line):\($1.range.lowerBound.column)-\($1.range.upperBound.line):\($1.range.upperBound.column): fixit: \($1.replacement)"
            })
        })

        return description +  fixitString
    }
}

extension Sequence where Element == Problem {
    /// Returns `true` if there are problems with diagnostics with `error` severity.
    public var containsErrors: Bool {
        return self.contains {
            $0.diagnostic.severity == .error
        }
    }
    
    /// The human readable summary description for the problems.
    public var localizedDescription: String {
        return map { $0.localizedDescription }.joined(separator: "\n")
    }

    public func formattedLocalizedDescription(withOptions options: DiagnosticFormattingOptions) -> String {
        return map { $0.formattedLocalizedDescription(withOptions: options) }.joined(separator: "\n")
    }
}
