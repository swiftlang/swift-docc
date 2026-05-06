/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC

class NonOverviewHeadingCheckerTests: XCTestCase {

    func testFindNonOverviewH2() throws {
        let source = """
# Title
Abstract

## Overview
An overview

## Discussion
A discussion

### Discussion subsection
A subsection

## Topics
- ``SymoblLink``
"""
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = NonOverviewHeadingChecker(sourceFile: URL(fileURLWithPath: "/dev/null"))
        checker.visit(document)

        XCTAssertEqual(checker.diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(checker.diagnostics.first)

        XCTAssertEqual(diagnostic.notes.count, 1)
        let note = try XCTUnwrap(diagnostic.notes.first)
        XCTAssertEqual(note.range.lowerBound.line, 4)
        XCTAssertEqual(note.range.lowerBound.column, 1)
        XCTAssertEqual(note.range.upperBound.line, 4)
        XCTAssertEqual(note.range.upperBound.column, 12)

        let range = diagnostic.range
        XCTAssertEqual(range?.lowerBound.line, 7)
        XCTAssertEqual(diagnostic.solutions.count, 1)

        let solution = try XCTUnwrap(diagnostic.solutions.first)
        XCTAssertEqual(solution.replacements.count, 1)

        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "### Discussion")
        XCTAssertEqual(replacement.range.lowerBound.line, 7)
        XCTAssertEqual(replacement.range.lowerBound.column, 1)
        XCTAssertEqual(replacement.range.upperBound.line, 7)
        XCTAssertEqual(replacement.range.upperBound.column, 14)
    }

    func testWithNoOverviewSection() throws {
        let source = """
# Title
Abstract

## Discussion
A discussion

"""
        let document = Document(parsing: source)
        var checker = NonOverviewHeadingChecker(sourceFile: nil)
        checker.visit(document)

        XCTAssertEqual(checker.diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(checker.diagnostics.first)
        XCTAssert(diagnostic.notes.isEmpty)

        let range = diagnostic.range
        XCTAssertEqual(range?.lowerBound.line, 4)
        XCTAssertEqual(diagnostic.solutions.count, 1)

        let solution = try XCTUnwrap(diagnostic.solutions.first)
        XCTAssertEqual(solution.replacements.count, 1)

        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "## Overview")
        XCTAssertEqual(replacement.range.lowerBound.line, 4)
        XCTAssertEqual(replacement.range.lowerBound.column, 1)
        XCTAssertEqual(replacement.range.upperBound.line, 4)
        XCTAssertEqual(replacement.range.upperBound.column, 14)
    }
}
