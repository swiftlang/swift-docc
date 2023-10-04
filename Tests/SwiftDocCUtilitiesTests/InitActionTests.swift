/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

final class InitActionTests: XCTestCase {

    func testInitActionCreatesDocCatalog() throws {
        let outputTargetURL = try createTemporaryDirectory()
        let testDocumentationTitle = "MyTestDocumentation"
        var action = try InitAction(
            catalogOutputDirectory: outputTargetURL.path,
            documentationTitle: testDocumentationTitle,
            includeTutorial: false
        )
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        _ = try action.perform(logHandle: .standardOutput)
        // Test an output folder exists
        guard fileManager.fileExists(atPath: "\(outputTargetURL.path)/\(testDocumentationTitle).docc", isDirectory: &isDirectory) else {
            XCTFail("InitAction failed to create output folder")
            return
        }
        // Test the output folder really is a folder.
        XCTAssert(isDirectory.boolValue)
    }
    
    func testInitActionCatalogContent() throws {
        let outputURL = try createTemporaryDirectory()
        var action = try InitAction(
            catalogOutputDirectory: outputURL.path,
            documentationTitle: "MyTestDocumentation",
            includeTutorial: false
        )
        let fileManager = FileManager.default
        _ = try action.perform(logHandle: .standardOutput)
        
        // Test the top-level content of the output folder.
        var expectedContent = ["Essentials", "MyTestDocumentation.md", "Resources"]
        var outputCatalogContent = try fileManager.contentsOfDirectory(
            atPath: outputURL.appendingPathComponent("MyTestDocumentation.docc").path
        ).sorted()
        XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
        
        // Test the content of the output subfolders.
        let templateCatalogBaseFolderURL = Bundle.module.url(
            forResource: "___FILEBASENAME_INIT___", withExtension: ".docc", subdirectory: "Test Resources/TemplateLibrary/Init"
        )!
        for item in outputCatalogContent {
            // Test the content of generated catalog matches the expected content from the template catalog.
            switch item {
            case "Essentials":
                expectedContent = ["Resources", "getting-started.md", "more-information.md"]
                outputCatalogContent = try fileManager.contentsOfDirectory(atPath: "\(templateCatalogBaseFolderURL.path)/Essentials/").sorted()
                XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
            case "Resources":
                expectedContent = ["DocC@2x.png", "DocC~dark@2x.png"]
                outputCatalogContent = try fileManager.contentsOfDirectory(atPath: "\(templateCatalogBaseFolderURL.path)/Resources/").sorted()
                XCTAssertEqual(outputCatalogContent, expectedContent, "Unexpected output")
            default:
                continue
            }
        }
    }
    
    func testInitActionTutorialGeneration() throws {
        let outputURL = try createTemporaryDirectory()
        var action = try InitAction(
            catalogOutputDirectory: outputURL.path,
            documentationTitle: "MyTestDocumentation",
            includeTutorial: true
        )
        let fileManager = FileManager.default
        _ = try action.perform(logHandle: .standardOutput)
        // Test the top-level content of the output folder.
        var expectedContent = ["Essentials", "MyTestDocumentation.md", "Resources", "Tutorial"]
        let output = try fileManager.contentsOfDirectory(
            atPath: outputURL.appendingPathComponent("MyTestDocumentation.docc").path
        ).sorted()
        XCTAssertEqual(output, expectedContent, "Unexpected output")
        
        // Test the content of the output tutorial folder.
        let templateTutorialBaseFolderURL = Bundle.module.url(
            forResource: "Tutorial", withExtension: "", subdirectory: "Test Resources/TemplateLibrary/Tutorials"
        )!
        let outputTutorialContent = try fileManager.contentsOfDirectory(atPath: templateTutorialBaseFolderURL.path).sorted()
        expectedContent = ["Resources", "table-of-contents.tutorial", "tutorial-chapter.tutorial"]
        XCTAssertEqual(outputTutorialContent, expectedContent, "Unexpected output")
    }

}
