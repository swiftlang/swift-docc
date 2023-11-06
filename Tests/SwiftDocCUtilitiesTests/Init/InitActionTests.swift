/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

final class InitActionTests: XCTestCase {
    
    let fileManager = FileManager.default
    let documentationTitle = "MyTestDocumentation"
    
    func testInitActionCreatesArticleOnlyCatalog() throws {
        let outputURL = try createTemporaryDirectory()
        var action = try InitAction(
            catalogOutputDirectory: outputURL,
            documentationTitle: documentationTitle,
            catalogTemplate: .articleOnly
        )
        var isDirectory: ObjCBool = false
        _ = try action.perform(logHandle: .standardOutput)
        // Test an output folder exists
        guard fileManager.fileExists(atPath: "\(outputURL.path)/\(documentationTitle).docc", isDirectory: &isDirectory) else {
            XCTFail("InitAction failed to create output folder")
            return
        }
        // Test the output folder really is a folder.
        XCTAssert(isDirectory.boolValue)
        // Test the top-level content of the output folder is the expected one.
        var expectedContent = ["Essentials", "\(documentationTitle).md", "Resources"]
        var outputCatalogContent = try fileManager.contentsOfDirectory(
            atPath: outputURL.appendingPathComponent("\(documentationTitle).docc").path
        ).sorted()
        XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
        for item in outputCatalogContent {
            // Test the content of generated catalog matches the expected content from the template catalog.
            switch item {
            case "Essentials":
                expectedContent = ["Resources", "getting-started.md", "more-information.md"]
                outputCatalogContent = try fileManager.contentsOfDirectory(atPath: "\(outputURL.path)/\(documentationTitle).docc/Essentials/").sorted()
                XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
            default:
                continue
            }
        }
    }

}
