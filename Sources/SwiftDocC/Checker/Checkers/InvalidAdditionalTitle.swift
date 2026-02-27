/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A checker that warns about additional first-level headings.
public struct InvalidAdditionalTitle: Checker {
    public var problems = [Problem]()
    
    /// The first level-one heading that the checker encountered, if any.
    private var documentTitle: Heading? = nil
    
    private var sourceFile: URL?
    
    /// Creates a new checker that warns about multiple first-level headings.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks, for diagnostics purposes.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }
    
    public mutating func visitHeading(_ heading: Heading) {
        // Only care about level-one headings.
        guard heading.level == 1 else { return }
        
        guard let documentTitle else {
            documentTitle = heading
            return
        }
        
        // We've found a level-one heading which isn't the title of the document.
        let isExtensionFile = documentTitle.startsWithAnyLink
        
        func makeNote(message: @autoclosure () -> String) -> [DiagnosticNote] {
            guard let range = documentTitle.range, let source = sourceFile ?? range.source else {
                return []
            }
            return [DiagnosticNote(source: source, range: range, message: message())]
        }
        
        let diagnostic = if isExtensionFile {
            Diagnostic(
                source: sourceFile,
                severity: .warning,
                range: heading.range,
                identifier: "MultipleSymbolExtensionAssociations",
                summary: "Documentation extension file can only extend one symbol",
                explanation: "A first-level heading with a symbol link is reserved for defining which symbol a documentation extension file is associated with.",
                notes: makeNote(message: "Previously extending '\(documentTitle.title.trimmingCharacters(in: CharacterSet(charactersIn: "`")))' here")
            )
        } else {
            Diagnostic(
                source: sourceFile,
                severity: .warning,
                range: heading.range,
                identifier: "MultiplePageTitles",
                summary: "Page title can only be specified once",
                explanation: "A first-level heading is reserved for specifying the title of an article.",
                notes: makeNote(message: "Previously specified title '\(documentTitle.title)' here")
            )
        }
        
        var solutions = [
            Solution(summary: "Remove heading", replacements: heading.range.map { range in
                [Replacement(range: range, replacement: "")]
            } ?? [])
        ]
        if !isExtensionFile {
            solutions.append(
                Solution(summary: "Change to second-level heading", replacements: heading.range.map { range in
                    [Replacement(range: range, replacement: "## \(heading.title)")]
                } ?? [])
            )
        }
        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: solutions))
    }
}
