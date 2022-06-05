/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
@testable import SwiftDocC
import XCTest

class TutorialDirectiveMisuseCheckerTests: XCTestCase {
    func testImageDirctive() throws {
        do {
            let source = """
            ![a](a.png)
            @Image(source: test.png)
            ![b](b.jpg)
            """
            let expectedRange: SourceRange = SourceLocation(line: 2, column: 1, source: nil) ..< SourceLocation(line: 2, column: 25, source: nil)
            let expectedReplacementText = "![](test.png)"

            let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
            var checker = TutorialDirectiveMisuseChecker(sourceFile: URL(fileURLWithPath: "/dev/null"))
            checker.visit(document)

            XCTAssertEqual(checker.problems.count, 1)
            let problem = checker.problems[0]

            XCTAssertEqual(problem.diagnostic.range, expectedRange)

            XCTAssertEqual(problem.possibleSolutions.count, 1)
            let solution = problem.possibleSolutions[0]

            XCTAssertEqual(solution.replacements.count, 1)
            let replacement = solution.replacements[0]
            XCTAssertEqual(replacement.range, expectedRange)
            XCTAssertEqual(replacement.replacement, expectedReplacementText)
        }

        do {
            let source = """
            ![a](a.png)
            @Image(source: test.png, alt: hello)
            ![b](b.jpg)
            """
            let expectedRange: SourceRange = SourceLocation(line: 2, column: 1, source: nil) ..< SourceLocation(line: 2, column: 37, source: nil)
            let expectedReplacementText = "![hello](test.png)"
            let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
            print(document.debugDescription(options: .printSourceLocations))
            var checker = TutorialDirectiveMisuseChecker(sourceFile: URL(fileURLWithPath: "/dev/null"))
            checker.visit(document)

            XCTAssertEqual(checker.problems.count, 1)
            let problem = checker.problems[0]

            XCTAssertEqual(problem.diagnostic.range, expectedRange)

            XCTAssertEqual(problem.possibleSolutions.count, 1)
            let solution = problem.possibleSolutions[0]

            XCTAssertEqual(solution.replacements.count, 1)
            let replacement = solution.replacements[0]
            XCTAssertEqual(replacement.range, expectedRange)
            XCTAssertEqual(replacement.replacement, expectedReplacementText)
        }
    }
}
