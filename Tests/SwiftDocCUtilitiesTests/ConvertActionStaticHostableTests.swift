/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
    func testConvertActionStaticHostableTestOutput() throws {
        
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = try createTemporaryDirectory()
            
        let fileManager = FileManager.default
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        
        let testTemplateURL = try createTemporaryDirectory().appendingPathComponent("testTemplate")
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let basePath =  "test/folder"
        let indexHTML = Folder.testHTMLTemplate(basePath: "test/folder")

        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: testTemplateURL,
            emitDigest: false,
            currentPlatforms: nil,
            transformForStaticHosting: true,
            hostingBasePath: basePath,
            temporaryDirectory: try createTemporaryDirectory()
        )
       
        _ = try action.perform(logHandle: .standardOutput)
        
        // Test the content of the output folder.
        var expectedContent = ["data", "documentation", "tutorials", "downloads", "images", "metadata.json" ,"videos", "index.html", "index"]
        expectedContent += templateFolder.content.filter { $0 is Folder }.map{ $0.name }
        
        let output = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)
        XCTAssertEqual(Set(output), Set(expectedContent), "Unexpect output")
    
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

