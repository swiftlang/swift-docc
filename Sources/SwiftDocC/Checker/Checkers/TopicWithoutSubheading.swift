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
 A `Topic` should have at least one subheading.
 */
public struct TopicWithoutSubheading: Checker {
    public var problems = [Problem]()

    private var sourceFile: URL?

    /// Creates a new checker that detects Topics without subheadings.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitDocument(_ document: Document) -> () {
        let headings = getHeadings(document: document)
        for (index, element) in headings.enumerated() {
            guard element.title == "Topics" else {
                continue
            }

            if !hasSubheading(heading: element, subnodes: headings.dropFirst(index + 1)) {
                warnHeading(element)
            }
        }
    }

    private func getHeadings(document: Document) -> [Heading] {
        return (0..<document.childCount).compactMap { index -> Heading? in
            guard let heading = document.child(at: index) as? Heading else {
                return nil
            }

            return heading
        }
    }

    private func hasSubheading(heading: Heading, subnodes: ArraySlice<Heading>) -> Bool {
        for subnode in subnodes {
            if subnode.level <= heading.level {
                break
            }

            return true
        }

        return false
    }

    private mutating func warnHeading(_ heading: Heading) {
        let explanation = """
        Topics headings must have at least one subheading.
        """

        let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: heading.range, identifier:       "org.swift.docc.TopicWithoutSubheading", summary: "Invalid use of Topics heading.", explanation: explanation)
        problems.append(Problem(diagnostic: diagnostic, possibleSolutions: []))
    }
}
