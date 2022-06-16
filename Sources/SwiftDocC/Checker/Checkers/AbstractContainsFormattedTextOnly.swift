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
 A document's abstract may only contain formatted text. Images and links are not allowed.
 */
public struct AbstractContainsFormattedTextOnly: Checker {
    public var problems: [Problem] = [Problem]()
    private var sourceFile: URL?
    
    /// Creates a new checker that detects non-text elements in abstracts.
    /// 
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }
    
    enum InvalidContent: CustomStringConvertible {
        case image, link
        
        var diagnosticIdentifier: String {
            switch self {
            case .image: return "org.swift.docc.SummaryContainsImage"
            case .link: return "org.swift.docc.SummaryContainsLink"
            }
        }
        
        var description: String {
            switch self {
            case .image: return "image"
            case .link: return "link"
            }
        }
    }
    
    private mutating func foundInvalidContent(_ invalidContent: InvalidContent, markup: Markup) {
        let explanation = """
            Summary should only contain (formatted) text. To resolve this issue, place links and images elsewhere in the document, or remove them.
            """
        let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: markup.range, identifier: invalidContent.diagnosticIdentifier, summary: "\(invalidContent.description.capitalized) in document summary will not be displayed", explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        problems.append(problem)
    }
    
    public mutating func visitDocument(_ document: Document) -> () {
        guard let abstract = DocumentationMarkup(markup: document, parseUpToSection: .abstract).abstractSection?.paragraph else { return }
        self.visitParagraph(abstract)
    }
    
    public mutating func visitImage(_ image: Image) {
        foundInvalidContent(.image, markup: image)
        descendInto(image)
    }
    
    public mutating func visitLink(_ link: Link) {
        foundInvalidContent(.link, markup: link)
        descendInto(link)
    }
}
