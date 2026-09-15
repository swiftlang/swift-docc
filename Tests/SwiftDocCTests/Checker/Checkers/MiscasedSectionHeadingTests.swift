/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
@testable import SwiftDocC
import Markdown

struct MiscasedSectionHeadingTests {
    @Test
    func warnsAboutLowercaseSeeAlsoHeading() throws {
        let markupSource = """
        # Title
        Abstract

        ## Overview
        An overview

        ## See also
        - ``RelatedSymbol``
        """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = MiscasedSectionHeading(sourceFile: nil)
        checker.visit(document)

        #expect(checker.diagnostics.count == 1)
        let diagnostic = try #require(checker.diagnostics.first)
        #expect(diagnostic.severity == .warning)
        #expect(diagnostic.identifier == "MiscasedSectionHeading")
        #expect(diagnostic.summary == "Level-2 heading 'See also' does not form a See Also section; did you mean 'See Also'?")

        let solution = try #require(diagnostic.solutions.first)
        #expect(solution.summary == "Replace 'See also' with 'See Also'")
        let replacement = try #require(solution.replacements.first)
        #expect(replacement.replacement == "## See Also")
        #expect(replacement.range.lowerBound.line == 7)
        #expect(replacement.range.lowerBound.column == 1)
        #expect(replacement.range.upperBound.line == 7)
        #expect(replacement.range.upperBound.column == 12)
    }

    @Test(arguments: [
        (actual: "See also",   expected: "See Also",   article: "a"),
        (actual: "SEE ALSO",   expected: "See Also",   article: "a"),
        (actual: "topics",     expected: "Topics",     article: "a"),
        (actual: "TOPICS",     expected: "Topics",     article: "a"),
        (actual: "discussion", expected: "Discussion", article: "a"),
        (actual: "overview",   expected: "Overview",   article: "an"),
        (actual: "OVERVIEW",   expected: "Overview",   article: "an"),
    ])
    func warnsAboutCaseTyposForExpectedSectionHeadings(actual: String, expected: String, article: String) throws {
        let markupSource = """
        # Title
        Abstract

        ## \(actual)
        Content
        """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = MiscasedSectionHeading(sourceFile: nil)
        checker.visit(document)

        #expect(checker.diagnostics.count == 1)
        let diagnostic = try #require(checker.diagnostics.first)
        #expect(diagnostic.severity == .warning)
        #expect(diagnostic.identifier == "MiscasedSectionHeading")
        #expect(diagnostic.summary == "Level-2 heading '\(actual)' does not form \(article) \(expected) section; did you mean '\(expected)'?")

        let solution = try #require(diagnostic.solutions.first)
        #expect(solution.summary == "Replace '\(actual)' with '\(expected)'")
        let replacement = try #require(solution.replacements.first)
        #expect(replacement.replacement == "## \(expected)")
    }

    @Test
    func doesNotWarnForExpectedCasing() {
        let markupSource = """
        # Title
        Abstract

        ## Overview
        An overview

        ## Discussion
        A discussion

        ## Topics
        - ``A``

        ## See Also
        - ``B``
        """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = MiscasedSectionHeading(sourceFile: nil)
        checker.visit(document)

        #expect(checker.diagnostics.isEmpty)
    }

    @Test
    func doesNotWarnAboutNonLevel2Headings() {
        let markupSource = """
        # see also
        Abstract

        ### see also
        Sub-section
        """
        let document = Document(parsing: markupSource, options: [.parseBlockDirectives, .parseSymbolLinks])
        var checker = MiscasedSectionHeading(sourceFile: nil)
        checker.visit(document)

        #expect(checker.diagnostics.isEmpty)
    }
}
