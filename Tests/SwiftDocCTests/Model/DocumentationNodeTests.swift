/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
@testable import SwiftDocC
import XCTest

class DocumentationNodeTests: XCTestCase {
    func testH4AndUpAnchorSections() throws {
        let articleSource = """
        # Title

        ## Heading2

        ### Heading3
        
        #### Heading4
        
        ##### Heading5

        ###### Heading6
        """
        
        let article = Article(markup: Document(parsing: articleSource, options: []), metadata: nil, redirects: nil, options: [:])
        let node = try DocumentationNode(
            reference: ResolvedTopicReference(bundleIdentifier: "org.swift.docc", path: "/blah", sourceLanguage: .swift),
            article: article
        )
        XCTAssertEqual(node.anchorSections.count, 5)
        for (index, anchorSection) in node.anchorSections.enumerated() {
            let expectedTitle = "Heading\(index + 2)"
            XCTAssertEqual(anchorSection.title, expectedTitle)
            XCTAssertEqual(anchorSection.reference, node.reference.withFragment(expectedTitle))
        }
    }
}
