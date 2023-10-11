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
    
    func testInitActionCreatesDocCatalog() throws {
        let outputURL = try createTemporaryDirectory()
        var action = try InitAction(
            catalogOutputDirectory: outputURL,
            documentationTitle: "MyTestDocumentation",
            catalogTemplate: .base,
            includeTutorial: false
        )
        var isDirectory: ObjCBool = false
        _ = try action.perform(logHandle: .standardOutput)
        // Test an output folder exists
        guard fileManager.fileExists(atPath: "\(outputURL.path)/MyTestDocumentation.docc", isDirectory: &isDirectory) else {
            XCTFail("InitAction failed to create output folder")
            return
        }
        // Test the output folder really is a folder.
        XCTAssert(isDirectory.boolValue)
    }
    
    func testInitActionCatalogContent() throws {
        let outputURL = try createTemporaryDirectory()
        var action = try InitAction(
            catalogOutputDirectory: outputURL,
            documentationTitle: "MyTestDocumentation",
            catalogTemplate: .base,
            includeTutorial: false
        )
        _ = try action.perform(logHandle: .standardOutput)
        // Test the top-level content of the output folder.
        var expectedContent = ["Essentials", "MyTestDocumentation.md", "Resources"]
        var outputCatalogContent = try fileManager.contentsOfDirectory(
            atPath: outputURL.appendingPathComponent("MyTestDocumentation.docc").path
        ).sorted()
        XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
        
        for item in outputCatalogContent {
            // Test the content of generated catalog matches the expected content from the template catalog.
            switch item {
            case "Essentials":
                expectedContent = ["Resources", "getting_started.md", "more_information.md"]
                outputCatalogContent = try fileManager.contentsOfDirectory(atPath: "\(outputURL.path)/MyTestDocumentation.docc/Essentials/").sorted()
                XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
            default:
                continue
            }
        }
    }

}
