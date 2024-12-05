/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC
import SwiftDocCTestUtilities

class NonInclusiveLanguageCheckerTests: XCTestCase {

    func testMatchTermInTitle() throws {
        let source = """
# A Whitelisted title
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 1)
        XCTAssertEqual(range.lowerBound.column, 5)
        XCTAssertEqual(range.upperBound.line, 1)
        XCTAssertEqual(range.upperBound.column, 16)
    }

    func testMatchTermWithSpaces() throws {
        let source = """
        # A White  listed title
        # A Black    listed title
        # A White listed title
        """
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 3)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 1)
        XCTAssertEqual(range.lowerBound.column, 5)
        XCTAssertEqual(range.upperBound.line, 1)
        XCTAssertEqual(range.upperBound.column, 18)

        let problemTwo = try XCTUnwrap(checker.problems[1])
        let rangeTwo = try XCTUnwrap(problemTwo.diagnostic.range)
        XCTAssertEqual(rangeTwo.lowerBound.line, 2)
        XCTAssertEqual(rangeTwo.lowerBound.column, 5)
        XCTAssertEqual(rangeTwo.upperBound.line, 2)
        XCTAssertEqual(rangeTwo.upperBound.column, 20)

        let problemThree = try XCTUnwrap(checker.problems[2])
        let rangeThree = try XCTUnwrap(problemThree.diagnostic.range)
        XCTAssertEqual(rangeThree.lowerBound.line, 3)
        XCTAssertEqual(rangeThree.lowerBound.column, 5)
        XCTAssertEqual(rangeThree.upperBound.line, 3)
        XCTAssertEqual(rangeThree.upperBound.column, 17)
    }

    func testMatchTermInAbstract() throws {
        let source = """
# Title

The blacklist is in the abstract.
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 3)
        XCTAssertEqual(range.lowerBound.column, 5)
        XCTAssertEqual(range.upperBound.line, 3)
        XCTAssertEqual(range.upperBound.column, 14)
    }

    func testMatchTermInParagraph() throws {
        let source = """
# Title

The abstract.

## Overview

The
master branch is the default.
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 8)
        XCTAssertEqual(range.lowerBound.column, 1)
        XCTAssertEqual(range.upperBound.line, 8)
        XCTAssertEqual(range.upperBound.column, 7)
    }

    func testMatchTermInList() throws {
        let source = """
- Item 1 is ok
- Item 2 is blacklisted
- Item 3 is ok
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 2)
        XCTAssertEqual(range.lowerBound.column, 13)
        XCTAssertEqual(range.upperBound.line, 2)
        XCTAssertEqual(range.upperBound.column, 24)
    }

    func testMatchTermInInlineCode() throws {
        let source = """
The name `MachineSlave` is unacceptable.
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)

        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 1)
        XCTAssertEqual(range.lowerBound.column, 18)
        XCTAssertEqual(range.upperBound.line, 1)
        XCTAssertEqual(range.upperBound.column, 23)
    }

    func testMatchTermInCodeBlock() throws {
        let source = """
A code block:

```swift

func aBlackListedFunc() {
    // ...
}
```
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        XCTAssertEqual(checker.problems.count, 1)
        let problem = try XCTUnwrap(checker.problems.first)
        let range = try XCTUnwrap(problem.diagnostic.range)
        XCTAssertEqual(range.lowerBound.line, 5)
        XCTAssertEqual(range.lowerBound.column, 7)
        XCTAssertEqual(range.upperBound.line, 5)
        XCTAssertEqual(range.upperBound.column, 18)
    }
    
    private let nonInclusiveContent = """
    # Some root page
    
    Some custom root page. And here is a ~~whitelist~~:
    
     - item one
     - item two
     - item three
    """

    func testDisabledByDefault() throws {
        // Create a test bundle with some non-inclusive content.
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: nonInclusiveContent)
        ])
        let (_, context) = try loadBundle(catalog: catalog)
        
        XCTAssertEqual(context.problems.count, 0) // Non-inclusive content is an info-level diagnostic, so it's filtered out.
    }

    func testEnablingTheChecker() throws {
        // The expectations of the checker being run, depending on the diagnostic level
        // set to to the documentation context for the compilation.
        let expectations: [(DiagnosticSeverity, Bool)] = [
            (.hint, true),
            (.information, true),
            (.warning, false),
            (.error, false),
        ]

        for (severity, enabled) in expectations {
            let catalog = Folder(name: "unit-test.docc", content: [
                TextFile(name: "Root.md", utf8Content: nonInclusiveContent)
            ])
            var configuration = DocumentationContext.Configuration()
            configuration.externalMetadata.diagnosticLevel = severity
            let (_, context) = try loadBundle(catalog: catalog, diagnosticEngine: .init(filterLevel: severity), configuration: configuration)
            
            // Verify that checker diagnostics were emitted or not, depending on the diagnostic level set.
            XCTAssertEqual(context.problems.contains(where: { $0.diagnostic.identifier == "org.swift.docc.NonInclusiveLanguage" }), enabled)
        }
    }
}
