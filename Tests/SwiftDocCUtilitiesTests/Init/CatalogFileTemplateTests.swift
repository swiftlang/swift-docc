/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

final class CatalogFileTemplateTests: XCTestCase {

    func testFormattedTechnologyRoot() {
        let article = CatalogFileTemplate(
            title: "MyTestArticle",
            content: """
            Test article summary
            ## Overview
            Test article overview
            """,
            isTechnologyRoot: true
        )
        let rawArticle = """
        # MyTestArticle

        @Metadata {
          @TechnologyRoot
        }

        Test article summary
        ## Overview
        Test article overview
        """
        XCTAssertEqual(article.content, rawArticle)
    }
    
}
