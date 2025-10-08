/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class ConvertActionStaticHostableTests: StaticHostingBaseTests {
    /// Creates a DocC archive and then archives it with options  to produce static content which is then validated.
    func testConvertActionStaticHostableTestOutput() async throws {
        
        let bundleURL = Bundle.module.url(forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = try createTemporaryDirectory()
            
        let fileManager = FileManager.default
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        
        let testTemplateURL = try createTemporaryDirectory().appendingPathComponent("testTemplate")
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let basePath = "test/folder"
        let indexHTML = Folder.testHTMLTemplate(basePath: "test/folder")

        let action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: testTemplateURL,
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: try createTemporaryDirectory(),
            transformForStaticHosting: true,
            hostingBasePath: basePath
        )
        _ = try await action.perform(logHandle: .none)
        
        // Test the content of the output folder.
        var expectedContent = [
            "data", "documentation", "tutorials", "downloads", "images", "videos",
            "index.html", "index",
            "metadata.json", "link-hierarchy.json", "linkable-entities.json"
        ]
        expectedContent += templateFolder.content.filter { $0 is Folder }.map{ $0.name }
        
        let output = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)
        XCTAssertEqual(Set(output), Set(expectedContent), "Unexpected output")
    
        for item in output {
            
            // Test the content of the documentation and tutorial folders match the expected content from the doccarchive.
            switch item {
            case "documentation":
                compareJSONFolder(fileManager: fileManager,
                                  output: targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.documentationFolderName),
                                  input:  targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).appendingPathComponent(NodeURLGenerator.Path.documentationFolderName),
                               indexHTML: indexHTML)
            case "tutorials":
                compareJSONFolder(fileManager: fileManager,
                                  output: targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.tutorialsFolderName),
                                  input:  targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).appendingPathComponent(NodeURLGenerator.Path.tutorialsFolderName),
                               indexHTML: indexHTML)
            default:
                continue
            }
        }
        
    }
}

