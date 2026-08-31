/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
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

    func testIsThemeSettingsFile() {
        XCTAssertTrue(DocumentationCatalogFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "theme-settings.json")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "/a/b/theme-settings.json")))

        XCTAssertFalse(DocumentationCatalogFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "theme-settings.txt")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "not-theme-settings.json")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "/a/theme-settings.json/bar")))
    }

    func testIsCustomFavicon() {
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFavicon(
            URL(fileURLWithPath: "favicon.ico")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFavicon(
            URL(fileURLWithPath: "/favicon.ico")))
        XCTAssertTrue(DocumentationCatalogFileTypes.isCustomFavicon(
            URL(fileURLWithPath: "DocC.docc/favicon.ico")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomFavicon(
            URL(fileURLWithPath: "favicon")))
        XCTAssertFalse(DocumentationCatalogFileTypes.isCustomFavicon(
            URL(fileURLWithPath: "/favicon.ico/foo")))
    }
}
