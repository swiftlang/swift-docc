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

class SeeAlsoInTopicsHeadingCheckerTests: XCTestCase {
    
    func testSeeAlsoInTopics() throws {
        let source = """
# Title
Abstract

## Topics
An overview

### Discussion
A discussion

### See Also
- ``RelatedSymbol``
"""
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = SeeAlsoInTopicsHeadingChecker(sourceFile: URL(fileURLWithPath: "/dev/null"))
        checker.visit(document)

        let problems = checker.problems
        XCTAssertEqual(problems.count, 1)
        let problem = try XCTUnwrap(problems.first)

        let diagnosticRange = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(diagnosticRange.lowerBound.line, 10)
        XCTAssertEqual(diagnosticRange.lowerBound.column, 1)
        XCTAssertEqual(diagnosticRange.upperBound.line, 10)
        XCTAssertEqual(diagnosticRange.upperBound.column, 13)

        let solutions = problem.possibleSolutions
        XCTAssertEqual(solutions.count, 2)
        
        let levelSolution = solutions[0]
        let levelReplacements = levelSolution.replacements
        XCTAssertEqual(levelReplacements.count, 1)
        let levelReplacement = try XCTUnwrap(levelReplacements.first)
        XCTAssertEqual(levelReplacement.replacement, "## See Also")
        let levelReplacementRange = levelReplacement.range
        XCTAssertEqual(levelReplacementRange.lowerBound.line, 10)
        XCTAssertEqual(levelReplacementRange.lowerBound.column, 1)
        XCTAssertEqual(levelReplacementRange.upperBound.line, 10)
        XCTAssertEqual(levelReplacementRange.upperBound.column, 13)
        
        let nameSolution = solutions[1]
        let nameReplacements = nameSolution.replacements
        XCTAssertEqual(nameReplacements.count, 1)
        let nameReplacement = try XCTUnwrap(nameReplacements.first)
        XCTAssertEqual(nameReplacement.replacement, "### <#name#>")
        let nameReplacementRange = nameReplacement.range
        XCTAssertEqual(nameReplacementRange.lowerBound.line, 10)
        XCTAssertEqual(nameReplacementRange.lowerBound.column, 1)
        XCTAssertEqual(nameReplacementRange.upperBound.line, 10)
        XCTAssertEqual(nameReplacementRange.upperBound.column, 13)
    }
}
