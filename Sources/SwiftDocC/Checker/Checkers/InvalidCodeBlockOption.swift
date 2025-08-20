/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/**
 Code blocks can have a `nocopy` option after the \`\`\`, in the language line.
`nocopy` can be immediately after the \`\`\` or after a specified language and a comma (`,`).
 */
public struct InvalidCodeBlockOption: Checker {
    public var problems = [Problem]()

    // FIXME: populate this from the parse options
    /// Parsing options for code blocks
    private let knownOptions = ["nocopy"]

    private var sourceFile: URL?

    /// Creates a new checker that detects documents with multiple titles.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
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
                // FIXME: figure out the position of 'token' and provide solutions
                problems.append(Problem(diagnostic: diagnostic, possibleSolutions: possibleSolutions))
            }
        }
    }
}
