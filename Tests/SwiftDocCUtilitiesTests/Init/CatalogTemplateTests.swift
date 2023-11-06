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

    func testMalformedCatalogTemplateFileURL() {
        let catalogTitle = "Catalog Title"
        let catalogArticles = [
            "": CatalogFileTemplate(
                title: "RootArticle",
                content: """
                
                Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                
                ## Overview
                
                Add one or more paragraphs that introduce your content overview.
                """,
                isTechnologyRoot: true
            )
        ]
        let additionalDirectories = ["Resources", "Essentials/Resources/"]
        // Test that the template throws an error when the files URLs
        // are not formatted properly.
        XCTAssertThrowsError(
            try CatalogTemplate(title: catalogTitle, files: catalogArticles, additionalDirectories: additionalDirectories)
        ) { error in
            XCTAssertEqual(error as! CatalogTemplate.Error, CatalogTemplate.Error.malformedCatalogFileURL(""))
        }
    }
    
    func testMalformedCatalogTemplateDirectoryURL() {
        let catalogTitle = "Catalog Title"
        let catalogArticles = [
            "File.md": CatalogFileTemplate(
                title: "RootArticle",
                content: """
                
                Add a single sentence or sentence fragment, which DocC uses as the page’s abstract or summary.
                
                ## Overview
                
                Add one or more paragraphs that introduce your content overview.
                """,
                isTechnologyRoot: true
            )
        ]
        let additionalDirectories = ["Resources/", "Essentials/Resources"]
        // Test that the template throws an error when the directories URLs
        // are not formatted properly.
        XCTAssertThrowsError(
            try CatalogTemplate(title: catalogTitle, files: catalogArticles, additionalDirectories: additionalDirectories)
        ) { error in
            XCTAssertEqual(error as! CatalogTemplate.Error, CatalogTemplate.Error.malformedCatalogDirectoryURL("Essentials/Resources"))
        }
    }
}
