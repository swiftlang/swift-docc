/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationBundleFileTypesTests: XCTestCase {
    func testIsCustomHeader() {
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html/foo")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomHeader(
            URL(fileURLWithPath: "DocC.docc/header.html")))
    }

    func testIsCustomFooter() {
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html/foo")))
        XCTAssertFalse(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationBundleFileTypes.isCustomFooter(
            URL(fileURLWithPath: "DocC.docc/footer.html")))
    }
}
