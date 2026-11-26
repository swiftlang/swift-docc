/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import Markdown
@testable import SwiftDocC

struct NonOverviewHeadingCheckerTests {
    @Test(arguments: [
        "Overview", "OVERVIEW", "overview", "OvErViEw",
    ])
    func warnsAboutNonOverviewHeading(after overviewHeadingTitle: String) throws {
        let source = """
# Title
Abstract

## \(overviewHeadingTitle)
An overview

## Discussion
A discussion

### Discussion subsection
A subsection

## Topics
- ``SymbolLink``
"""
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = NonOverviewHeadingChecker(sourceFile: URL(fileURLWithPath: "/dev/null")) // A source file is needed to create diagnostic notes
        checker.visit(document)

        #expect(checker.diagnostics.count == 1)
        let diagnostic = try #require(checker.diagnostics.first)

        #expect(diagnostic.notes.count == 1)
        let note = try #require(diagnostic.notes.first)
        #expect(note.range.lowerBound.line == 4)
        #expect(note.range.lowerBound.column == 1)
        #expect(note.range.upperBound.line == 4)
        #expect(note.range.upperBound.column == 12)

        let range = diagnostic.range
        #expect(range?.lowerBound.line == 7)
        #expect(diagnostic.solutions.count == 1)

        let solution = try #require(diagnostic.solutions.first)
        #expect(solution.replacements.count == 1)

        let replacement = try #require(solution.replacements.first)
        #expect(replacement.replacement == "### Discussion")
        #expect(replacement.range.lowerBound.line == 7)
        #expect(replacement.range.lowerBound.column == 1)
        #expect(replacement.range.upperBound.line == 7)
        #expect(replacement.range.upperBound.column == 14)
    }

    @Test
    func warnsAboutNoOverviewSection() throws {
        let source = """
# Title
Abstract

## Discussion
A discussion

"""
        let document = Document(parsing: source)
        var checker = NonOverviewHeadingChecker(sourceFile: nil)
        checker.visit(document)

        #expect(checker.diagnostics.count == 1)
        let diagnostic = try #require(checker.diagnostics.first)
        #expect(diagnostic.notes.isEmpty)

        let range = diagnostic.range
        #expect(range?.lowerBound.line == 4)
        #expect(diagnostic.solutions.count == 1)

        let solution = try #require(diagnostic.solutions.first)
        #expect(solution.replacements.count == 1)

        let replacement = try #require(solution.replacements.first)
        #expect(replacement.replacement == "## Overview")
        #expect(replacement.range.lowerBound.line == 4)
        #expect(replacement.range.lowerBound.column == 1)
        #expect(replacement.range.upperBound.line == 4)
        #expect(replacement.range.upperBound.column == 14)
    }
}
