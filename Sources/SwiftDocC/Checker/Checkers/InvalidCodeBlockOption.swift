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
        let info = codeBlock.language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !info.isEmpty else { return }

        let tokens = info
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else { return }

        for token in tokens {
            // if the token is an exact match, we don't need to do anything
            guard !knownOptions.contains(token) else { continue }

            let matches = NearMiss.bestMatches(for: knownOptions, against: token)

            if !matches.isEmpty {
                let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: codeBlock.range, identifier: "org.swift.docc.InvalidCodeBlockOption", summary: "Unknown option \(token.singleQuoted) in code block.")
                let possibleSolutions = matches.map { candidate in
                    Solution(
                        summary: "Replace \(token.singleQuoted) with \(candidate.singleQuoted).",
                        replacements: []
                    )
                }
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: possibleSolutions))
            }
        }
    }
}
