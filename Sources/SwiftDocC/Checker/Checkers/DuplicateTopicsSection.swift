/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

/**
 A `Document` may only have one level-2 "Topics" heading at the top level, since it serves as structured data for a documentation bundle's hierarchy.
 */
public struct DuplicateTopicsSections: Checker {
    /// The list of level-2 headings with the text "Topics" found in the document.
    public var foundTopicsHeadings = [Heading]()
    private var sourceFile: URL?
    
    /// Creates a new checker that detects documents with multiple "Topics" sections.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public var problems: [Problem] {
        guard foundTopicsHeadings.count > 1 else {
            return []
        }
        let first = foundTopicsHeadings[0]
        let duplicates = foundTopicsHeadings[1...]
        return duplicates.map { duplicateHeading -> Problem in
            let range = duplicateHeading.range!
            let notes: [DiagnosticNote]
            if let sourceFile = sourceFile, let range = first.range {
                notes = [DiagnosticNote(source: sourceFile, range: range, message: "First Topics Section starts here.")]
            } else {
                notes = []
            }
            let explanation = """
                A second-level heading with the name "Topics" is a reserved heading name you use to begin a section to organize topics into task groups. To resolve this issue, change the name of this heading or merge the contents of both topics sections under a single Topics heading.
                """
            let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: range, identifier: "org.swift.docc.MultipleTopicsSections", summary: "The Topics section may only appear once in a document", explanation: explanation, notes: notes)
            return Problem(diagnostic: diagnostic, possibleSolutions: [])
        }
    }
    
    public mutating func visitHeading(_ heading: Heading) {
        guard heading.isTopicsSection,
              heading.parent is Document? else {
                return
        }
        foundTopicsHeadings.append(heading)
    }
}
