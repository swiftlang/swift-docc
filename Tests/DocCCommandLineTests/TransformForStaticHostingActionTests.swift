/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import DocCCommandLine
import DocCTestUtilities

class TransformForStaticHostingActionTests: StaticHostingBaseTests {

    /// Creates a DocC archive and then archive then executes and TransformForStaticHostingAction on it to produce static content which is then validated.
    func testTransformForStaticHostingTestExternalOutput() async throws {
        
        // Convert a test bundle as input for the TransformForStaticHostingAction
        let bundleURL = Bundle.module.url(forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = try createTemporaryDirectory()
        
        let templateURL = try createTemporaryDirectory().appendingPathComponent("template")
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        
        let action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: try createTemporaryDirectory()
        )
        _ = try await action.perform(logHandle: .none)
        
        let outputURL = try createTemporaryDirectory()//.appendingPathComponent("output")
    
        let basePath =  "test/folder"
        
        let testTemplateURL = try createTemporaryDirectory().appendingPathComponent("testTemplate")
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let indexHTML = Folder.testHTMLTemplate(basePath: basePath)

        let transformAction = try TransformForStaticHostingAction(documentationBundleURL: targetBundleURL, outputURL: outputURL, hostingBasePath: basePath, htmlTemplateDirectory: testTemplateURL)
        
        
        _ = try await transformAction.perform(logHandle: .none)
        let fileManager = FileManager.default
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
                                  output: outputURL.appendingPathComponent(NodeURLGenerator.Path.documentationFolderName),
                                  input:  targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).appendingPathComponent(NodeURLGenerator.Path.documentationFolderName),
                               indexHTML: indexHTML)
            case "tutorials":
                compareJSONFolder(fileManager: fileManager,
                                  output: outputURL.appendingPathComponent(NodeURLGenerator.Path.tutorialsFolderName),
                                  input:  targetBundleURL.appendingPathComponent(NodeURLGenerator.Path.dataFolderName).appendingPathComponent(NodeURLGenerator.Path.tutorialsFolderName),
                               indexHTML: indexHTML)
            default:
                continue
            }
        }
        
    }
    
    
    // Creates a DocC archive and then archive then executes and TransformForStaticHostingAction on it to produce static content which is then validated.
    func testTransformForStaticHostingActionTestInPlaceOutput() async throws {
        
        // Convert a test bundle as input for the TransformForStaticHostingAction
        let bundleURL = Bundle.module.url(forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
        let targetURL = try createTemporaryDirectory()
            
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: targetURL, withIntermediateDirectories: true, attributes: nil)
        defer { try? fileManager.removeItem(at: targetURL) }
    
        let templateURL = try createTemporaryDirectory().appendingPathComponent("template")
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        
        let targetBundleURL = targetURL.appendingPathComponent("Result.doccarchive")
        
        let action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetBundleURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: try createTemporaryDirectory()
        )
        _ = try await action.perform(logHandle: .none)
        
        let basePath =  "test/folder"
        let testTemplateURL = try createTemporaryDirectory().appendingPathComponent("testTemplate")
        let templateFolder = Folder.testHTMLTemplateDirectory
        try templateFolder.write(to: testTemplateURL)

        let indexHTML = Folder.testHTMLTemplate(basePath: basePath)
        var expectedContent = try fileManager.contentsOfDirectory(atPath: targetBundleURL.path)

        let transformAction = try TransformForStaticHostingAction(documentationBundleURL: targetBundleURL, outputURL: nil, hostingBasePath: basePath, htmlTemplateDirectory: testTemplateURL)
        
        _ = try await transformAction.perform(logHandle: .none)
        
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

    func testTransformForStaticHostingPreservesCustomTemplatesInGeneratedRoutePagesForExternalOutput() async throws {
        try await assertTransformForStaticHostingPreservesCustomTemplatesInGeneratedRoutePages(outputIsExternal: true)
    }

    func testTransformForStaticHostingPreservesCustomTemplatesInGeneratedRoutePagesForInPlaceOutput() async throws {
        try await assertTransformForStaticHostingPreservesCustomTemplatesInGeneratedRoutePages(outputIsExternal: false)
    }

    private func assertTransformForStaticHostingPreservesCustomTemplatesInGeneratedRoutePages(outputIsExternal: Bool) async throws {
        let displayName = "CustomTemplateStaticHosting"
        let identifier = "com.test.custom-template-static-hosting"
        let headerContent = "<header>custom header</header>"
        let footerContent = "<footer>custom footer</footer>"
        let hostingBasePath = "custom/base/path"

        let bundle = Folder(name: "\(displayName).docc", content: [
            InfoPlist(displayName: displayName, identifier: identifier),
            TextFile(name: "header.html", utf8Content: headerContent),
            TextFile(name: "footer.html", utf8Content: footerContent),
            TextFile(name: "\(displayName).md", utf8Content: """
            # \(displayName)

            @Metadata {
                @TechnologyRoot
            }

            An abstract.

            ## Overview

            Some discussion.
            """)
        ])
        let convertTemplate = Folder(name: "convert-template", content: [
            TextFile(name: "index.html", utf8Content: """
            <!DOCTYPE html>
            <html lang="en">
                <head>
                    <title>Original Template</title>
                </head>
                <body><main></main></body>
            </html>
            """)
        ])
        let transformTemplate = Folder(name: "transform-template", content: [
            TextFile(name: "index.html", utf8Content: """
            <!DOCTYPE html>
            <html lang="en">
                <head>
                    <title>Static Hosting Template</title>
                </head>
                <body><script src="/js/app.js"></script></body>
            </html>
            """),
            TextFile(name: "index-template.html", utf8Content: """
            <!DOCTYPE html>
            <html lang="en">
                <head>
                    <title>Static Hosting Template</title>
                </head>
                <body><script src="{{BASE_PATH}}/js/app.js"></script></body>
            </html>
            """)
        ])

        let temporaryDirectory = try createTemporaryDirectory()
        let bundleURL = try bundle.write(inside: temporaryDirectory)
        let convertTemplateURL = try convertTemplate.write(inside: temporaryDirectory)
        let transformTemplateURL = try transformTemplate.write(inside: temporaryDirectory)
        let archiveURL = temporaryDirectory.appendingPathComponent("Result.doccarchive", isDirectory: true)

        let convertAction = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: archiveURL,
            htmlTemplateDirectory: convertTemplateURL,
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: try createTemporaryDirectory(),
            experimentalEnableCustomTemplates: true
        )
        _ = try await convertAction.perform(logHandle: .none)

        let outputURL = outputIsExternal ? temporaryDirectory.appendingPathComponent("static-output", isDirectory: true) : nil
        let transformAction = try TransformForStaticHostingAction(
            documentationBundleURL: archiveURL,
            outputURL: outputURL,
            hostingBasePath: hostingBasePath,
            htmlTemplateDirectory: transformTemplateURL
        )
        _ = try await transformAction.perform(logHandle: .none)

        let transformedArchiveURL = outputURL ?? archiveURL
        let generatedRouteIndexHTML = transformedArchiveURL
            .appendingPathComponent(NodeURLGenerator.Path.documentationFolderName)
            .appendingPathComponent(displayName.lowercased())
            .appendingPathComponent("index.html")
        let generatedRouteHTML = try String(contentsOf: generatedRouteIndexHTML)

        XCTAssert(
            generatedRouteHTML.contains(#"<template id="custom-header">\#(headerContent)</template>"#),
            "Generated route page didn't preserve the custom header template from the archive's root index.html."
        )
        XCTAssert(
            generatedRouteHTML.contains(#"<template id="custom-footer">\#(footerContent)</template>"#),
            "Generated route page didn't preserve the custom footer template from the archive's root index.html."
        )
        XCTAssert(
            generatedRouteHTML.contains(#"src="/\#(hostingBasePath)/js/app.js""#),
            "Generated route page didn't apply the new hosting base path."
        )
        XCTAssertFalse(
            generatedRouteHTML.contains(HTMLTemplate.tag.rawValue),
            "Generated route page still contains the unresolved hosting base path placeholder."
        )
    }
}
