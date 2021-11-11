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
 A Topics section  should have at least one subheading.
 */
public struct TopicsSectionWithoutSubheading: Checker {
    public var problems = [Problem]()

    private var sourceFile: URL?

    /// Creates a new checker that detects Topics sections without subheadings.
    ///
    /// - Parameter sourceFile: The URL to the documentation file that the checker checks.
    public init(sourceFile: URL?) {
        self.sourceFile = sourceFile
    }

    public mutating func visitDocument(_ document: Document) -> () {
        let headings = document.children.compactMap { $0 as? Heading }
        for (index, heading) in headings.enumerated() {
            guard heading.isTopicsSection, isMissingSubheading(heading, remainingHeadings: headings.dropFirst(index + 1)) else {
                continue
            }

            let explanation = """
            A Topics section requires at least one topic, represented by a level-3 subheading. A Topics section without topics won’t render any content.”
            """

            let diagnostic = Diagnostic(source: sourceFile, severity: .warning, range: heading.range, identifier: "org.swift.docc.TopicsSectionWithoutSubheading", summary: "Missing required subheading for Topics section.", explanation: explanation)
            problems.append(Problem(diagnostic: diagnostic))
        }
    }

    private func isMissingSubheading(_ heading: Heading, remainingHeadings: ArraySlice<Heading>) -> Bool {
        if let nextHeading = remainingHeadings.first {
            return nextHeading.level <= heading.level
        }

        return true
    }
}
