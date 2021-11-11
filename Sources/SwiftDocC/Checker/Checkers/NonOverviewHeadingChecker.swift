/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public struct NonOverviewHeadingChecker: Checker {
    public var overviewHeading: Heading?
    public var nonOverviewHeadings: [Heading] = []
    public var problems: [Problem] {
        guard !nonOverviewHeadings.isEmpty else {
            return []
        }

        return nonOverviewHeadings.compactMap { heading -> Problem? in
            guard let headingRange = heading.range else { return nil }
            let notes: [DiagnosticNote]
            if let sourceFile = sourceFile, let range = overviewHeading?.range {
                notes = [DiagnosticNote(source: sourceFile, range: range, message: "Overview section starts here")]
            } else {
                notes = []
            }

            let diagnostic = Diagnostic(
                source: sourceFile,
                severity: .information,
                range: heading.range,
                identifier: "org.swift.docc.NonOverviewHeadings",
                summary: #"The majority of content should be under level-3 headers under the "Overview" section"#,
                explanation: nil,
                notes: notes
            )

            let solution: Solution
            if overviewHeading == nil {
                let replacement = Replacement(range: headingRange, replacement: "## Overview")
                solution = Solution(summary: #"Change the title to "Overview""#, replacements: [replacement])
            } else {
                let replacement = Replacement(range: headingRange, replacement: "### \(heading.title)")
                solution = Solution(summary: "Change the heading to a level-3 heading", replacements: [replacement])
            }

            return Problem(diagnostic: diagnostic, possibleSolutions: [solution])
        }
    }

    private var sourceFile: URL?

    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitHeading(_ heading: Heading) {
        // We don't want to flag the Topics H2 and the See Also H2.
        guard heading.level == 2, !heading.isTopicsSection, heading.title != "See Also" else {
            return
        }

        if heading.plainText == "Overview", overviewHeading == nil {
            overviewHeading = heading
            return
        }

        nonOverviewHeadings.append(heading)
    }
}
