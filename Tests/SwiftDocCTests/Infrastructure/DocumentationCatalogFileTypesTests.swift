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
        assertThat(DocumentationCatalogFileTypes.isCustomHeader, matchesFilesNamed: "header", withExtension: "html")
    }

    func testIsCustomFooter() {
        assertThat(DocumentationCatalogFileTypes.isCustomFooter, matchesFilesNamed: "footer", withExtension: "html")
    }

    func testIsThemeSettingsFile() {
        assertThat(DocumentationCatalogFileTypes.isThemeSettingsFile, matchesFilesNamed: "theme-settings", withExtension: "json")
    }
    
    func testIsCustomScriptsFile() {
        assertThat(DocumentationCatalogFileTypes.isCustomScriptsFile, matchesFilesNamed: "custom-scripts", withExtension: "json")
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

    private func assertThat(
        _ predicate: (URL) -> Bool,
        matchesFilesNamed fileName: String,
        withExtension extension: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let fileNameWithExtension = "\(fileName).\(`extension`)"
        
        let pathsThatShouldMatch = [
            fileNameWithExtension,
            "/\(fileNameWithExtension)",
            "DocC/docc/\(fileNameWithExtension)",
            "/a/b/\(fileNameWithExtension)"
        ].map { URL(fileURLWithPath: $0) }
        
        let pathsThatShouldNotMatch = [
            fileName,
            "/\(fileNameWithExtension)/foo",
            "/a/\(fileNameWithExtension)/bar",
            "\(fileName).wrongextension",
            "wrongname.\(`extension`)"
        ].map { URL(fileURLWithPath: $0) }
        
        for url in pathsThatShouldMatch {
            XCTAssertTrue(predicate(url), file: file, line: line)
        }
        
        for url in pathsThatShouldNotMatch {
            XCTAssertFalse(predicate(url), file: file, line: line)
        }
    }
}
