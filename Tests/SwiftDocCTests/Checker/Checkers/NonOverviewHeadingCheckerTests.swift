/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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

        XCTAssertEqual(checker.problems.count, 1)
        let problem = try XCTUnwrap(checker.problems.first)

        XCTAssertEqual(problem.diagnostic.notes.count, 1)
        let note = try XCTUnwrap(problem.diagnostic.notes.first)
        XCTAssertEqual(note.range.lowerBound.line, 4)
        XCTAssertEqual(note.range.lowerBound.column, 1)
        XCTAssertEqual(note.range.upperBound.line, 4)
        XCTAssertEqual(note.range.upperBound.column, 12)

        let range = problem.diagnostic.range
        XCTAssertEqual(range?.lowerBound.line, 7)
        XCTAssertEqual(problem.possibleSolutions.count, 1)

        let solution = try XCTUnwrap(problem.possibleSolutions.first)
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

        XCTAssertEqual(checker.problems.count, 1)
        let problem = try XCTUnwrap(checker.problems.first)
        XCTAssert(problem.diagnostic.notes.isEmpty)

        let range = problem.diagnostic.range
        XCTAssertEqual(range?.lowerBound.line, 4)
        XCTAssertEqual(problem.possibleSolutions.count, 1)

        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)

        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "## Overview")
        XCTAssertEqual(replacement.range.lowerBound.line, 4)
        XCTAssertEqual(replacement.range.lowerBound.column, 1)
        XCTAssertEqual(replacement.range.upperBound.line, 4)
        XCTAssertEqual(replacement.range.upperBound.column, 14)
    }
}
