/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
import SwiftDocCTestUtilities
@testable import SwiftDocCUtilities

final class InitActionTests: XCTestCase {
    
    let fileManager = FileManager.default
    let documentationTitle = "MyTestDocumentation"
    
    func testInitActionCreatesArticleOnlyCatalog() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent("\(documentationTitle).docc"),
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly,
            fileManager: fileManager
        )
        let result = try action.perform(logHandle: .none)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = fileManager.files.filter { $0.key.hasPrefix(result.outputs.first!.path()) }
        XCTAssertEqual(outputCatalogContent.keys.sorted(), [
            "/output/\(documentationTitle).docc",
            "/output/\(documentationTitle).docc/MyTestDocumentation2.md",
            "/output/\(documentationTitle).docc/Resources"
        ], "Unexpected output")
    }
    
    func testInitActionCreatesTutorialCatalog() throws {
        let outputLocation = Folder(name: "output", content: [])
        let fileManager = try TestFileSystem(folders: [outputLocation])
        var action = try InitAction(
            catalogOutputDirectory: outputLocation.absoluteURL.appendingPathComponent(
                "\(documentationTitle).docc"
            ),
            documentationTitle: documentationTitle,
            catalogTemplate: .tutorial,
            fileManager: fileManager
        )
        let result = try action.perform(logHandle: .standardOutput)
        // Test the content of the output folder is the expected one.
        let outputCatalogContent = fileManager.files.filter { $0.key.hasPrefix(result.outputs.first!.path()) }
        XCTAssertEqual(outputCatalogContent.keys.sorted(), [
            "/output/\(documentationTitle).docc",
            "/output/\(documentationTitle).docc/table-of-contents.tutorial",
            "/output/\(documentationTitle).docc/Chapter01",
            "/output/\(documentationTitle).docc/Chapter01/page-01.tutorial",
            "/output/\(documentationTitle).docc/Chapter01/Resources",
            "/output/\(documentationTitle).docc/Resources"
        ].sorted(), "Unexpected output")
    }

}


