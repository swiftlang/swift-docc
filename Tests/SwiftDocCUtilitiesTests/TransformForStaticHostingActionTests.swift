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

class TransformForStaticHostingActionTests: StaticHostingBaseTests {

    /// Creates a DocC archive and then archive then executes and TransformForStaticHostingAction on it to produce static content which is then validated.
    func testTransformForStaticHostingTestExternalOutput() throws {
        
        // Convert a test bundle as input for the TransformForStaticHostingAction
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        
        defer { try? fileManager.removeItem(at: targetURL) }
        
        let templateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        defer { try? fileManager.removeItem(at: templateURL) }
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        defer { try? fileManager.removeItem(at: targetBundleURL) }
        
        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil
        )
       
        _ = try action.perform(logHandle: .standardOutput)
        
        let outputURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        defer { try? fileManager.removeItem(at: outputURL) }
    
        let basePath =  "test/folder"
        
        let testTemplateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let indexHTML = Folder.testHTMLTemplate(basePath: basePath)

        defer { try? fileManager.removeItem(at: testTemplateURL) }

        var transformAction = try TransformForStaticHostingAction(documentationBundleURL: targetBundleURL, outputURL: outputURL, staticHostingBasePath: basePath, htmlTemplateDirectory: testTemplateURL)
        
        _ = try transformAction.perform(logHandle: .standardOutput)
        
        var isDirectory: ObjCBool = false
        
        // Test an output folder exists
        guard fileManager.fileExists(atPath: outputURL.path, isDirectory: &isDirectory) else {
            XCTFail("TransformForStaticHostingAction failed to create output folder")
            return
        }
        
        // Test the output folder really is a folder.
        XCTAssert(isDirectory.boolValue)
        
        // Test the content of the output folder.
        var expectedContent = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)
        expectedContent += templateFolder.content.filter { $0 is Folder }.map{ $0.name }
        expectedContent += ["documentation", "tutorials"]
        
        let output = try fileManager.contentsOfDirectory(atPath: outputURL.path)
        XCTAssertEqual(Set(output), Set(expectedContent), "Unexpect output")
    
        for item in output {
            
            // Test the content of the documentation and tutorial folders match the expected content from the doccarchive.
            switch item {
            case "documentation":
                compareJSONFolder(fileManager: fileManager,
                               output: outputURL.appendingPathComponent("documentation"),
                               input:  targetBundleURL.appendingPathComponent("data").appendingPathComponent("documentation"),
                               indexHTML: indexHTML)
            case "tutorials":
                compareJSONFolder(fileManager: fileManager,
                               output: outputURL.appendingPathComponent("tutorials"),
                               input:  targetBundleURL.appendingPathComponent("data").appendingPathComponent("tutorials"),
                               indexHTML: indexHTML)
            default:
                continue
            }
        }
        
    }
    
    
    // Creates a DocC archive and then archive then executes and TransformForStaticHostingAction on it to produce static content which is then validated.
    func testTransformForStaticHostingActionTestInPlaceOutput() throws {
        
        // Convert a test bundle as input for the TransformForStaticHostingAction
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
            
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: targetURL) }
    
        let templateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        defer { try? fileManager.removeItem(at: templateURL) }
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        
        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil
        )
       
        _ = try action.perform(logHandle: .standardOutput)
        
      
        let basePath =  "test/folder"
        let testTemplateURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let indexHTML = Folder.testHTMLTemplate(basePath: basePath)
        var expectedContent = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)
        
        defer { try? fileManager.removeItem(at: testTemplateURL) }

        var transformAction = try TransformForStaticHostingAction(documentationBundleURL: targetBundleURL, outputURL: nil, staticHostingBasePath: basePath, htmlTemplateDirectory: testTemplateURL)
        
        _ = try transformAction.perform(logHandle: .standardOutput)
        
        var isDirectory: ObjCBool = false
        
        // Test an output folder exists
        guard fileManager.fileExists(atPath: targetBundleURL.path, isDirectory: &isDirectory) else {
            XCTFail("TransformForStaticHostingAction - Output Folder not Found")
            return
        }
        
        // Test the output folder really is a folder.
        XCTAssert(isDirectory.boolValue)
        
        // Test the content of the output folder.
        expectedContent += templateFolder.content.filter { $0 is Folder }.map{ $0.name }
        expectedContent += ["documentation", "tutorials"]
        
        let output = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)
        XCTAssertEqual(Set(output), Set(expectedContent), "Unexpect output")
    
        for item in output {
            
            // Test the content of the documentation and tutorial folders match the expected content from the doccarchive.
            switch item {
            case "documentation":
                compareJSONFolder(fileManager: fileManager,
                               output: targetBundleURL.appendingPathComponent("documentation"),
                               input:  targetBundleURL.appendingPathComponent("data").appendingPathComponent("documentation"),
                               indexHTML: indexHTML)
            case "tutorials":
                compareJSONFolder(fileManager: fileManager,
                               output: targetBundleURL.appendingPathComponent("tutorials"),
                               input:  targetBundleURL.appendingPathComponent("data").appendingPathComponent("tutorials"),
                               indexHTML: indexHTML)
            default:
                continue
            }
        }
    }
}

