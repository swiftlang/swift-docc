/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
@testable import SwiftDocC
import Markdown

struct DuplicateTopicsSectionsTests {
    // This file is never read, it's only used as the source of diagnostics and notes
    private let sourceFileForDiagnosticMessages = URL(fileURLWithPath: "/path/to/some-fake-file.md")
    
    @Test
    func doesNotWarnForEmptyDocument() {
        var checker = DuplicateTopicsSections(sourceFile: sourceFileForDiagnosticMessages)
        checker.visit(Document())
        #expect(checker.problems.isEmpty)
    }
    
    @Test
    func doesNotWarnForSingleTopicsSection() {
        let markupSource = """
        # Title

        Blah

        ## Topics
        """
        let document = Document(parsing: markupSource, options: [])
        var checker = DuplicateTopicsSections(sourceFile: sourceFileForDiagnosticMessages)
        checker.visit(document)
        #expect(checker.problems.isEmpty)
    }
    
    @Test
    func warnsAboutMultipleTopicsSection() throws {
        let markupSource = """
        # Title

        ## Topics
        ### Topic A

        ## Topics
        ### Topic B
        
        ## Topics
        ### Topic C
        """
        let document = Document(parsing: markupSource, options: [])
        var checker = DuplicateTopicsSections(sourceFile: sourceFileForDiagnosticMessages)
        checker.visit(document)
        
        #expect(checker.foundTopicsHeadings.count == 3)
        let firstTopicsHeading  = try #require(document.child(at: 1) as? Heading)
        let secondTopicsHeading = try #require(document.child(at: 3) as? Heading)
        let thirdTopicsHeading  = try #require(document.child(at: 5) as? Heading)
        
        #expect(checker.problems.count == 2)
        for (problem, expectedDiagnosticRange) in zip(checker.problems, [secondTopicsHeading.range, thirdTopicsHeading.range]) {
            #expect(problem.diagnostic.summary == "Topics section can only appear once per page")
            #expect(problem.diagnostic.explanation == "A second-level heading named 'Topics' is reserved for the section you use to organize your documentation hierarchy. Each page can only have a single Topics section.")
            
            
            #expect(problem.possibleSolutions.count == 2)
            let firstSolution = try #require(problem.possibleSolutions.first)
            #expect(firstSolution.summary == "Change heading name")
            #expect(firstSolution.replacements.count == 1)
            #expect(firstSolution.replacements.first?.range == expectedDiagnosticRange)
            #expect(firstSolution.replacements.first?.replacement == "## <#New heading name#>")
            
            let secondSolution = try #require(problem.possibleSolutions.last)
            #expect(secondSolution.summary == "Move this section's content under the first Topics section")
            #expect(secondSolution.replacements.count == 0)
            
            let diagnostic = problem.diagnostic
            #expect(diagnostic.identifier == "MultipleTopicsSections")
            #expect(problem.diagnostic.range == expectedDiagnosticRange)
            
            let note = try #require(diagnostic.notes.first)
            #expect(note.range == firstTopicsHeading.range)
            #expect(note.message == "Topics section starts here")
        }
    }
}
