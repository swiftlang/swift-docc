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
 A document should have a single title, i.e. a single first-level heading.
 */
public struct InvalidAdditionalTitle: Checker {
    public var problems = [Problem]()
    
    /// The first level-one heading we encounter.
    private var documentTitle: Heading? = nil
    
    private var sourceFile: URL?
    
    /// Creates a new checker that detects documents with multiple titles.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }
    
    public mutating func visitHeading(_ heading: Heading) {
        // Only care about level-one headings.
        guard heading.level == 1 else { return }
        
        if documentTitle == nil {
            // This is the first level-one heading we encounter.
            documentTitle = heading
        } else if documentTitle?.range != heading.range {
            // We've found a level-one heading which isn't the title of the document.
            let explanation = """
                Level-1 headings are reserved for specifying the title of the document.
                """
            
            let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: heading.range, identifier: "org.swift.docc.InvalidAdditionalTitle", summary: "Invalid use of level-1 heading.", explanation: explanation)
            problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
        }
    }
}
