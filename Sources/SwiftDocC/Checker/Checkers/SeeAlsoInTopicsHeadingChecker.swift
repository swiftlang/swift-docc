/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

public struct SeeAlsoInTopicsHeadingChecker: Checker {
    public var seeAlsoInTopicsHeadings: [Heading] = []
    public var problems: [Problem] {
        guard !seeAlsoInTopicsHeadings.isEmpty else {
            return []
        }
        return seeAlsoInTopicsHeadings.compactMap { heading -> Problem? in
            guard let headingRange = heading.range else { return nil }
            let diagnostic = Diagnostic(
                source: sourceFile,
                severity: .warning,
                range: headingRange,
                identifier: "org.swift.docc.SeeAlsoInTopicsHeadings",
                summary: #"Level-3 heading "See Also" can't form a See Also section. Did you mean to use a level-2 heading?"#,
                explanation: #"A level-2 heading with the name "See Also" is a reserved heading name you use to begin a section to groups related symbols or links. To resolve this issue, change the heading level to a level-2 heading to form a See Also section or change the name of this heading to form a task group."#
            )
            let solutions = [
                Solution(
                    summary: "Change to level-2 heading",
                    replacements: [Replacement(range: headingRange, replacement: "## \(heading.plainText)")]
                ),
                Solution(
                    summary: "Change heading name",
                    replacements: [Replacement(range: headingRange, replacement: "### <#name#>" )]
                ),
            ]
            return Problem(diagnostic: diagnostic, possibleSolutions: solutions)
        }
    }

    private var sourceFile: URL?

    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitHeading(_ heading: Heading) {
        if heading.level == 3, heading.plainText == "See Also" {
            seeAlsoInTopicsHeadings.append(heading)
            return
        }
    }
}
