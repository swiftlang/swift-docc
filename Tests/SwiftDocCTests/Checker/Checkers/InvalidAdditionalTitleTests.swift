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

struct InvalidAdditionalTitleTests {
    
    @Test
    func doesNotWarnForSingleArticlePageTitle() {
        let (diagnostics, _) = check(content: "# Title")
        #expect(diagnostics.isEmpty)
    }
    
    @Test
    func doesNotWarnForSingleDocumentationExtensionAssociation() {
        let (diagnostics, _) = check(content:  "# ``SomeSymbol``")
        #expect(diagnostics.isEmpty)
    }
    
    @Test(arguments: [
        "First",     // The page title of an article
        "``First``", // A symbol association for a documentation extension
    ], [
        "Second",     // Another heading, like the title of an article
        "``Second``", // An association with a symbol for a documentation extension
    ])
    func warnsAboutSecondHeading(firstHeadingRawContent: String, secondHeadingRawContent: String) throws {
        let (diagnostics, document) = check(content:  """
            # \(firstHeadingRawContent)
            
            After this abstract there's another first-level heading
            
            # \(secondHeadingRawContent)
            """)
        
        #expect(diagnostics.count == 1)
        
        let firstHeading  = try #require(document.child(at: 0) as? Heading)
        let secondHeading = try #require(document.child(at: 2) as? Heading)
        
        let isDocumentationExtensionFile = firstHeading.startsWithAnyLink
        let diagnostic = try #require(diagnostics.first)
        
        // Verify the diagnostic
        if isDocumentationExtensionFile {
            #expect(diagnostic.identifier == "MultipleSymbolExtensionAssociations")
            #expect(diagnostic.summary == "Documentation extension file can only extend one symbol")
            #expect(diagnostic.explanation == "A first-level heading with a symbol link is reserved for defining which symbol a documentation extension file is associated with.")
        } else {
            #expect(diagnostic.identifier == "MultiplePageTitles")
            #expect(diagnostic.summary == "Page title can only be specified once")
            #expect(diagnostic.explanation == "A first-level heading is reserved for specifying the title of an article.")
        }
        #expect(diagnostic.range == secondHeading.range, "The warning highlights the second level-1 heading")
        
        // Verify the note
        #expect(diagnostic.notes.count == 1)
        let note = try #require(diagnostic.notes.first)
        if isDocumentationExtensionFile {
            #expect(note.message == "Previously extending 'First' here")
        } else {
            #expect(note.message == "Previously specified title 'First' here")
        }
        #expect(note.range == firstHeading.range, "The note points to the first level-1 heading")
        
        // Verify the solutions
        #expect(diagnostic.possibleSolutions.count == (isDocumentationExtensionFile ? 1 : 2))
        
        let firstSolution = try #require(diagnostic.possibleSolutions.first)
        #expect(firstSolution.summary == "Remove heading")
        #expect(firstSolution.replacements.count == 1)
        #expect(firstSolution.replacements.first?.range == secondHeading.range, "The replacement modifies the second heading")
        #expect(firstSolution.replacements.first?.replacement == "", "The solution removes the heading completely")
        
        if !isDocumentationExtensionFile {
            let secondSolution = try #require(diagnostic.possibleSolutions.last)
            #expect(secondSolution.summary == "Change to second-level heading")
            #expect(secondSolution.replacements.count == 1)
            #expect(secondSolution.replacements.first?.range == secondHeading.range, "The replacement modifies the second heading")
            #expect(secondSolution.replacements.first?.replacement == "## \(secondHeadingRawContent)", "The solution changes the heading level without altering the content of the heading")
        }
    }
    
    @Test(arguments: [
        "First",     // The page title of an article
        "``First``", // A symbol association for a documentation extension
    ])
    func eachAdditionalHeadingRefersBackToTheFirstHeading(firstHeadingRawContent: String) throws {
        let (diagnostics, document) = check(content:  """
            # \(firstHeadingRawContent)
            
            After this abstract there are 3 additional first-level headings
            
            # Second
            # ``Third``
            # Fourth
            """)
        #expect(diagnostics.count == 3)
        
        let firstHeading  = try #require(document.child(at: 0) as? Heading)
        
        let additionalHeadings = document.children.dropFirst().compactMap { $0 as? Heading }
        #expect(additionalHeadings.count == 3)
        
        for (diagnostic, additionalHeading) in zip(diagnostics, additionalHeadings) {
            #expect(diagnostic.range == additionalHeading.range, "The warning highlights each heading")
            
            // Verify the note
            #expect(diagnostic.notes.count == 1)
            let note = try #require(diagnostic.notes.first)
            #expect(note.message.hasPrefix("Previously "), "The note refers to an element earlier in the page's markup")
            #expect(note.range == firstHeading.range, "The note points to the first heading")
        }
    }
    
    private func check(content: String) -> ([Diagnostic], Document) {
        // This file is never read, it's only used as the source of diagnostics and notes
        var checker = InvalidAdditionalTitle(sourceFile: URL(fileURLWithPath: "/path/to/some-fake-file.md"))
        let document = Document(parsing: content, options: [.parseSymbolLinks])
        checker.visit(document)
        return (checker.diagnostics, document)
    }
}
