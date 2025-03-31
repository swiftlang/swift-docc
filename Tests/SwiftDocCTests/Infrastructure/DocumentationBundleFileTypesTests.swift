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
        test(whether: DocumentationBundleFileTypes.isCustomHeader, matchesFilesNamed: "header", withExtension: "html")
    }

    func testIsCustomFooter() {
        test(whether: DocumentationBundleFileTypes.isCustomFooter, matchesFilesNamed: "footer", withExtension: "html")
    }

    func testIsThemeSettingsFile() {
        test(whether: DocumentationBundleFileTypes.isThemeSettingsFile, matchesFilesNamed: "theme-settings", withExtension: "json")
    }
    
    func testIsCustomScriptsFile() {
        test(whether: DocumentationBundleFileTypes.isCustomScriptsFile, matchesFilesNamed: "custom-scripts", withExtension: "json")
    }
    
    private func test(
        whether predicate: (URL) -> Bool,
        matchesFilesNamed fileName: String,
        withExtension extension: String
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
            XCTAssertTrue(predicate(url))
        }
        
        for url in pathsThatShouldNotMatch {
            XCTAssertFalse(predicate(url))
        }
    }
}
