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
    private let knownOptions = RenderBlockContent.CodeListing.knownOptions

    private var sourceFile: URL?

    /// Creates a new checker that detects documents with multiple titles.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
        let (lang, tokens) = tokenizeLanguageString(codeBlock.language)

        func matches(token: RenderBlockContent.CodeListing.OptionName, value: String?) {
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

        for (token, value) in tokens {
            matches(token: token, value: value)
        }
        // check if first token (lang) might be a typo
        matches(token: .unknown, value: lang)
    }
}
