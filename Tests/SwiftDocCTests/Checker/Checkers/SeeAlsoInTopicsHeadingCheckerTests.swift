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

struct SeeAlsoInTopicsHeadingCheckerTests {
    @Test(arguments: [
        "Topics", "TOPICS", "topics", "ToPiCs",
    ], [
        "See Also", "SEE ALSO", "see also", "SeE aLsO",
    ])
    func warnsAboutSeeAlsoInTopics(topicsHeadingSpelling: String, seeAlsoHeadingSpelling: String) throws {
        let source = """
# Title
Abstract

## \(topicsHeadingSpelling)
An overview

### Discussion
A discussion

### \(seeAlsoHeadingSpelling)
- ``RelatedSymbol``
"""
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = SeeAlsoInTopicsHeadingChecker(sourceFile: URL(fileURLWithPath: "/dev/null")) // A source file is needed to create diagnostic notes
        checker.visit(document)

        let diagnostics = checker.diagnostics
        #expect(diagnostics.count == 1)
        let diagnostic = try #require(diagnostics.first)

        let diagnosticRange = try #require(diagnostic.range)
        #expect(diagnosticRange.lowerBound.line == 10)
        #expect(diagnosticRange.lowerBound.column == 1)
        #expect(diagnosticRange.upperBound.line == 10)
        #expect(diagnosticRange.upperBound.column == 13)

        let solutions = diagnostic.solutions
        #expect(solutions.count == 2)
        
        let levelSolution = solutions[0]
        let levelReplacements = levelSolution.replacements
        #expect(levelReplacements.count == 1)
        let levelReplacement = try #require(levelReplacements.first)
        #expect(levelReplacement.replacement == "## See Also")
        let levelReplacementRange = levelReplacement.range
        #expect(levelReplacementRange.lowerBound.line == 10)
        #expect(levelReplacementRange.lowerBound.column == 1)
        #expect(levelReplacementRange.upperBound.line == 10)
        #expect(levelReplacementRange.upperBound.column == 13)
        
        let nameSolution = solutions[1]
        let nameReplacements = nameSolution.replacements
        #expect(nameReplacements.count == 1)
        let nameReplacement = try #require(nameReplacements.first)
        #expect(nameReplacement.replacement == "### <#name#>")
        let nameReplacementRange = nameReplacement.range
        #expect(nameReplacementRange.lowerBound.line == 10)
        #expect(nameReplacementRange.lowerBound.column == 1)
        #expect(nameReplacementRange.upperBound.line == 10)
        #expect(nameReplacementRange.upperBound.column == 13)
    }
}
