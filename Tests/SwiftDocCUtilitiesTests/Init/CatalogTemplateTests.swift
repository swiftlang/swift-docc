/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

final class CatalogTemplateTests: XCTestCase {

    func testMalformedCatalogTemplateCreation() {
        let catalogTitle = "Catalog Tite"
        let catalogArticles = [
            "": ArticleTemplate(
                title: "RootArticle",
                content: """
                
                Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                
                ## Overview
                
                Add one or more paragraphs that introduce your content overview.
                """,
                isTechnologyRoot: true
            )
        ]
        let additionalDirectories = ["Resources/", "Essentials/Resources/"]
        XCTAssertThrowsError(
            try CatalogTemplate(title: catalogTitle, articles: catalogArticles, additionalDirectories: additionalDirectories)
        ) { error in
            XCTAssertEqual(error as! CatalogTemplate.Error, CatalogTemplate.Error.malformedCatalogTemplate)
        }
    }
}
