/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// Checks for non-inclusive language in documentation.
///
/// Unlike the other checkers, this type performs global analysis on all types of documentation.
public struct NonInclusiveLanguageChecker: Checker {
    /// The severity for this checker's diagnostics.
    public static let severity: DiagnosticSeverity = .information

    public var problems: [Problem] = []

    /// The list of terms to search for in documentation.
    ///
    /// This type has a built-in list of terms to look for, but a custom array of terms can be passed at
    /// initialization.
    private var terms: [Term]
    /// The URL of the documentation file being analyzed.
    private var sourceFile: URL?

    /// A structure that represents a term to match in content.
    public struct Term: Codable {
        /// The term to search for in the content.
        ///
        /// - Note: This property will be treated as a regular expression, so normal regular expression
        /// syntax is supported.
        public let expression: String
        /// A user-facing message explaining why the term is problematic.
        public let message: String
        /// The suggested replacement for the word.
        public let replacement: String
    }

    public init(sourceFile: URL?, terms: [Term]? = nil) {
        self.sourceFile = sourceFile
        self.terms = terms ?? builtinExcludedTerms
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        // Need to offset the lines by +1 to take into account the start of the code block (``` or ~~~)
        let offset = SourceLocation(line: 1, column: 0, source: nil)
        let offsetRange = offset ..< offset
        
        for term in terms {
            for var range in matchingRanges(for: term, in: codeBlock.code, of: codeBlock) {
                range.offsetWithRange(offsetRange)
                addDiagnosticAboutMatch(term, at: range)
            }
        }
    }

    public mutating func visitInlineCode(_ inlineCode: InlineCode) {
        // Need to offset the columns by +1 to account for the inline code start delimiter (`)
        let offset = SourceLocation(line: 0, column: 1, source: nil)
        let offsetRange = offset ..< offset
        
        for term in terms {
            for var range in matchingRanges(for: term, in: inlineCode.code, of: inlineCode) {
                range.offsetWithRange(offsetRange)
                addDiagnosticAboutMatch(term, at: range)
            }
        }
    }

    public mutating func visitText(_ text: Text) {
        for term in terms {
            for range in matchingRanges(for: term, in: text.string, of: text) {
                addDiagnosticAboutMatch(term, at: range)
            }
        }
    }

    /// Adds a new diagnostic describing where a term was found to `self.problems`.
    /// - Parameters:
    ///   - term: The term that was found.
    ///   - range: The range at which the term was found in the current file.
    private mutating func addDiagnosticAboutMatch(_ term: Term, at range: SourceRange) {
        let diagnostic = Diagnostic(
            source: sourceFile,
            severity: Self.severity,
            range: range,
            identifier: "NonInclusiveLanguage",
            summary: "Documentation should use inclusive language",
            explanation: term.message
        )
        
        let solution = Solution(summary: "Replace with \(term.replacement.singleQuoted)", replacements: [
            Replacement(range: range, replacement: term.replacement)
        ])
        
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
        problems.append(problem)
    }

    /// Checks for a non-inclusive term in the given text and returns the matching ranges.
    ///
    /// The regular expression created from the provided term is evaluated with the case insensitive flag.
    ///
    /// - Parameters:
    ///   - term: The term to look for.
    ///   - text: The text to check for the term in.
    ///   - markup: The markup element that contains the text.
    /// - Returns: An array of ranges at which the term was found.
    /// - Warning: Crashes if the term expression pattern is not valid.
    private func matchingRanges(for term: Term, in text: String, of markup: any Markup) -> [SourceRange] {
        var ranges = [SourceRange]()

        let regex = try! defaultRegularExpressions[term.expression]
            ?? NSRegularExpression(pattern: term.expression, options: [.caseInsensitive])
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        for match in matches {
            if let startCursor = PrintCursor(offset: match.range.location, in: text),
               let endCursor = PrintCursor(offset: NSMaxRange(match.range), in: text),
               let markupRange = markup.range
            {
                let start = SourceLocation(
                    line: markupRange.lowerBound.line + startCursor.line - 1,
                    column: startCursor.column + markupRange.lowerBound.column - 1,
                    source: sourceFile
                )
                let end = SourceLocation(
                    line: markupRange.lowerBound.line + endCursor.line - 1,
                    column: start.column + match.range.length,
                    source: sourceFile
                )
                ranges.append(start ..< end)
            }
        }

        return ranges
    }
}

/// The default list of terms to look for in documentation.
private let builtinExcludedTerms: [NonInclusiveLanguageChecker.Term] = [
    NonInclusiveLanguageChecker.Term(
        expression: #"black\W*list\w{0,2}"#,
        message: "Choose a more inclusive alternative that's appropriate to the context, such as deny list/allow list or unapproved list/approved list.",
        replacement: "deny list"
    ),
    NonInclusiveLanguageChecker.Term(
        expression: #"master\w{0,2}"#,
        message: #"Don't use "master" to describe the relationship between two devices, processes, or other things. Use an alternative that's appropriate to the context, such as "main" and "secondary" or "host" and "client"."#,
        replacement: "primary"
    ),
    NonInclusiveLanguageChecker.Term(
        expression: #"slave\w{0,2}"#,
        message: #"Don't use "slave" to describe the relationship between two devices, processes, or other things. Use an alternative that's appropriate to the context, such as "main" and "secondary" or "host" and "client"."#,
        replacement: "secondary"
    ),
    NonInclusiveLanguageChecker.Term(
        expression: #"white\W*list\w{0,2}"#,
        message: "Choose a more inclusive alternative that's appropriate to the context, such as deny list/allow list or unapproved list/approved list.",
        replacement: "allow list"
    )
]

/// The regular expressions for the default term list.
private let defaultRegularExpressions: [String: NSRegularExpression] = builtinExcludedTerms.reduce(into: [:]) { result, term in
    if let regex = try? NSRegularExpression(pattern: term.expression, options: .caseInsensitive) {
        result[term.expression] = regex
    }
}
