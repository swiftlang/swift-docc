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
 A document should have an abstract.
 
 If the first element after the title (if there is one) is not a paragraph, a warning is produced.
 */
public struct MissingAbstract: Checker {
    public var problems = [Problem]()
    
    private var sourceFile: URL?
    
    /// Creates a new checker that detects documents without abstracts.
    ///
    /// - Parameter document: The documentation node that the checker checks.
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }
    
    public mutating func visitDocument(_ document: Document) {
        // The document has an abstract.
        let abstractExists = DocumentationMarkup(markup: document, parseUpToSection: .abstract).abstractSection?.paragraph != nil
        
        // The document doesn't have a title nor children (the document is empty).
        let isDocumentEmpty = document.title == nil && !document.hasChildren
        
        // There is no content after the title.
        let onlyTitleExists = document.title != nil && document.childCount == 1
        
        // Only produce a warning if there is no abstract and there is content after the title.
        if abstractExists || isDocumentEmpty || onlyTitleExists {
            return
        }
        
        let explanation = """
            An abstract provides a short description of the document. Write a paragraph below the title of the document to use it as an abstract.
            """
        
        let zeroLocation = SourceLocation(line: 1, column: 1, source: sourceFile)
        
        let titleHeadingRange = document.child(at: 0)?.range
        let titleRange = titleHeadingRange ?? zeroLocation..<zeroLocation
        let diagnostic = Diagnostic(source: sourceFile,
                                         severity: .information,
                                         range: titleRange,
                                         identifier: "org.swift.docc.DocumentHasNoAbstract",
                                         summary: "This document does not have a summary.",
                                         explanation: explanation)

        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
    }
}

