/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationInputFileTypesTests: XCTestCase {
    func testIsCustomHeader() {
        XCTAssertTrue(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "header")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "/header.html/foo")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationInputFileTypes.isCustomHeader(
            URL(fileURLWithPath: "DocC.docc/header.html")))
    }

    func testIsCustomFooter() {
        XCTAssertTrue(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer.html")))
        XCTAssertTrue(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "footer")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "/footer.html/foo")))
        XCTAssertFalse(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "header.html")))
        XCTAssertTrue(DocumentationInputFileTypes.isCustomFooter(
            URL(fileURLWithPath: "DocC.docc/footer.html")))
    }

    func testIsThemeSettingsFile() {
        XCTAssertTrue(DocumentationInputFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "theme-settings.json")))
        XCTAssertTrue(DocumentationInputFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "/a/b/theme-settings.json")))

        XCTAssertFalse(DocumentationInputFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "theme-settings.txt")))
        XCTAssertFalse(DocumentationInputFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "not-theme-settings.json")))
        XCTAssertFalse(DocumentationInputFileTypes.isThemeSettingsFile(
            URL(fileURLWithPath: "/a/theme-settings.json/bar")))
    }
}
