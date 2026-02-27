/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation
public import Markdown

/// A checker that warns about multiple "Topics" sections.
public struct DuplicateTopicsSections: Checker {
    /// The list of second-level headings named "Topics" that the checker encountered while walking the the document.
    public var foundTopicsHeadings = [Heading]()
    private var sourceFile: URL?
    
    /// Creates a new checker that warns about multiple "Topics" sections.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks, for diagnostics purposes.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public var problems: [Problem] {
        guard foundTopicsHeadings.count > 1 else {
            return []
        }
        
        // The notes are the same for all problems, so only create them once.
        let first = foundTopicsHeadings[0]
        let notes: [DiagnosticNote]
        if let sourceFile, let range = first.range {
            notes = [DiagnosticNote(source: sourceFile, range: range, message: "Topics section starts here")]
        } else {
            notes = []
        }
        
        let duplicates = foundTopicsHeadings[1...]
        return duplicates.map { duplicateHeading in
            let range = duplicateHeading.range!
            
            return Problem(
                diagnostic: Diagnostic(
                    source: sourceFile,
                    severity: .warning,
                    range: range,
                    identifier: "MultipleTopicsSections",
                    summary: "Topics section can only appear once per page",
                    explanation: """
                    A second-level heading named 'Topics' is reserved for the section you use to organize your documentation hierarchy. \
                    Each page can only have a single Topics section.
                    """,
                    notes: notes
                ),
                possibleSolutions: [
                    Solution(summary: "Change heading name", replacements: [
                        .init(range: range, replacement: "## <#New heading name#>")
                    ]),
                    Solution(summary: "Move this section's content under the first Topics section", replacements: []/* It would be nice but complicated to offer a replacement for this */)
                ]
            )
        }
    }
    
    public mutating func visitHeading(_ heading: Heading) {
        guard heading.isTopicsSection, heading.parent is Document? else {
            return
        }
        foundTopicsHeadings.append(heading)
    }
}
