/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Markdown
@testable import SwiftDocC
import DocCTestUtilities

struct NonInclusiveLanguageCheckerTests {
    @Test
    func matchesTermsInTitle() throws {
        let source = """
# A Whitelisted title
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        #expect(checker.problems.count == 1)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 1)
        #expect(range.lowerBound.column == 5)
        #expect(range.upperBound.line == 1)
        #expect(range.upperBound.column == 16)
    }

    @Test
    func matchesTermsWithSpaces() throws {
        let source = """
        # A White  listed title
        # A Black    listed title
        # A White listed title
        """
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        #expect(checker.problems.count == 3)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 1)
        #expect(range.lowerBound.column == 5)
        #expect(range.upperBound.line == 1)
        #expect(range.upperBound.column == 18)

        let problemTwo = try #require(checker.problems.dropFirst(1).first)
        let rangeTwo = try #require(problemTwo.diagnostic.range)
        #expect(rangeTwo.lowerBound.line == 2)
        #expect(rangeTwo.lowerBound.column == 5)
        #expect(rangeTwo.upperBound.line == 2)
        #expect(rangeTwo.upperBound.column == 20)

        let problemThree = try #require(checker.problems.dropFirst(2).first)
        let rangeThree = try #require(problemThree.diagnostic.range)
        #expect(rangeThree.lowerBound.line == 3)
        #expect(rangeThree.lowerBound.column == 5)
        #expect(rangeThree.upperBound.line == 3)
        #expect(rangeThree.upperBound.column == 17)
    }

    @Test
    func matchesTermsInAbstract() throws {
        let source = """
# Title

The blacklist is in the abstract.
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        #expect(checker.problems.count == 1)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 3)
        #expect(range.lowerBound.column == 5)
        #expect(range.upperBound.line == 3)
        #expect(range.upperBound.column == 14)
    }

    @Test
    func matchesTermsInParagraph() throws {
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
        #expect(checker.problems.count == 1)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 8)
        #expect(range.lowerBound.column == 1)
        #expect(range.upperBound.line == 8)
        #expect(range.upperBound.column == 7)
    }

    @Test
    func matchesTermsInList() throws {
        let source = """
- Item 1 is ok
- Item 2 is blacklisted
- Item 3 is ok
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        #expect(checker.problems.count == 1)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 2)
        #expect(range.lowerBound.column == 13)
        #expect(range.upperBound.line == 2)
        #expect(range.upperBound.column == 24)
    }

    @Test
    func matchesTermsInInlineCode() throws {
        let source = """
The name `MachineSlave` is unacceptable.
"""
        let document = Document(parsing: source)
        var checker = NonInclusiveLanguageChecker(sourceFile: nil)
        checker.visit(document)
        #expect(checker.problems.count == 1)

        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 1)
        #expect(range.lowerBound.column == 18)
        #expect(range.upperBound.line == 1)
        #expect(range.upperBound.column == 23)
    }

    @Test
    func matchesTermsInCodeBlock() throws {
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
        #expect(checker.problems.count == 1)
        let problem = try #require(checker.problems.first)
        let range = try #require(problem.diagnostic.range)
        #expect(range.lowerBound.line == 5)
        #expect(range.lowerBound.column == 7)
        #expect(range.upperBound.line == 5)
        #expect(range.upperBound.column == 18)
    }
    
    private let nonInclusiveContent = """
    # Some root page
    
    Some custom root page. And here is a ~~whitelist~~:
    
     - item one
     - item two
     - item three
    """

    @Test
    func isDisabledByDefault() async throws {
        // Create a test bundle with some non-inclusive content.
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: nonInclusiveContent)
        ])
        let context = try await load(catalog: catalog)
        
        #expect(context.problems.isEmpty) // Non-inclusive content is an info-level diagnostic, so it's filtered out.
    }

    @Test(arguments: [
        DiagnosticSeverity.information: true,
        DiagnosticSeverity.warning:     false,
        DiagnosticSeverity.error:       false,
    ])
    func raisesDiagnostics(configuredDiagnosticFilterLevel: DiagnosticSeverity, expectsToIncludeNonInclusiveDiagnostics: Bool) async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: nonInclusiveContent)
        ])
        var configuration = DocumentationContext.Configuration()
        configuration.externalMetadata.diagnosticLevel = configuredDiagnosticFilterLevel
        let context = try await load(catalog: catalog, diagnosticFilterLevel: configuredDiagnosticFilterLevel, configuration: configuration)
        
        // Verify that checker diagnostics were emitted or not, depending on the diagnostic level set.
        #expect(context.problems.contains(where: { $0.diagnostic.identifier == "org.swift.docc.NonInclusiveLanguage" }) == expectsToIncludeNonInclusiveDiagnostics)
    }
}
