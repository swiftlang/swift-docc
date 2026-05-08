/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

internal import Foundation
internal import Markdown

/**
 Code blocks can have a `nocopy` option after the \`\`\`, in the language line.
`nocopy` can be immediately after the \`\`\` or after a specified language and a comma (`,`).
 */
internal struct InvalidCodeBlockOption: Checker {
    var problems = [Problem]()

    /// Parsing options for code blocks
    private let knownOptions = RenderBlockContent.CodeBlockOptions.knownOptions

    private var sourceFile: URL?

    /// Creates a new checker that detects documents with multiple titles.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let (lang, tokens) = RenderBlockContent.CodeBlockOptions.tokenizeLanguageString(codeBlock.language)

        func matches(token: RenderBlockContent.CodeBlockOptions.OptionName, value: String?) {
            guard token == .unknown, let value = value else { return }

            let matches = NearMiss.bestMatches(for: knownOptions, against: value)

            if !matches.isEmpty {
                let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: codeBlock.range, identifier: "org.swift.docc.InvalidCodeBlockOption", summary: "Unknown option \(value.singleQuoted) in code block.")
                let possibleSolutions = matches.map { candidate in
                    Solution(
                        summary: "Replace \(value.singleQuoted) with \(candidate.singleQuoted).",
                        replacements: []
                    )
                }
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: possibleSolutions))
            } else if lang == nil {
                let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: codeBlock.range, identifier: "org.swift.docc.InvalidCodeBlockOption", summary: "Unknown option \(value.singleQuoted) in code block.")
                let possibleSolutions =
                Solution(
                    summary: "If \(value.singleQuoted) is the language for this code block, then write \(value.singleQuoted) as the first option.",
                    replacements: []
                )
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: [possibleSolutions]))
            }
        }

        func validateArrayIndices(token: RenderBlockContent.CodeBlockOptions.OptionName, value: String?) {
            guard token == .highlight || token == .strikeout, let value = value else { return }
            // code property ends in a newline. this gives us a bogus extra line.
            let lineCount: Int = codeBlock.code.split(omittingEmptySubsequences: false, whereSeparator: { $0.isNewline }).count - 1

            let indices = RenderBlockContent.CodeBlockOptions.parseCodeBlockOptionsArray(value)

            if !value.isEmpty, indices.isEmpty {
                let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: codeBlock.range, identifier: "org.swift.docc.InvalidCodeBlockOption", summary: "Could not parse \(token.rawValue.singleQuoted) indices from \(value.singleQuoted). Expected an integer (e.g. 3) or an array (e.g. [1, 3, 5])")
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
                return
            }

            let invalid = indices.filter { $0 < 1 || $0 > lineCount }
            guard !invalid.isEmpty else { return }

            let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: codeBlock.range, identifier: "org.swift.docc.InvalidCodeBlockOption", summary: "Invalid \(token.rawValue.singleQuoted) index\(invalid.count == 1 ? "" : "es") in \(value.singleQuoted) for a code block with \(lineCount) line\(lineCount == 1 ? "" : "s"). Valid range is 1...\(lineCount).")
            let solutions: [Solution] = {
                if invalid.contains(where: {$0 == lineCount + 1}) {
                    return [Solution(
                        summary: "If you intended the last line, change '\(lineCount + 1)' to \(lineCount).",
                        replacements: []
                    )]
                }
                return []
            }()
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
        }

        for (token, value) in tokens {
            matches(token: token, value: value)
            validateArrayIndices(token: token, value: value)
        }
        // check if first token (lang) might be a typo
        matches(token: .unknown, value: lang)
    }
}
