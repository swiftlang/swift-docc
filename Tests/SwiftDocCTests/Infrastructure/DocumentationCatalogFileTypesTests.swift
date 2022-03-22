/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationCatalogFileTypesTests: XCTestCase {
    func testIsCustomHeader() {
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html/foo")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomHeader(
            URL(fileURLWithPath: "DocC.docc/header.html")))
    }

    func testIsCustomFooter() {
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html/foo")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFooter(
            URL(fileURLWithPath: "DocC.docc/footer.html")))
    }
}
