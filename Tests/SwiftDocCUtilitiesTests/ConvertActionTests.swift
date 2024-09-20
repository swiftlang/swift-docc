/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable @_spi(ExternalLinks) import SwiftDocC
@testable import SwiftDocCUtilities
import SymbolKit
import Markdown
@testable import SwiftDocCTestUtilities

class ConvertActionTests: XCTestCase {
    #if !os(iOS)
    let imageFile = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        .appendingPathComponent("figure1.png")
    
    let symbolGraphFile = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        .appendingPathComponent("FillIntroduced.symbols.json")
    
    let objectiveCSymbolGraphFile = Bundle.module.url(
        forResource: "DeckKit-Objective-C",
        withExtension: "symbols.json",
        subdirectory: "Test Resources"
    )!

    let projectZipFile = Bundle.module.url(
        forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        .appendingPathComponent("project.zip")
    
    func testCopyingImageAssets() throws {
        XCTAssert(FileManager.default.fileExists(atPath: imageFile.path))
        let testImageName = "TestImage.png"
        
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: testImageName),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: imageFile, newName: testImageName),
                ]),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
        
        // Verify that the copied image has the same capitalization as the original
        let copiedImageOutput = testDataProvider.files.keys
            .filter({ $0.hasPrefix(result.outputs[0].appendingPathComponent("images/com.test.example").path + "/") })
            .map({ $0.replacingOccurrences(of: result.outputs[0].appendingPathComponent("images/com.test.example").path + "/", with: "") })
        
        XCTAssertEqual(copiedImageOutput, [testImageName])
    }
    
    func testCopyingVideoAssets() throws {
        let videoFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("introvideo.mp4")
        
        XCTAssert(FileManager.default.fileExists(atPath: videoFile.path))
        let testVideoName = "TestVideo.mp4"
        
        // Documentation bundle that contains a video
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: videoFile, newName: testVideoName),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "videos", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: videoFile, newName: testVideoName),
                ]),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
        
        // Verify that the copied video has the same capitalization as the original
        let copiedVideoOutput = testDataProvider.files.keys
            .filter({ $0.hasPrefix(result.outputs[0].appendingPathComponent("videos/com.test.example").path + "/") })
            .map({ $0.replacingOccurrences(of: result.outputs[0].appendingPathComponent("videos/com.test.example").path + "/", with: "") })
        
        XCTAssertEqual(copiedVideoOutput, [testVideoName])
    }
    
    // Ensures we don't regress on copying download assets to the build folder (72599615)
    func testCopyingDownloadAssets() throws {
        let downloadFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("project.zip")
        
        let tutorialFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("TestTutorial.tutorial")
        
        let tutorialOverviewFile = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
                .appendingPathComponent("TestOverview.tutorial")
        
        XCTAssert(FileManager.default.fileExists(atPath: downloadFile.path))
        XCTAssert(FileManager.default.fileExists(atPath: tutorialFile.path))
        XCTAssert(FileManager.default.fileExists(atPath: tutorialOverviewFile.path))
        
        // Documentation bundle that contains a download and a tutorial that references it
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: downloadFile),
            CopyOfFile(original: tutorialFile),
            CopyOfFile(original: tutorialOverviewFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "downloads", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: downloadFile),
                ]),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    // Ensures we always create the required asset folders even if no assets are explicitly
    // provided
    func testCreationOfAssetFolders() throws {
        // Empty documentation bundle
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "downloads", content: []),
            Folder(name: "images", content: []),
            Folder(name: "videos", content: []),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testConvertsWithoutErrorsWhenBundleIsNotAtRoot() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let input = Folder(name: "nested", content: [Folder(name: "folders", content: [bundle, Folder.emptyHTMLTemplateDirectory])])

        let testDataProvider = try TestFileSystem(folders: [input, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: input.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        XCTAssertEqual(result.problems.count, 0)
    }
    
    func testConvertWithoutBundle() throws {
        let myKitSymbolGraph = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        
        XCTAssert(FileManager.default.fileExists(atPath: myKitSymbolGraph.path))
        let symbolGraphFiles = Folder(name: "Not-a-doc-bundle", content: [
            CopyOfFile(original: myKitSymbolGraph, newName: "MyKit.symbols.json")
        ])
        
        let outputLocation = Folder(name: "output", content: [])
        
        let testDataProvider = try TestFileSystem(folders: [Folder.emptyHTMLTemplateDirectory, symbolGraphFiles, outputLocation])
        
        var infoPlistFallbacks = [String: Any]()
        infoPlistFallbacks["CFBundleDisplayName"] = "MyKit" // same as the symbol graph
        infoPlistFallbacks["CFBundleIdentifier"] = "com.example.test"
        infoPlistFallbacks["CFBundleVersion"] = "1.2.3"
        infoPlistFallbacks["CDDefaultCodeListingLanguage"] = "swift"
        
        var action = try ConvertAction(
            documentationBundleURL: nil,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                infoPlistFallbacks: infoPlistFallbacks,
                additionalSymbolGraphFiles: [URL(fileURLWithPath: "/Not-a-doc-bundle/MyKit.symbols.json")]
            )
        )
        
        let result = try action.perform(logHandle: .none)
        XCTAssertEqual(result.problems.count, 0)
        XCTAssertEqual(result.outputs, [outputLocation.absoluteURL])
        
        let outputData = testDataProvider.files.filter { $0.key.hasPrefix("/output/data/documentation/") }
        
        XCTAssertEqual(outputData.keys.sorted(), [
            "/output/data/documentation/mykit",
            "/output/data/documentation/mykit.json",
            "/output/data/documentation/mykit/myclass",
            "/output/data/documentation/mykit/myclass.json",
            "/output/data/documentation/mykit/myclass/init()-33vaw.json",
            "/output/data/documentation/mykit/myclass/init()-3743d.json",
            "/output/data/documentation/mykit/myclass/myfunction().json",
            "/output/data/documentation/mykit/myprotocol.json",
            "/output/data/documentation/mykit/globalfunction(_:considering:).json",
        ].sorted())
        
        let myKitNodeData = try XCTUnwrap(outputData["/output/data/documentation/mykit.json"])
        let myKitNode = try JSONDecoder().decode(RenderNode.self, from: myKitNodeData)
        
        // Verify that framework page doesn't get automatic abstract
        XCTAssertNil(myKitNode.abstract)
        XCTAssertTrue(myKitNode.primaryContentSections.isEmpty)
        XCTAssertEqual(myKitNode.topicSections.count, 3) // Automatic curation of the symbols in the symbol graph file
        
        // Verify that non-framework symbols also do not get automatic abstracts.
        let myProtocolNodeData = try XCTUnwrap(outputData["/output/data/documentation/mykit/myprotocol.json"])
        let myProtocolNode = try JSONDecoder().decode(RenderNode.self, from: myProtocolNodeData)
        XCTAssertNil(myProtocolNode.abstract)
    }

    func testMoveOutputCreatesTargetFolderParent() throws {
        // Source folder to test moving
        let source = Folder(name: "source", content: [
            TextFile(name: "index.html", utf8Content: ""),
        ])

        // The target location to test moving to
        let target = Folder(name: "target", content: [
            Folder(name: "output", content: []),
        ])
        
        // We add only the source to the file system
        let testDataProvider = try TestFileSystem(folders: [source, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: source.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        
        let targetURL = target.absoluteURL.appendingPathComponent("output")
        
        XCTAssertNoThrow(try action.moveOutput(from: source.absoluteURL, to: targetURL))
        XCTAssertTrue(testDataProvider.fileExists(atPath: targetURL.path, isDirectory: nil))
        XCTAssertFalse(testDataProvider.fileExists(atPath: source.absoluteURL.path, isDirectory: nil))
    }
    
    func testMoveOutputDoesNotCreateIntermediateTargetFolderParents() throws {
        // Source folder to test moving
        let source = Folder(name: "source", content: [
            TextFile(name: "index.html", utf8Content: ""),
        ])

        // The target location to test moving to
        let target = Folder(name: "intermediate", content: [
            Folder(name: "target", content: [
                Folder(name: "output", content: []),
            ])
        ])
        
        // We add only the source to the file system
        let testDataProvider = try TestFileSystem(folders: [source, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: source.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        
        let targetURL = target.absoluteURL.appendingPathComponent("target").appendingPathComponent("output")
        
        XCTAssertThrowsError(try action.moveOutput(from: source.absoluteURL, to: targetURL))
    }

    func testConvertDoesNotLowercasesResourceFileNames() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "TEST.png"),
            CopyOfFile(original: imageFile, newName: "VIDEO.mov"),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: imageFile, newName: "TEST.png"),
                ]),
            ]),
            Folder(name: "videos", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: imageFile, newName: "VIDEO.mov"),
                ]),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    // Ensures that render JSON produced by the convert action
    // does not include file location information for symbols.
    func testConvertDoesNotIncludeFilePathsInRenderNodes() throws {
        // Documentation bundle that contains a symbol graph.
        // The symbol graph contains symbols that include location information.
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: symbolGraphFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Construct the URLs for the produced render json:
        
        let documentationDataDirectoryURL = result.outputs[0]
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("documentation", isDirectory: true)
        
        let fillIntroducedDirectoryURL = documentationDataDirectoryURL
            .appendingPathComponent("fillintroduced", isDirectory: true)
            
        let renderNodeURLs = [
            documentationDataDirectoryURL
                .appendingPathComponent("fillintroduced.json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosmacosonly().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlyintroduced().json", isDirectory: false),
        ]
        
        let decoder = JSONDecoder()
        
        // Process all of the render JSON:
        try renderNodeURLs.forEach { renderNodeURL in
            // Get the data for the render json
            let renderNodeJSON = try testDataProvider.contentsOfURL(renderNodeURL)
            
            // Decode the render node
            let renderNode = try decoder.decode(RenderNode.self, from: renderNodeJSON)
            
            // Confirm that the render node didn't contain the location information
            // from the symbol graph
            XCTAssertNil(renderNode.metadata.sourceFileURI)
        }
    }
    
    // Ensures that render JSON produced by the convert action does not include symbol access level information.
    func testConvertDoesNotIncludeSymbolAccessLevelsInRenderNodes() throws {
        // Documentation bundle that contains a symbol graph.
        // The symbol graph contains symbols that include access level information.
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: symbolGraphFile),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)
        
        // Construct the URLs for the produced render json:
        
        let documentationDataDirectoryURL = result.outputs[0]
            .appendingPathComponent("data", isDirectory: true)
            .appendingPathComponent("documentation", isDirectory: true)
        
        let fillIntroducedDirectoryURL = documentationDataDirectoryURL
            .appendingPathComponent("fillintroduced", isDirectory: true)
            
        let renderNodeURLs = [
            documentationDataDirectoryURL
                .appendingPathComponent("fillintroduced.json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("macosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosmacosonly().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("iosonlyintroduced().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlydeprecated().json", isDirectory: false),
            fillIntroducedDirectoryURL
                .appendingPathComponent("maccatalystonlyintroduced().json", isDirectory: false),
        ]
        
        let decoder = JSONDecoder()
        
        // Process all of the render JSON:
        try renderNodeURLs.forEach { renderNodeURL in
            // Get the data for the render json
            let renderNodeJSON = try testDataProvider.contentsOfURL(renderNodeURL)
            
            // Decode the render node
            let renderNode = try decoder.decode(RenderNode.self, from: renderNodeJSON)
            
            // Confirm that the render node didn't contain the access level of symbols.
            XCTAssertNil(renderNode.metadata.symbolAccessLevel)
        }
    }

    func testOutputFolderContainsDiagnosticJSONWhenThereAreWarnings() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorials(name: "Technology X") {
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                   
                   @Volume(name: "Volume 1") {
                      This volume contains Chapter 1.

                      @Image(source: referenced-tutorials-image, alt: "Some alt text")

                      @Chapter(name: "Chapter 1") {
                         In this chapter, you'll learn about Tutorial 1.

                         @Image(source: referenced-tutorials-image, alt: "Some alt text")
                      }
                   }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            Folder(name: "images", content: [
                Folder(name: "com.test.example", content: [
                    CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
                ]),
            ]),
            Folder(name: "videos", content: [
                Folder(name: "com.test.example", content: []),
            ]),
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: .init(line: 11, column: 7),
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "Missing required 'TutorialReference' child directive",
                    explanation: "The 'Chapter' directive requires at least one 'TutorialReference' child directive",
                    notes: []
                ),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testOutputFolderContainsDiagnosticJSONWhenThereAreErrorsAndNoTemplate() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Article(time: 10) {
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                
                   @Intro(title: "Technology X") {
                      You'll learn all about Technology X.
                   }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "hint") // report all errors during the test
        let result = try action.perform(logHandle: .none)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: .init(line: 6, column: 4),
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "Duplicate 'Intro' child directive",
                    explanation: "The 'Article' directive must have exactly one 'Intro' child directive",
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "The article 'TechnologyX' must be referenced from a Tutorial Table of Contents",
                    explanation: nil,
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .information,
                    summary: "You haven't curated 'doc://com.test.example/tutorials/TestBundle/TechnologyX'",
                    explanation: nil,
                    notes: []
                ),
            ]),
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testWarningForUncuratedTutorial() throws {
        // Documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorial(time: 10) {
                  @Intro(title: "TechologyX") {}

                  @Section(title: "Section") {
                    @Steps {}
                  }

                  @Assessments {
                    @MultipleChoice {
                      text
                      @Choice(isCorrect: true) {
                        text
                        @Justification(reaction: "reaction text") {}
                      }

                      @Choice(isCorrect: false) {
                        text
                        @Justification(reaction: "reaction text") {}
                      }
                    }
                  }
                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "hint") // report all errors during the test
        let result = try action.perform(logHandle: .none)

        // Verify that the following files and folder exist at the output location
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(name: "diagnostics.json", content: [
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .warning,
                    summary: "The tutorial 'TechnologyX' must be referenced from a Tutorial Table of Contents",
                    explanation: nil,
                    notes: []
                ),
                Digest.Diagnostic(
                    start: nil,
                    source: URL(string: "TechnologyX.tutorial"),
                    severity: .information,
                    summary: "You haven't curated 'doc://com.test.example/tutorials/TestBundle/TechnologyX'",
                    explanation: nil,
                    notes: []
                ),
            ])
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    func testOutputFolderIsNotRemovedWhenThereAreErrors() throws {
        let tutorialsFile = TextFile(name: "TechnologyX.tutorial", utf8Content: """
            @Tutorials(name: "Technology Z") {
               @Intro(title: "Technology Z") {
                  Intro text.
               }
               
               @Volume(name: "Volume A") {
                  This is a volume.

                  @Chapter(name: "Getting Started") {
                     In this chapter, you'll learn about Tutorial 1. Feel free to add more `TutorialReference`s below.

                     @TutorialReference(tutorial: "doc:Tutorial" )
                  }
               }
            }
            """
        )
        
        let tutorialFile = TextFile(name: "Tutorial.tutorial", utf8Content: """
            @Article(time: 20) {
               @Intro(title: "Basic Augmented Reality App") {
                  This is curated under a Swift page and and ObjC page.
               }
            }
            """
        )
        
        let bundleInfoPlist = InfoPlist(displayName: "TestBundle", identifier: "com.test.example")
        
        let goodBundle = Folder(name: "unit-test.docc", content: [
            tutorialsFile,
            tutorialFile,
            bundleInfoPlist,
        ])
        
        let testDataProvider = try TestFileSystem(folders: [goodBundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        do {
            var action = try ConvertAction(
                documentationBundleURL: goodBundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
            let result = try action.perform(logHandle: .none)
            
            XCTAssertFalse(
                result.didEncounterError,
                "Unexpected error occurred during conversion of test bundle."
            )
            
            // Verify that the build output folder was successfully created
            let expectedOutput = Folder(name: ".docc-build", content: [
                Folder(name: "data", content: [
                    Folder(name: "tutorials", content: []),
                ]),
            ])
            expectedOutput.assertExist(at: targetDirectory, fileManager: testDataProvider)
        }
    }

    /// Verifies that digest is correctly emitted for API documentation topics
    /// like module pages, symbols, and articles.
    func testMetadataIsWrittenToOutputFolderAPIDocumentation() throws {
        // Example documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            // An asset
            CopyOfFile(original: imageFile, newName: "image.png"),
            
            // An Article
            TextFile(name: "Article.md", utf8Content: """
                # This is an article
                Article abstract.
                
                Discussion content
                
                ![my image](image.png)
                
                ## Article Section
                
                This is another section of the __article__.
                """
            ),

            TextFile(name: "SampleArticle.md", utf8Content: """
                # Sample Article

                @Metadata {
                    @PageKind(sampleCode)
                }

                Sample abstract.

                Discussion content
                """
            ),

            // A module page
            TextFile(name: "TestBed.md", utf8Content: """
                # ``TestBed``
                TestBed abstract.
                
                TestBed discussion __content__.
                ## Topics
                ### Basics
                - <doc:Article>
                """
            ),

            // A symbol doc extensions
            TextFile(name: "A.md", utf8Content: """
                # ``TestBed/A``
                An abstract.
                
                `A` discussion __content__.
                """
            ),

            // A symbol graph
            CopyOfFile(original: Bundle.module.url(forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!),
            
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)

        // Because the page order isn't deterministic, we create the indexing records and linkable entities in the same order as the pages.
        let indexingRecords: [IndexingRecord] = action.context.knownPages.compactMap { reference in
            switch reference.path {
            case "/documentation/TestBed":
                return IndexingRecord(
                    kind: .symbol,
                    location: .topLevelPage(reference),
                    title: "TestBed",
                    summary: "TestBed abstract.",
                    headings: ["Overview"],
                    rawIndexableTextContent: "TestBed abstract. Overview TestBed discussion content."
                )
            case "/documentation/TestBed/A":
                return IndexingRecord(
                    kind: .symbol,
                    location: .topLevelPage(reference),
                    title: "A",
                    summary: "An abstract.",
                    headings: ["Overview"],
                    rawIndexableTextContent: "An abstract. Overview A discussion content."
                )
            case "/documentation/TestBundle/Article":
                return IndexingRecord(
                    kind: .article,
                    location: .topLevelPage(reference),
                    title: "This is an article",
                    summary: "Article abstract.",
                    headings: ["Overview", "Article Section"],
                    rawIndexableTextContent: "Article abstract. Overview Discussion content  Article Section This is another section of the article."
                )
            case "/documentation/TestBundle/SampleArticle":
                return IndexingRecord(
                    kind: .article,
                    location: .topLevelPage(reference),
                    title: "Sample Article",
                    summary: "Sample abstract.",
                    headings: ["Overview"],
                    rawIndexableTextContent: "Sample abstract. Overview Discussion content"
                )
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return nil
            }
        }
        let linkableEntities = action.context.knownPages.flatMap { (reference: ResolvedTopicReference) -> [LinkDestinationSummary] in
            switch reference.path {
            case "/documentation/TestBed":
                return [
                    LinkDestinationSummary(
                        kind: .module,
                        relativePresentationURL: URL(string: "/documentation/testbed")!,
                        referenceURL: reference.url,
                        title: "TestBed",
                        language: .swift,
                        abstract: "TestBed abstract.",
                        taskGroups: [
                            .init(title: "Basics", identifiers: ["doc://com.test.example/documentation/TestBundle/Article"]),
                            .init(title: "Articles", identifiers: ["doc://com.test.example/documentation/TestBundle/SampleArticle"]),
                            .init(title: "Structures", identifiers: ["doc://com.test.example/documentation/TestBed/A"]),
                        ],
                        usr: "TestBed",
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                ]
            case "/documentation/TestBed/A":
                return [
                    LinkDestinationSummary(
                        kind: .structure,
                        relativePresentationURL: URL(string: "/documentation/testbed/a")!,
                        referenceURL: reference.url,
                        title: "A",
                        language: .swift,
                        abstract: "An abstract.",
                        taskGroups: [],
                        usr: "s:7TestBed1AV",
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                ]
            case "/documentation/TestBundle/Article":
                return [
                    LinkDestinationSummary(
                        kind: .article,
                        relativePresentationURL: URL(string: "/documentation/testbundle/article")!,
                        referenceURL: reference.url,
                        title: "This is an article",
                        language: .swift,
                        abstract: "Article abstract.",
                        taskGroups: [],
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                ]
            case "/documentation/TestBundle/SampleArticle":
                return [
                    LinkDestinationSummary(
                        kind: .sampleCode,
                        relativePresentationURL: URL(string: "/documentation/testbundle/samplearticle")!,
                        referenceURL: reference.url,
                        title: "Sample Article",
                        language: .swift,
                        abstract: "Sample abstract.",
                        taskGroups: [],
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    )
                ]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        let images: [ImageReference] = action.context.knownPages.flatMap {
            reference -> [ImageReference] in
            switch reference.path {
            case "/documentation/TestBundle/Article":
                return [ImageReference(
                    name: "image.png",
                    altText: "my image",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            default:
                return []
            }
        }

        // Verify diagnostics
        guard let resultDiagnostics: [Digest.Diagnostic] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("diagnostics.json")) else {
            XCTFail("Can't find diagnostics.json in output")
            return
        }
        XCTAssertTrue(resultDiagnostics.isEmpty)
        
        // Verify indexing records
        let indexingRecordSort: (IndexingRecord, IndexingRecord) -> Bool = { return $0.title < $1.title }
        guard let resultIndexingRecords: [IndexingRecord] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("indexing-records.json")) else {
            XCTFail("Can't find indexing-records.json in output")
            return
        }
        XCTAssertEqual(resultIndexingRecords.sorted(by: indexingRecordSort), indexingRecords.sorted(by: indexingRecordSort))

        // Verify linkable entities
        let linkableEntitiesSort: (LinkDestinationSummary, LinkDestinationSummary) -> Bool = { return $0.referenceURL.absoluteString < $1.referenceURL.absoluteString }
        guard let resultLikableEntities: [LinkDestinationSummary] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("linkable-entities.json")) else {
            XCTFail("Can't find linkable-entities.json in output")
            return
        }
        XCTAssertEqual(resultLikableEntities.count, linkableEntities.count)
        for (resultEntity, entity) in zip(resultLikableEntities.sorted(by: linkableEntitiesSort), linkableEntities.sorted(by: linkableEntitiesSort)) {
            XCTAssertEqual(resultEntity, entity)
        }
        
        // Verify images
        guard let resultAssets: Digest.Assets = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("assets.json")) else {
            XCTFail("Can't find assets.json in output")
            return
        }
        XCTAssertEqual(resultAssets.images.map({ $0.identifier.identifier }).sorted(), images.map({ $0.identifier.identifier }).sorted())
    }

    func testLinkableEntitiesMetadataIncludesOverloads() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let bundle = try Folder.createFromDisk(
            url: Bundle.module.url(
                forResource: "OverloadedSymbols",
                withExtension: "docc",
                subdirectory: "Test Bundles")!
        )

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        let result = try action.perform(logHandle: .none)

        guard let resultLikableEntities: [LinkDestinationSummary] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("linkable-entities.json")) else {
            XCTFail("Can't find linkable-entities.json in output")
            return
        }

        // Rather than comparing all the linkable entities in the file, pull out one overload group
        // and check its task groups
        let overloadGroupEntity = try XCTUnwrap(resultLikableEntities.first(where: { $0.usr == "s:8ShapeKit18OverloadedProtocolP20fourthTestMemberName4testSdSS_tF::OverloadGroup" }))

        let taskGroups = try XCTUnwrap(overloadGroupEntity.taskGroups)
        guard taskGroups.count == 1, let overloadTaskGroup = taskGroups.first else {
            XCTFail("Expected one task group, found \(taskGroups.count): \(taskGroups.map(\.title?.singleQuoted))")
            return
        }

        XCTAssertEqual(overloadTaskGroup.title, "Overloads")
        XCTAssertEqual(Set(overloadTaskGroup.identifiers), [
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-91hxs",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-961zx",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-8iuz7",
            "doc://com.shapes.ShapeKit/documentation/ShapeKit/OverloadedProtocol/fourthTestMemberName(test:)-1h173",
        ])
    }

    func testDownloadMetadataIsWrittenToOutputFolder() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: projectZipFile),
            CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),

            TextFile(name: "MyTechnology.tutorial", utf8Content: """
            @Tutorial(time: 10, projectFiles: project.zip) {
              @Intro(title: "TechologyX") {}

              @Section(title: "Section") {
                @Steps {}
              }

              @Assessments {
                @MultipleChoice {
                  text
                  @Choice(isCorrect: true) {
                    text
                    @Justification(reaction: "reaction text") {}
                  }

                  @Choice(isCorrect: false) {
                    text
                    @Justification(reaction: "reaction text") {}
                  }
                }
              }
            }
            """),

            TextFile(name: "TechnologyX.tutorial", utf8Content: """
            @Tutorials(name: TechnologyX) {
               @Intro(title: "Technology X") {
                  Learn about some stuff in Technology X.
               }

               @Volume(name: "Volume 1") {
                  This volume contains Chapter 1.

                  @Image(source: referenced-tutorials-image.png, alt: "Some alt text")

                  @Chapter(name: "Chapter 1") {
                     In this chapter, you'll learn about Tutorial 1.

                     @Image(source: referenced-tutorials-image.png, alt: "Some alt text")
                     @TutorialReference(tutorial: "doc:MyTechnology")
                  }
               }
            }
            """),

            TextFile(name: "MySample.md", utf8Content: """
            # My Sample

            @Metadata {
                @CallToAction(url: "https://example.com/sample.zip", purpose: download)
            }

            This is a page with a download button.
            """),

            TextFile(name: "TestBundle.md", utf8Content: """
            # ``TestBundle``

            This is a test.

            ## Topics

            ### Pages

            - <doc:TechnologyX>
            - <doc:MySample>
            """),

            // A symbol graph
            CopyOfFile(original: Bundle.module.url(forResource: "TopLevelCuration.symbols", withExtension: "json", subdirectory: "Test Resources")!),

            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        let result = try action.perform(logHandle: .none)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        // Verify downloads
        guard let resultAssets: Digest.Assets = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("assets.json")) else {
            XCTFail("Can't find assets.json in output")
            return
        }
        XCTAssertEqual(resultAssets.downloads.count, 2)

        XCTAssert(resultAssets.downloads.contains(where: {
            $0.identifier.identifier == "project.zip"
        }))
        XCTAssert(resultAssets.downloads.contains(where: {
            $0.identifier.identifier == "https://example.com/sample.zip"
        }))
    }

    func testMetadataIsWrittenToOutputFolder() throws {
        // Example documentation bundle that contains an image
        let bundle = Folder(name: "unit-test.docc", content: [
            CopyOfFile(original: imageFile, newName: "referenced-article-image.png"),
            CopyOfFile(original: imageFile, newName: "referenced-tutorials-image.png"),
            CopyOfFile(original: imageFile, newName: "UNreferenced-image.png"),
            
            TextFile(name: "Article.tutorial", utf8Content: """
                @Article(time: 20) {
                   @Intro(title: "Making an Augmented Reality App") {
                      This is an abstract for the intro.
                   }
                   
                   ## Section Name
                   
                   ![full width image](referenced-article-image.png)
                }
                """
            ),
            TextFile(name: "TechnologyX.tutorial", utf8Content: """
                @Tutorials(name: TechnologyX) {
                   @Intro(title: "Technology X") {
                      Learn about some stuff in Technology X.
                   }
                   
                   @Volume(name: "Volume 1") {
                      This volume contains Chapter 1.

                      @Image(source: referenced-tutorials-image.png, alt: "Some alt text")

                      @Chapter(name: "Chapter 1") {
                         In this chapter, you'll learn about Tutorial 1.

                         @Image(source: referenced-tutorials-image.png, alt: "Some alt text")
                         @TutorialReference(tutorial: "doc:Article")
                      }
                   }

                }
                """
            ),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        func contentsOfJSONFile<Result: Decodable>(url: URL) -> Result? {
            guard let data = testDataProvider.contents(atPath: url.path) else {
                return nil
            }
            return try? JSONDecoder().decode(Result.self, from: data)
        }

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        let result = try action.perform(logHandle: .none)
        
        // Because the page order isn't deterministic, we create the indexing records and linkable entities in the same order as the pages.
        let indexingRecords: [IndexingRecord] = action.context.knownPages.compactMap { reference in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return IndexingRecord(
                    kind: .article,
                    location: .topLevelPage(reference),
                    title: "Making an Augmented Reality App",
                    summary: "This is an abstract for the intro.",
                    headings: ["Section Name"],
                    rawIndexableTextContent: "This is an abstract for the intro. Section Name "
                )
            case "/tutorials/TechnologyX":
                return IndexingRecord(
                    kind: .overview,
                    location: .topLevelPage(reference),
                    title: "Technology X",
                    summary: "Learn about some stuff in Technology X.",
                    headings: ["Volume 1"],
                    rawIndexableTextContent: "Learn about some stuff in Technology X. This volume contains Chapter 1."
                )
            case "/": return nil
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return nil
            }
        }
        let linkableEntities = action.context.knownPages.flatMap { (reference: ResolvedTopicReference) -> [LinkDestinationSummary] in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return [
                    LinkDestinationSummary(
                        kind: .tutorialArticle,
                        relativePresentationURL: URL(string: "/tutorials/testbundle/article")!,
                        referenceURL: reference.url,
                        title: "Making an Augmented Reality App",
                        language: .swift,
                        abstract: "This is an abstract for the intro.",
                        taskGroups: [.init(title: nil, identifiers: [reference.withFragment("Section-Name").absoluteString])],
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                    LinkDestinationSummary(
                        kind: .onPageLandmark,
                        relativePresentationURL: URL(string: "/tutorials/testbundle/article#Section-Name")!,
                        referenceURL: reference.withFragment("Section-Name").url,
                        title: "Section Name",
                        language: .swift,
                        abstract: nil,
                        taskGroups: [],
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                ]
            case "/tutorials/TechnologyX":
                return [
                    LinkDestinationSummary(
                        kind: .technology,
                        relativePresentationURL: URL(string: "/tutorials/technologyx")!,
                        referenceURL: reference.url,
                        title: "Technology X",
                        language: .swift,
                        abstract: "Learn about some stuff in Technology X.",
                        taskGroups: [.init(title: nil, identifiers: [reference.appendingPath("Volume-1").absoluteString])],
                        availableLanguages: [.swift],
                        platforms: nil,
                        topicImages: nil,
                        references: nil,
                        redirects: nil
                    ),
                ]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        let images: [ImageReference] = action.context.knownPages.flatMap {
            reference -> [ImageReference] in
            switch reference.path {
            case "/tutorials/TestBundle/Article":
                return [ImageReference(
                    name: "referenced-article-image.png",
                    altText: "full width image",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            case "/tutorials/TechnologyX":
                return [ImageReference(
                    name: "referenced-tutorials-image.png",
                    altText: "Some alt text",
                    userInterfaceStyle: .light,
                    displayScale: .standard
                )]
            default:
                XCTFail("Encountered unexpected page '\(reference)'")
                return []
            }
        }
        
        // Verify diagnostics
        guard let resultDiagnostics: [Digest.Diagnostic] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("diagnostics.json")) else {
            XCTFail("Can't find diagnostics.json in output")
            return
        }
        XCTAssertTrue(resultDiagnostics.isEmpty)
        
        // Verify indexing records
        let indexingRecordSort: (IndexingRecord, IndexingRecord) -> Bool = { return $0.title < $1.title }
        guard let resultIndexingRecords: [IndexingRecord] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("indexing-records.json")) else {
            XCTFail("Can't find indexing-records.json in output")
            return
        }
        XCTAssertEqual(resultIndexingRecords.sorted(by: indexingRecordSort), indexingRecords.sorted(by: indexingRecordSort))
        
        // Verify linkable entities
        let linkableEntitiesSort: (LinkDestinationSummary, LinkDestinationSummary) -> Bool = { return $0.referenceURL.absoluteString < $1.referenceURL.absoluteString }
        guard let resultLikableEntities: [LinkDestinationSummary] = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("linkable-entities.json")) else {
            XCTFail("Can't find linkable-entities.json in output")
            return
        }
        XCTAssertEqual(resultLikableEntities.sorted(by: linkableEntitiesSort), linkableEntities.sorted(by: linkableEntitiesSort))
        
        // Verify images
        guard let resultAssets: Digest.Assets = contentsOfJSONFile(url: result.outputs[0].appendingPathComponent("assets.json")) else {
            XCTFail("Can't find assets.json in output")
            return
        }
        XCTAssertEqual(resultAssets.images.map({ $0.identifier.identifier }).sorted(), images.map({ $0.identifier.identifier }).sorted())
    }
    
    func testMetadataIsOnlyWrittenToOutputFolderWhenEmitDigestFlagIsSet() throws {
        
        // An empty documentation bundle
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])

        // Check that they're all written when `--emit-digest` is set
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: true, // emit digest files
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
            )
            let result = try action.perform(logHandle: .none)
            
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("assets.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("diagnostics.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("indexing-records.json").path))
            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("linkable-entities.json").path))
        }
        
        // Check that they're not written when `--emit-digest` is not set
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false, // don't emit digest files
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
            )
            let result = try action.perform(logHandle: .none)
            
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("assets.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("diagnostics.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("indexing-records.json").path))
            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("linkable-entities.json").path))
        }
    }

    /// An empty implementation of `ConvertOutputConsumer` that purposefully does nothing except
    /// to pass the number of documentation coverage info structs received to the given handler
    struct TestDocumentationCoverageConsumer: ConvertOutputConsumer {

        let coverageConsumeHandler: (Int) -> Void

        init(coverageConsumeHandler: @escaping (Int) -> Void) {
            self.coverageConsumeHandler = coverageConsumeHandler
        }

        func consume(renderNode: RenderNode) throws { }
        func consume(problems: [Problem]) throws { }
        func consume(assetsInBundle bundle: DocumentationBundle) throws {}
        func consume(linkableElementSummaries: [LinkDestinationSummary]) throws {}
        func consume(indexingRecords: [IndexingRecord]) throws {}
        func consume(assets: [RenderReferenceType: [RenderReference]]) throws {}
        func consume(benchmarks: Benchmark) throws {}

        // Call the handler with the number of coverage items consumed here
        func consume(documentationCoverageInfo: [CoverageDataEntry]) throws {
            coverageConsumeHandler(documentationCoverageInfo.count)
        }
    }

    func testMetadataIsOnlyWrittenToOutputFolderWhenDocumentationCoverage() throws {

        // An empty documentation bundle, except for a single symbol graph file
        // containing 8 symbols.
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
        ])

        // Count the number of coverage info structs consumed by each test below,
        // using TestDocumentationCoverageConsumer and this handler.
        var coverageInfoCount = 0
        let coverageInfoHandler = { count in coverageInfoCount += count }

        // Check that they're nothing is written for `.noCoverage`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                documentationCoverageOptions: .noCoverage)
            let result = try action.perform(logHandle: .none)

            XCTAssertFalse(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))

            // Rerun the convert and test no coverage info structs were consumed
            let _ = try action.converter.convert(outputConsumer: TestDocumentationCoverageConsumer(coverageConsumeHandler: coverageInfoHandler))
            XCTAssertEqual(coverageInfoCount, 0)
        }

        // Check that JSON is written for `.brief`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                documentationCoverageOptions: DocumentationCoverageOptions(level: .brief))
            let result = try action.perform(logHandle: .none)

            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))

            // Rerun the convert and test one coverage info structs was consumed for each symbol page (8)
            coverageInfoCount = 0
            let _ = try action.converter.convert(outputConsumer: TestDocumentationCoverageConsumer(coverageConsumeHandler: coverageInfoHandler))
            XCTAssertEqual(coverageInfoCount, 8)
        }

        // Check that JSON is written for `.detailed`
        do {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                documentationCoverageOptions: DocumentationCoverageOptions(level: .detailed))
            let result = try action.perform(logHandle: .none)

            XCTAssertTrue(testDataProvider.fileExists(atPath: result.outputs[0].appendingPathComponent("documentation-coverage.json").path))

            // Rerun the convert and test one coverage info structs was consumed for each symbol page (8)
            coverageInfoCount = 0
            let _ = try action.converter.convert(outputConsumer: TestDocumentationCoverageConsumer(coverageConsumeHandler: coverageInfoHandler))
            XCTAssertEqual(coverageInfoCount, 8)
        }
    }
    
    /// Test context gets the current platforms provided by command line.
    func testRelaysCurrentPlatformsToContext() throws {
        // Empty documentation bundle that's nested inside some other directories.
        let bundle = Folder(name: "nested", content: [
            Folder(name: "folders", content: [
                Folder(name: "unit-test.docc", content: [
                    InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                ]),
            ])
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        let action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: [
                "platform1": PlatformVersion(.init(10, 11, 12), beta: false),
                "platform2": PlatformVersion(.init(11, 12, 13), beta: false),
            ],
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "platform1" : PlatformVersion(.init(10, 11, 12), beta: false),
            "platform2" : PlatformVersion(.init(11, 12, 13), beta: false),
        ])
    }
    
    func testBetaInAvailabilityFallbackPlatforms() throws {
        
        func generateConvertAction(currentPlatforms: [String : PlatformVersion]) throws -> ConvertAction {
            try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: currentPlatforms,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
            )
        }
        let bundle = Folder(name: "nested", content: [
            Folder(name: "folders", content: [
                Folder(name: "unit-test.docc", content: [
                    InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                ]),
            ])
        ])
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        // Test whether the missing platforms copy the availability information from the fallback platform.
        var action = try generateConvertAction(currentPlatforms: ["iOS": PlatformVersion(.init(10, 0, 0), beta: true)])
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "iOS" : PlatformVersion(.init(10, 0, 0), beta: true),
            "Mac Catalyst" : PlatformVersion(.init(10, 0, 0), beta: true),
            "iPadOS" : PlatformVersion(.init(10, 0, 0), beta: true),
        ])
        // Test whether the non-missing platforms don't copy the availability information from the fallback platform.
        action = try generateConvertAction(currentPlatforms: [
            "iOS": PlatformVersion(.init(10, 0, 0), beta: true),
            "Mac Catalyst": PlatformVersion(.init(11, 0, 0), beta: false)
        ])
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "iOS" : PlatformVersion(.init(10, 0, 0), beta: true),
            "Mac Catalyst" : PlatformVersion(.init(11, 0, 0), beta: false),
            "iPadOS" : PlatformVersion(.init(10, 0, 0), beta: true)
        ])
        action = try generateConvertAction(currentPlatforms: [
            "iOS": PlatformVersion(.init(10, 0, 0), beta: true),
            "Mac Catalyst" : PlatformVersion(.init(11, 0, 0), beta: true),
            "iPadOS": PlatformVersion(.init(12, 0, 0), beta: false),
            
        ])
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "iOS" : PlatformVersion(.init(10, 0, 0), beta: true),
            "Mac Catalyst" : PlatformVersion(.init(11, 0, 0), beta: true),
            "iPadOS" : PlatformVersion(.init(12, 0, 0), beta: false),
        ])
        // Test whether the non-missing platforms don't copy the availability information from the non-fallback platform.
        action = try generateConvertAction(currentPlatforms: [
            "tvOS": PlatformVersion(.init(13, 0, 0), beta: true)
            
        ])
        XCTAssertEqual(action.context.externalMetadata.currentPlatforms, [
            "tvOS": PlatformVersion(.init(13, 0, 0), beta: true)
        ])
    }
    
    func testResolvedTopicReferencesAreCachedByDefaultWhenConverting() throws {
        let bundle = Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(displayName: "TestBundle", identifier: #function),
                CopyOfFile(original: symbolGraphFile),
            ]
        )
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: [:],
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        
        _ = try action.perform(logHandle: .none)
        
        XCTAssertEqual(ResolvedTopicReference._numberOfCachedReferences(bundleID: #function), 8)
    }

    func testIgnoresAnalyzerHintsByDefault() throws {
        func runCompiler(analyze: Bool) throws -> [Problem] {
            // This bundle has both non-analyze and analyze style warnings.
            let testBundleURL = Bundle.module.url(
                forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            let bundle = try Folder.createFromDisk(url: testBundleURL)

            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
            let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
                .appendingPathComponent("target", isDirectory: true)

            let engine = DiagnosticEngine()
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: analyze, // Turn on/off the analyzer.
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                diagnosticEngine: engine)
            let result = try action.perform(logHandle: .none)
            XCTAssertFalse(result.didEncounterError)
            return engine.problems
        }

        let analyzeDiagnostics = try runCompiler(analyze: true)
        let noAnalyzeDiagnostics = try runCompiler(analyze: false)
        
        XCTAssertTrue(analyzeDiagnostics.contains { $0.diagnostic.severity == .information })
        XCTAssertFalse(noAnalyzeDiagnostics.contains { $0.diagnostic.severity == .information })

        XCTAssertTrue(
            analyzeDiagnostics.count > noAnalyzeDiagnostics.count,
            """
                The number of diagnostics with '--analyze' should be more than without '--analyze' \
                (\(analyzeDiagnostics.count) vs \(noAnalyzeDiagnostics.count))
                """
        )
    }
    
    /// Verify that the conversion of the same input given high concurrency and no concurrency,
    /// and also with and without generating digest produces the same results
    func testConvertTestBundleWithHighConcurrency() throws {
        let testBundleURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let bundle = try Folder.createFromDisk(url: testBundleURL)

        struct TestReferenceResolver: ExternalDocumentationSource {
            func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
                return .success(ResolvedTopicReference(bundleIdentifier: "com.example.test", path: reference.url!.path, sourceLanguage: .swift))
            }

            func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
                fatalError("This test never asks for the external entity.")
            }
        }
        
        func convertTestBundle(batchSize: Int, emitDigest: Bool, targetURL: URL, testDataProvider: DocumentationWorkspaceDataProvider & FileManagerProtocol) throws -> ActionResult {
            // Run the create ConvertAction
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetURL,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: emitDigest,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
            )
            
            action.converter.batchNodeCount = batchSize
            
            action.context.externalDocumentationSources["com.example.test"] = TestReferenceResolver()
            
            return try action.perform(logHandle: .none)
        }

        for withDigest in [false, true] {
            let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])

            // Set a batch size to a high number to have no concurrency
            let serialOutputURL = URL(string: "/serialOutput")!
            let serialResult = try convertTestBundle(batchSize: 10_000, emitDigest: withDigest, targetURL: serialOutputURL, testDataProvider: testDataProvider)

            // Set a batch size to 1 to have maximum concurrency (this is bad for performance maximizes our chances of encountering an issue).
            let parallelOutputURL = URL(string: "/parallelOutput")!
            let parallelResult = try convertTestBundle(batchSize: 1, emitDigest: withDigest, targetURL: parallelOutputURL, testDataProvider: testDataProvider)
            
            // Compare the results
            XCTAssertEqual(
                uniformlyPrintDiagnosticMessages(serialResult.problems),
                uniformlyPrintDiagnosticMessages(parallelResult.problems)
            )
            
            XCTAssertEqual(parallelResult.outputs.count, 1)
            XCTAssertEqual(serialResult.outputs.count, 1)
            
            guard let serialOutput = serialResult.outputs.first, let parallelOutput = parallelResult.outputs.first else {
                XCTFail("Missing output to compare")
                return
            }
            
            let serialContent = testDataProvider.files.keys.filter({ $0.hasPrefix(serialOutput.path) })
            let parallelContent = testDataProvider.files.keys.filter({ $0.hasPrefix(parallelOutput.path) })

            XCTAssertFalse(serialContent.isEmpty)
            XCTAssertEqual(serialContent.count, parallelContent.count)
            
            let relativePathsSerialContent = serialContent.map({ $0.replacingOccurrences(of: serialOutput.path, with: "") })
            let relativePathsParallelContent = parallelContent.map({ $0.replacingOccurrences(of: parallelOutput.path, with: "") })

            XCTAssertEqual(relativePathsSerialContent.sorted(), relativePathsParallelContent.sorted())
        }
    }
    
    func testConvertActionProducesDeterministicOutput() throws {
        // Pretty printing the output JSON also enables sorting keys during encoding
        // which is required for testing if the conversion output is deterministic.
        let priorPrettyPrintValue = shouldPrettyPrintOutputJSON
        shouldPrettyPrintOutputJSON = true
        defer {
            // Because this value is being modified in-process (not in the environment)
            // it will not affect the outcome of other tests, even when running tests in parallel.
            // Even when tests are run in parallel,
            // there is only one test being executed per process at a time.
            shouldPrettyPrintOutputJSON = priorPrettyPrintValue
        }
        
        let testBundleURL = try XCTUnwrap(
            Bundle.module.url(
                forResource: "TestBundle",
                withExtension: "docc",
                subdirectory: "Test Bundles"
            )
        )
        let bundle = try Folder.createFromDisk(url: testBundleURL)
        
        func performConvertAction(outputURL: URL, testFileSystem: TestFileSystem) throws {
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: outputURL,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testFileSystem,
                fileManager: testFileSystem,
                temporaryDirectory: testFileSystem.uniqueTemporaryDirectory()
            )
            action.diagnosticEngine.consumers.sync { $0.removeAll() } 
            
            _ = try action.perform(logHandle: .none)
        }
        
        // We'll perform 3 sets of conversions to confirm the output is deterministic
        for _ in 1...3 {
            let testFileSystem = try TestFileSystem(
                folders: [bundle, Folder.emptyHTMLTemplateDirectory]
            )
            
            // Convert the same bundle three times and place the output in
            // separate directories.
            
            try performConvertAction(
                outputURL: URL(fileURLWithPath: "/1", isDirectory: true),
                testFileSystem: testFileSystem
            )
            try performConvertAction(
                outputURL: URL(fileURLWithPath: "/2", isDirectory: true),
                testFileSystem: testFileSystem
            )
            
            // Extract and sort the RenderJSON output of each conversion
            
            let firstConversionFiles = testFileSystem.files.lazy.filter { key, _ in
                key.hasPrefix("/1/data/")
            }.map { (key, value) in
                return (String(key.dropFirst("/1".count)), value)
            }.sorted(by: \.0)
            
            let secondConversionFiles = testFileSystem.files.lazy.filter { key, _ in
                key.hasPrefix("/2/data/")
            }.map { (key, value) in
                return (String(key.dropFirst("/2".count)), value)
            }.sorted(by: \.0)
            
            // Zip the two sets of sorted files and loop through them, ensuring that
            // each conversion produced the same RenderJSON output.
            
            XCTAssertEqual(
                firstConversionFiles.map(\.0),
                secondConversionFiles.map(\.0),
                "The produced file paths are nondeterministic."
            )
            
            for (first, second) in zip(firstConversionFiles, secondConversionFiles) {
                let firstString = String(data: first.1, encoding: .utf8)
                let secondString = String(data: second.1, encoding: .utf8)
                
                XCTAssertEqual(firstString, secondString, "The contents of '\(first.0)' is nondeterministic.")
            }
        }
    }
    
    func testConvertActionNavigatorIndexGeneration() throws {
        // The navigator index needs to test with the real file manager
        let bundleURL = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        let targetURL = try createTemporaryDirectory()
        let templateURL = try createTemporaryDirectory().appendingPathComponent("template")
        try Folder.emptyHTMLTemplateDirectory.write(to: templateURL)
        
        // Convert the documentation and create an index
        
        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true,
            temporaryDirectory: createTemporaryDirectory() // Create an index
        )
        _ = try action.perform(logHandle: .none)
        
        let indexURL = targetURL.appendingPathComponent("index")
        
        let indexFromConvertAction = try NavigatorIndex.readNavigatorIndex(url: indexURL)
        XCTAssertEqual(indexFromConvertAction.count, 37)
        
        indexFromConvertAction.environment?.close()
        try FileManager.default.removeItem(at: indexURL)
        
        // Run just the index command over the built documentation
        
        var indexAction = try IndexAction(
            documentationBundleURL: targetURL,
            outputURL: indexURL,
            bundleIdentifier: indexFromConvertAction.bundleIdentifier
        )
        _ = try indexAction.perform(logHandle: .none)
        
        let indexFromIndexAction = try NavigatorIndex.readNavigatorIndex(url: indexURL)
        XCTAssertEqual(indexFromIndexAction.count, 37)
        
        XCTAssertEqual(
            indexFromConvertAction.navigatorTree.root.dumpTree(),
            indexFromIndexAction.navigatorTree.root.dumpTree()
        )
    }
    
    func testObjectiveCNavigatorIndexGeneration() throws {
        let bundle = Folder(name: "unit-test-objc.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: objectiveCSymbolGraphFile),
        ])
        
        // The navigator index needs to test with the real File Manager
        let testTemporaryDirectory = try createTemporaryDirectory()
        
        let bundleDirectory = testTemporaryDirectory.appendingPathComponent(
            bundle.name,
            isDirectory: true
        )
        try bundle.write(to: bundleDirectory)
        
        let targetDirectory = testTemporaryDirectory.appendingPathComponent(
            "output",
            isDirectory: true
        )
        
        var action = try ConvertAction(
            documentationBundleURL: bundleDirectory,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true,
            temporaryDirectory: createTemporaryDirectory()
        )
        
        _ = try action.perform(logHandle: .none)
        
        let index = try NavigatorIndex.readNavigatorIndex(url: targetDirectory.appendingPathComponent("index"))
        func assertAllChildrenAreObjectiveC(_ node: NavigatorTree.Node) {
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.objc.mask,
                """
                Node from Objective-C symbol graph did not have Objective-C language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            for childNode in node.children {
                assertAllChildrenAreObjectiveC(childNode)
            }
        }
        
        XCTAssertEqual(
            index.navigatorTree.root.children.count, 1,
            "The root of the navigator tree unexpectedly contained more than one child."
        )
        
        let firstChild = try XCTUnwrap(index.navigatorTree.root.children.first)
        assertAllChildrenAreObjectiveC(firstChild)
    }
    
    func testMixedLanguageNavigatorIndexGeneration() throws {
        // The navigator index needs to test with the real File Manager
        let temporaryTestOutputDirectory = try createTemporaryDirectory()
        
        let bundleDirectory = try XCTUnwrap(
            Bundle.module.url(
                forResource: "MixedLanguageFramework",
                withExtension: "docc",
                subdirectory: "Test Bundles"
            ),
            "Unexpectedly failed to find 'MixedLanguageFramework.docc' test bundle."
        )
        
        var action = try ConvertAction(
            documentationBundleURL: bundleDirectory,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: temporaryTestOutputDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            buildIndex: true,
            temporaryDirectory: createTemporaryDirectory()
        )
        
        _ = try action.perform(logHandle: .none)
        
        let index = try NavigatorIndex.readNavigatorIndex(
            url: temporaryTestOutputDirectory.appendingPathComponent("index")
        )
        
        func assertForAllChildren(
            _ node: NavigatorTree.Node,
            assert: (_ node: NavigatorTree.Node) -> ()
        ) {
            assert(node)
            
            for childNode in node.children {
                assertForAllChildren(childNode, assert: assert)
            }
        }
        
        XCTAssertEqual(
            index.navigatorTree.root.children.count, 2,
            "The root of the navigator tree should contain '2' children, one for each language"
        )
        
        let swiftRootNode = try XCTUnwrap(
            index.navigatorTree.root.children.first { node in
                return node.item.languageID == InterfaceLanguage.swift.mask
            },
            "The navigator tree should contain a Swift item at the root."
        )
        
        let objectiveCRootNode = try XCTUnwrap(
            index.navigatorTree.root.children.first { node in
                return node.item.languageID == InterfaceLanguage.objc.mask
            },
            "The navigator tree should contain an Objective-C item at the root."
        )
        
        var swiftNavigatorEntries = [String]()
        assertForAllChildren(swiftRootNode) { node in
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.swift.mask,
                """
                Node from Swift root node did not have Swift language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            swiftNavigatorEntries.append(node.item.title)
        }
        
        let expectedSwiftNavigatorEntires = [
            "Swift",
            "MixedLanguageFramework",
            "Classes",
            "Bar",
            "Type Methods",
            "class func myStringFunction(String) throws -> String",
            "Structures",
            "Foo",
            "Initializers",
            "init(rawValue: UInt)",
            "Type Properties",
            "static var first: Foo",
            "static var fourth: Foo",
            "static var second: Foo",
            "static var third: Foo",
            "SwiftOnlyStruct",
            "Instance Methods",
            "func tada()",
        ]
        
        XCTAssertEqual(
            swiftNavigatorEntries,
            expectedSwiftNavigatorEntires,
            "Swift navigator contained unexpected content."
        )
        
        var objectiveCNavigatorEntries = [String]()
        assertForAllChildren(objectiveCRootNode) { node in
            XCTAssertEqual(
                node.item.languageID,
                InterfaceLanguage.objc.mask,
                """
                Node from Objective-C symbol graph did not have Objective-C language ID: \
                '\(node.item.usrIdentifier ?? node.item.title)'"
                """
            )
            
            objectiveCNavigatorEntries.append(node.item.title)
        }
        
        let expectedObjectiveNavigatorEntries = [
            "Objective-C",
            "MixedLanguageFramework",
            "Classes",
            "Bar",
            "Type Methods",
            "myStringFunction:error: (navigator title)",
            "Custom",
            "Foo",
            "Variables",
            "_MixedLanguageFrameworkVersionNumber",
            "_MixedLanguageFrameworkVersionString",
            "Enumerations",
            "Foo",
            "Enumeration Cases",
            "first",
            "fourth",
            "second",
            "third",
        ]
        
        XCTAssertEqual(
            objectiveCNavigatorEntries,
            expectedObjectiveNavigatorEntries,
            "Objective-C navigator contained unexpected content."
        )
    }
    
    func testDiagnosticLevel() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        let engine = DiagnosticEngine()
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "error",
            diagnosticEngine: engine
        )
        let result = try action.perform(logHandle: .none)

        XCTAssertEqual(engine.problems.count, 0, "\(ConvertAction.self) didn't filter out diagnostics at-or-above the 'error' level.")
        XCTAssertFalse(result.didEncounterError, "The issues with this test bundle are not severe enough to fail the build.")
    }

    func testDiagnosticLevelIgnoredWhenAnalyzeIsPresent() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        let engine = DiagnosticEngine()
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: true,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "error",
            diagnosticEngine: engine
        )
        let result = try action.perform(logHandle: .none)

        XCTAssertEqual(engine.problems.count, 1, "\(ConvertAction.self) shouldn't filter out diagnostics when the '--analyze' flag is passed")
        XCTAssertEqual(engine.problems.map { $0.diagnostic.identifier }, ["org.swift.docc.Article.Title.NotFound"])
        XCTAssertFalse(result.didEncounterError, "The issues with this test bundle are not severe enough to fail the build.")
        XCTAssert(engine.problems.contains(where: { $0.diagnostic.severity == .warning }))
    }

    func testDoesNotIncludeDiagnosticsInThrownError() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: true,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "error"
        )
        XCTAssertNoThrow(try action.performAndHandleResult(logHandle: .none))
    }
    
    func testWritesDiagnosticFileWhenThrowingError() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        // TODO: Support TestFileSystem in DiagnosticFileWriter
        let diagnosticFile = try createTemporaryDirectory().appendingPathComponent("test-diagnostics.json")
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: true,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticLevel: "error",
            diagnosticFilePath: diagnosticFile
        )
        
        // TODO: Support TestFileSystem in DiagnosticFileWriter
        XCTAssertFalse(FileManager.default.fileExists(atPath: diagnosticFile.path), "Diagnostic file doesn't exist before")
        XCTAssertNoThrow(try action.performAndHandleResult(logHandle: .none))
        XCTAssertTrue(FileManager.default.fileExists(atPath: diagnosticFile.path), "Diagnostic file exist after")
    }

    // Verifies setting convert inherit docs flag
    func testConvertInheritDocsOption() throws {
        // Empty documentation bundle
        let bundle = Folder(name: "unit-test.documentation", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
        ])
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        // Verify setting the flag explicitly
        for flag in [false, true] {
            let action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                inheritDocs: flag)
            XCTAssertEqual(action.context.externalMetadata.inheritDocs, flag)
        }
        
        // Verify implicit value
        let action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory())
        XCTAssertEqual(action.context.externalMetadata.inheritDocs, false)
    }
    
    func testEmitsDigest() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath).appendingPathComponent("target", isDirectory: true)

        let digestFileURL = targetDirectory
            .appendingPathComponent("diagnostics.json")
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: true,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        
        XCTAssertNoThrow(try action.performAndHandleResult(logHandle: .none))
        XCTAssert(testDataProvider.fileExists(atPath: digestFileURL.path))
        
        let data = try testDataProvider.contentsOfURL(digestFileURL)
        let diagnostics = try RenderJSONDecoder.makeDecoder().decode([Digest.Diagnostic].self, from: data)
        XCTAssertEqual(diagnostics.count, 0)
    }
    
    func testRenderIndexJSONGeneration() throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
        ])

        let temporaryDirectory = try createTemporaryDirectory()
        let catalogURL = try catalog.write(inside: temporaryDirectory)
        
        let targetDirectory = temporaryDirectory.appendingPathComponent("target", isDirectory: true)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: catalogURL)
        
        var action = try ConvertAction(
            documentationBundleURL: catalog.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: nil,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            temporaryDirectory: createTemporaryDirectory()
        )
        
        try action.performAndHandleResult(logHandle: .none)
        
        let indexDirectory = targetDirectory.appendingPathComponent("index", isDirectory: true)
        let renderIndexJSON = indexDirectory.appendingPathComponent("index.json", isDirectory: false)
        
        try action.performAndHandleResult(logHandle: .none)
        XCTAssertTrue(FileManager.default.directoryExists(atPath: indexDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: renderIndexJSON.path))
        try XCTAssertEqual(FileManager.default.contentsOfDirectory(at: indexDirectory, includingPropertiesForKeys: nil).count, 1)
    }
    
    /// Verifies that a metadata.json file is created in the output folder with additional metadata.
    func testCreatesBuildMetadataFileForBundleWithInfoPlistValues() throws {
        let bundle = Folder(
            name: "unit-test.docc",
            content: [InfoPlist(displayName: "TestBundle", identifier: "com.test.example")]
        )
        
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory()
        )
        let result = try action.perform(logHandle: .none)
        
        let expectedOutput = Folder(name: ".docc-build", content: [
            JSONFile(
                name: "metadata.json",
                content: BuildMetadata(bundleDisplayName: "TestBundle", bundleIdentifier: "com.test.example")
            ),
        ])
        
        expectedOutput.assertExist(at: result.outputs[0], fileManager: testDataProvider)
    }
    
    // Tests that the default behavior of `docc convert` on the command-line does not throw an error
    // when processing a DocC catalog that does not actually produce documentation. (r91790147)
    func testConvertDocCCatalogThatProducesNoDocumentationDoesNotThrowError() throws {
        let emptyCatalog = Folder(
            name: "unit-test.docc",
            content: [InfoPlist(displayName: "TestBundle", identifier: "com.test.example")]
        )
        
        let temporaryDirectory = try createTemporaryDirectory()
        let outputDirectory = temporaryDirectory.appendingPathComponent("output", isDirectory: true)
        let doccCatalogDirectory = try emptyCatalog.write(inside: temporaryDirectory)
        let htmlTemplateDirectory = try Folder.emptyHTMLTemplateDirectory.write(inside: temporaryDirectory)
        
        SetEnvironmentVariable(TemplateOption.environmentVariableKey, htmlTemplateDirectory.path)
        defer {
            UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
        }
        
        let convertCommand = try Docc.Convert.parse(
            [
                doccCatalogDirectory.path,
                "--output-path", outputDirectory.path,
            ]
        )
        
        var action = try ConvertAction(fromConvertCommand: convertCommand)
        _ = try action.perform(logHandle: .none)
    }
    
    func emitEmptySymbolGraph(moduleName: String, destination: URL) throws {
        let symbolGraph = SymbolGraph(
            metadata: .init(
                formatVersion: .init(major: 0, minor: 0, patch: 1),
                generator: "unit-test"
            ),
            module: .init(
                name: moduleName,
                platform: .init()
            ),
            symbols: [],
            relationships: []
        )
        
        // Create a unique subfolder to place the symbol graph in
        // in case we're emitting multiple symbol graphs with the same filename.
        let uniqueSubfolder = destination.appendingPathComponent(
            ProcessInfo.processInfo.globallyUniqueString
        )
        try FileManager.default.createDirectory(
            at: uniqueSubfolder,
            withIntermediateDirectories: false
        )
        
        try JSONEncoder().encode(symbolGraph).write(
            to: uniqueSubfolder
                .appendingPathComponent(moduleName, isDirectory: false)
                .appendingPathExtension("symbols.json")
        )
    }

    // Tests that when `docc convert` is given input that produces multiple pages at the same path
    // on disk it does not throw an error when attempting to transform it for static hosting. (94311195)
    func testConvertDocCCatalogThatProducesMultipleDocumentationPagesAtTheSamePathDoesNotThrowError() throws {
        let temporaryDirectory = try createTemporaryDirectory()
        
        let catalogURL = try Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ]
        ).write(inside: temporaryDirectory)
        try emitEmptySymbolGraph(moduleName: "docc", destination: catalogURL)
        try emitEmptySymbolGraph(moduleName: "DocC", destination: catalogURL)
        
        let htmlTemplateDirectory = try Folder.emptyHTMLTemplateDirectory.write(
            inside: temporaryDirectory
        )
        
        let targetDirectory = temporaryDirectory.appendingPathComponent("target.doccarchive", isDirectory: true)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: catalogURL)
        
        var action = try ConvertAction(
            documentationBundleURL: catalogURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: htmlTemplateDirectory,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            temporaryDirectory: createTemporaryDirectory(),
            transformForStaticHosting: true
        )
        
        XCTAssertNoThrow(try action.performAndHandleResult(logHandle: .none))
    }
    func testConvertWithCustomTemplates() throws {
        let info = InfoPlist(displayName: "TestConvertWithCustomTemplates", identifier: "com.test.example")
        let index = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><p>hello</p></body>
        </html>
        """)
        let template = Folder(name: "template", content: [index])
        let header = TextFile(name: "header.html", utf8Content: """
        <style>
            header { background-color: rebeccapurple; }
        </style>
        <header>custom header</header>
        """)
        let footer = TextFile(name: "footer.html", utf8Content: """
        <style>
            footer { background-color: #fff; }
        </style>
        <footer>custom footer</footer>
        """)
        let bundle = Folder(name: "TestConvertWithCustomTemplates.docc", content: [
            info,
            header,
            footer,
        ])

        let tempURL = try createTemporaryDirectory()
        let targetURL = tempURL.appendingPathComponent("target", isDirectory: true)

        let bundleURL = try bundle.write(inside: tempURL)
        let templateURL = try template.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)

        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            temporaryDirectory: createTemporaryDirectory(),
            experimentalEnableCustomTemplates: true
        )
        let result = try action.perform(logHandle: .none)

        // The custom template contents should be wrapped in <template> tags and
        // prepended to the <body>
        let expectedIndex = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><template id="custom-footer">\(footer.utf8Content)</template><template id="custom-header">\(header.utf8Content)</template><p>hello</p></body>
        </html>
        """)
        let expectedOutput = Folder(name: ".docc-build", content: [expectedIndex])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: FileManager.default)
    }

    // Tests that custom templates are injected into the extra index.html files generated for static hosting.
    func testConvertWithCustomTemplatesForStaticHosting() throws {
        let info = InfoPlist(displayName: "TestConvertWithCustomTemplatesForStaticHosting", identifier: "com.test.example")
        let index = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><p>test for custom templates in static hosting</p></body>
        </html>
        """)
        let template = Folder(name: "template", content: [index])
        let header = TextFile(name: "header.html", utf8Content: """
        <header>custom text for header</header>
        """)
        let footer = TextFile(name: "footer.html", utf8Content: """
        <footer>custom text for footer</footer>
        """)

        // Adding this page will generate a file named:
        // /documentation/testconvertwithcustomtemplatesforstatichosting/index.html
        // ...which should have the custom header/footer if they're propagated correctly.
        let technologyPage = TextFile(name: "TestConvertWithCustomTemplatesForStaticHosting.md", utf8Content: """
        # TestConvertWithCustomTemplatesForStaticHosting

        @Metadata {
            @TechnologyRoot
        }

        An abstract.

        ## Overview

        Text for a paragraph.
        """)
        let bundle = Folder(name: "TestConvertWithCustomTemplatesForStaticHosting.docc", content: [
            info,
            header,
            footer,
            technologyPage
        ])

        let tempURL = try createTemporaryDirectory()
        let targetURL = tempURL.appendingPathComponent("target", isDirectory: true)

        let bundleURL = try bundle.write(inside: tempURL)
        let templateURL = try template.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)

        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            temporaryDirectory: createTemporaryDirectory(),
            experimentalEnableCustomTemplates: true,
            transformForStaticHosting: true
        )
        let result = try action.perform(logHandle: .none)

        // The custom template contents should be wrapped in <template> tags and
        // prepended to the <body>
        let expectedIndex = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><template id="custom-footer">\(footer.utf8Content)</template><template id="custom-header">\(header.utf8Content)</template><p>test for custom templates in static hosting</p></body>
        </html>
        """)
        
        let expectedTechnologyFolder = Folder(name: "TestConvertWithCustomTemplatesForStaticHosting".lowercased(), content: [expectedIndex])
        let expectedDocsFolder = Folder(name: "documentation", content: [expectedTechnologyFolder])
        let expectedOutput = Folder(name: ".docc-build", content: [expectedDocsFolder])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: FileManager.default)
    }

    func testConvertWithThemeSettings() throws {
        let info = InfoPlist(displayName: "TestConvertWithThemeSettings", identifier: "com.test.example")
        let index = TextFile(name: "index.html", utf8Content: """
        <!DOCTYPE html>
        <html lang="en">
            <head>
                <title>Test</title>
            </head>
            <body data-color-scheme="auto"><p>hello</p></body>
        </html>
        """)
        let themeSettings = TextFile(name: "theme-settings.json", utf8Content: """
        {
          "meta": {},
          "theme": {
            "colors": {
              "text": "#ff0000"
            }
          },
          "features": {}
        }
        """)
        let template = Folder(name: "template", content: [index])
        let bundle = Folder(name: "TestConvertWithThemeSettings.docc", content: [
            info,
            themeSettings,
        ])

        let tempURL = try createTemporaryDirectory()
        let targetURL = tempURL.appendingPathComponent("target", isDirectory: true)

        let bundleURL = try bundle.write(inside: tempURL)
        let templateURL = try template.write(inside: tempURL)

        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)

        var action = try ConvertAction(
            documentationBundleURL: bundleURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: templateURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: dataProvider,
            fileManager: FileManager.default,
            temporaryDirectory: createTemporaryDirectory(),
            experimentalEnableCustomTemplates: true
        )
        let result = try action.perform(logHandle: .none)

        let expectedOutput = Folder(name: ".docc-build", content: [
            index,
            themeSettings,
        ])
        expectedOutput.assertExist(at: result.outputs[0], fileManager: FileManager.default)
    }
    
    func testTreatWarningsAsErrors() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            CopyOfFile(original: symbolGraphFile, newName: "MyKit.symbols.json"),
            TextFile(name: "Article.md", utf8Content: """
            Bad title

            This article has a malformed title and can't be analyzed, so it
            produces one warning.
            """),
        ])

        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath)
            .appendingPathComponent("target", isDirectory: true)

        // Test DiagnosticEngine with "treatWarningsAsErrors" set to false
        do {
            let engine = DiagnosticEngine(treatWarningsAsErrors: false)
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: true,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                diagnosticEngine: engine
            )
            let result = try action.perform(logHandle: .none)
            XCTAssertEqual(engine.problems.count, 1)
            XCTAssertTrue(engine.problems.contains(where: { $0.diagnostic.severity == .warning }))
            XCTAssertFalse(result.didEncounterError)
        }
        
        // Test DiagnosticEngine with "treatWarningsAsErrors" set to true
        do {
            let engine = DiagnosticEngine(treatWarningsAsErrors: true)
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: true,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                diagnosticEngine: engine
            )
            let result = try action.perform(logHandle: .none)
            XCTAssertEqual(engine.problems.count, 1)
            XCTAssertTrue(result.didEncounterError)
        }
        
        do {
            var action = try ConvertAction(
                documentationBundleURL: bundle.absoluteURL,
                outOfProcessResolver: nil,
                analyze: true,
                targetDirectory: targetDirectory,
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
                diagnosticEngine: nil,
                treatWarningsAsErrors: true
            )
            let result = try action.perform(logHandle: .none)
            XCTAssertTrue(result.didEncounterError)
        }

    }

    func testConvertWithoutBundleDerivesDisplayNameAndIdentifierFromSingleModuleSymbolGraph() throws {
        let myKitSymbolGraph = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
        
        XCTAssert(FileManager.default.fileExists(atPath: myKitSymbolGraph.path))
        let symbolGraphFiles = Folder(name: "Not-a-doc-bundle", content: [
            CopyOfFile(original: myKitSymbolGraph, newName: "MyKit.symbols.json"),
        ])
        
        let outputLocation = Folder(name: "output", content: [])
        
        let testDataProvider = try TestFileSystem(folders: [Folder.emptyHTMLTemplateDirectory, symbolGraphFiles, outputLocation])
        
        var action = try ConvertAction(
            documentationBundleURL: nil,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                additionalSymbolGraphFiles: [URL(fileURLWithPath: "/Not-a-doc-bundle/MyKit.symbols.json")]
            )
        )
        
        XCTAssert(action.context.registeredBundles.isEmpty)
        XCTAssertNoThrow(try action.perform(logHandle: .none))

        XCTAssertEqual(action.context.registeredBundles.count, 1)
        let bundle = try XCTUnwrap(action.context.registeredBundles.first, "Should have registered the generated test bundle.")
        XCTAssertEqual(bundle.displayName, "MyKit")
        XCTAssertEqual(bundle.identifier, "MyKit")
    }
    
    func testConvertWithoutBundleErrorsForMultipleModulesSymbolGraph() throws {
        let testBundle = Bundle.module.url(forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let myKitSymbolGraph = testBundle
            .appendingPathComponent("mykit-iOS.symbols.json")
        let sideKitSymbolGraph = testBundle
            .appendingPathComponent("sidekit.symbols.json")
        
        XCTAssert(FileManager.default.fileExists(atPath: myKitSymbolGraph.path))
        XCTAssert(FileManager.default.fileExists(atPath: sideKitSymbolGraph.path))
        let symbolGraphFiles = Folder(name: "Not-a-doc-bundle", content: [
            CopyOfFile(original: myKitSymbolGraph, newName: "MyKit.symbols.json"),
            CopyOfFile(original: sideKitSymbolGraph, newName: "SideKit.symbols.json")
        ])
        
        let outputLocation = Folder(name: "output", content: [])
        
        let testDataProvider = try TestFileSystem(
            folders: [Folder.emptyHTMLTemplateDirectory, symbolGraphFiles, outputLocation]
        )
        
        var infoPlistFallbacks = [String: Any]()
        infoPlistFallbacks["CFBundleIdentifier"] = "com.example.test"
        
        var action = try ConvertAction(
            documentationBundleURL: nil,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                infoPlistFallbacks: infoPlistFallbacks,
                additionalSymbolGraphFiles: [
                    URL(fileURLWithPath: "/Not-a-doc-bundle/MyKit.symbols.json"),
                    URL(fileURLWithPath: "/Not-a-doc-bundle/SideKit.symbols.json")
                ]
            )
        )
        
        let logStorage = LogHandle.LogStorage()
        XCTAssertThrowsError(try action.perform(logHandle: .memory(logStorage))) { error in
            XCTAssertEqual(error.localizedDescription, """
            The information provided as command line arguments is not enough to generate a documentation bundle:
            
            Missing value for 'CFBundleDisplayName'.
            Use the '--fallback-display-name' argument or add 'CFBundleDisplayName' to the bundle Info.plist.
            
            """)
        }
    }
    
    func testConvertWithBundleDerivesDisplayNameFromBundle() throws {
        let emptyDoccCatalog = try createTemporaryDirectory(named: "Something.docc")
        let outputLocation = try createTemporaryDirectory(named: "output")

        var infoPlistFallbacks = [String: Any]()
        infoPlistFallbacks["CFBundleIdentifier"] = "com.example.test"

        var action = try ConvertAction(
            documentationBundleURL: emptyDoccCatalog,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: outputLocation.absoluteURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.write(inside: createTemporaryDirectory(named: "template")),
            emitDigest: false,
            currentPlatforms: nil,
            temporaryDirectory: createTemporaryDirectory(),
            bundleDiscoveryOptions: BundleDiscoveryOptions(
                infoPlistFallbacks: infoPlistFallbacks,
                additionalSymbolGraphFiles: []
            )
        )
        XCTAssert(action.context.registeredBundles.isEmpty)
        XCTAssertNoThrow(try action.perform(logHandle: .none))

        XCTAssertEqual(action.context.registeredBundles.count, 1)
        let bundle = try XCTUnwrap(action.context.registeredBundles.first, "Should have registered the generated test bundle.")
        XCTAssertEqual(bundle.displayName, "Something")
        XCTAssertEqual(bundle.identifier, "com.example.test")
    }

    private func uniformlyPrintDiagnosticMessages(_ problems: [Problem]) -> String {
        return problems.sorted(by: { (lhs, rhs) -> Bool in
            guard lhs.diagnostic.identifier != rhs.diagnostic.identifier else {
                return lhs.diagnostic.summary < rhs.diagnostic.summary
            }
            return lhs.diagnostic.identifier < rhs.diagnostic.identifier
        }) .map { DiagnosticConsoleWriter.formattedDescription(for: $0.diagnostic) }.sorted().joined(separator: "\n")
    }
    
    // Tests that when converting a catalog with no technology root a warning is raised (r93371988)
    func testConvertWithNoTechnologyRoot() throws {
        func problemsFromConverting(_ catalogContent: [File]) throws -> [Problem] {
            let catalog = Folder(name: "unit-test.docc", content: catalogContent)
            let testDataProvider = try TestFileSystem(folders: [catalog, Folder.emptyHTMLTemplateDirectory])
            let engine = DiagnosticEngine()
            var action = try ConvertAction(
                documentationBundleURL: catalog.absoluteURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: URL(fileURLWithPath: "/output"),
                htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
                emitDigest: false,
                currentPlatforms: nil,
                dataProvider: testDataProvider,
                fileManager: testDataProvider,
                temporaryDirectory: URL(fileURLWithPath: "/tmp"),
                diagnosticEngine: engine
            )
            _ = try action.perform(logHandle: .none)
            return engine.problems
        }
        
        let onlyTutorialArticleProblems = try problemsFromConverting([
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            TextFile(name: "Article.tutorial", utf8Content: """
                @Article(time: 20) {
                   @Intro(title: "Slothy Tutorials") {
                      This is an abstract for the intro.
                   }
                }
                """
            ),
        ])
        XCTAssert(onlyTutorialArticleProblems.contains(where: {
            $0.diagnostic.identifier == "org.swift.docc.MissingTableOfContents"
        }))
        
        let tutorialTableOfContentProblem = try problemsFromConverting([
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            TextFile(name: "table-of-contents.tutorial", utf8Content: """
                """
            ),
            TextFile(name: "article.tutorial", utf8Content: """
                @Article(time: 20) {
                   @Intro(title: "Slothy Tutorials") {
                      This is an abstract for the intro.
                   }
                }
                """
            ),
        ])
        XCTAssert(tutorialTableOfContentProblem.contains(where: {
            $0.diagnostic.identifier == "org.swift.docc.MissingTableOfContents"
        }))
        
        let incompleteTutorialFile = try problemsFromConverting([
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            TextFile(name: "article.tutorial", utf8Content: """
                @Chapter(name: "SlothCreator Essentials") {
                    @Image(source: "chapter1-slothcreatorEssentials.png", alt: "A wireframe of an app interface that has an outline of a sloth and four buttons below the sloth. The buttons display the following symbols, from left to right: snowflake, fire, wind, and lightning.")
                    
                    Create custom sloths and edit their attributes and powers using SlothCreator.
                    
                    @TutorialReference(tutorial: "doc:Creating-Custom-Sloths")
                }
                """
            ),
        ])
        XCTAssert(incompleteTutorialFile.contains(where: {
            $0.diagnostic.identifier == "org.swift.docc.missingTopLevelChild"
        }))
        XCTAssertFalse(incompleteTutorialFile.contains(where: {
            $0.diagnostic.identifier == "org.swift.docc.MissingTableOfContents"
        }))
    }
    
    func testWrittenDiagnosticsAfterConvert() throws {
        let bundle = Folder(name: "unit-test.docc", content: [
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            TextFile(name: "Documentation.md", utf8Content: """
            # ``ModuleThatDoesNotExist``

            This will result in two errors from two different phases of the build
            """)
        ])
        let testDataProvider = try TestFileSystem(folders: [bundle, Folder.emptyHTMLTemplateDirectory])
        let targetDirectory = URL(fileURLWithPath: testDataProvider.currentDirectoryPath).appendingPathComponent("target", isDirectory: true)
        let diagnosticFile = try createTemporaryDirectory().appendingPathComponent("test-diagnostics.json")
        let fileConsumer = DiagnosticFileWriter(outputPath: diagnosticFile)
        
        let engine = DiagnosticEngine()
        engine.add(fileConsumer)
        
        let logStorage = LogHandle.LogStorage()
        let consoleConsumer = DiagnosticConsoleWriter(LogHandle.memory(logStorage), formattingOptions: [], baseURL: nil, highlight: false)
        engine.add(consoleConsumer)
        
        var action = try ConvertAction(
            documentationBundleURL: bundle.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetDirectory,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: testDataProvider,
            fileManager: testDataProvider,
            temporaryDirectory: testDataProvider.uniqueTemporaryDirectory(),
            diagnosticEngine: engine
        )
        
        let _ = try action.perform(logHandle: .none)
        XCTAssertEqual(engine.problems.count, 1)
        
        XCTAssert(FileManager.default.fileExists(atPath: diagnosticFile.path))
        
        let diagnosticFileContent = try JSONDecoder().decode(DiagnosticFile.self, from: Data(contentsOf: diagnosticFile))
        XCTAssertEqual(diagnosticFileContent.diagnostics.count, 1)
        
        XCTAssertEqual(diagnosticFileContent.diagnostics.map(\.summary).sorted(), [
            "No symbol matched 'ModuleThatDoesNotExist'. Can't resolve 'ModuleThatDoesNotExist'."
        ].sorted())
        
        let logLines = logStorage.text.splitByNewlines
        XCTAssertEqual(logLines.filter { $0.hasPrefix("warning: No symbol matched 'ModuleThatDoesNotExist'. Can't resolve 'ModuleThatDoesNotExist'.") }.count, 1)
    }
    
    func testEncodedImagePaths() throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Something.md", utf8Content: """
            # Something
            
            This article links to some assets
            
            ![Some alt text](image-name)
            """),
            
            // Image variants
            DataFile(name: "image-name.png", data: Data()),
            DataFile(name: "image-name~dark.png", data: Data()),
            DataFile(name: "image-name@2x.png", data: Data()),
            DataFile(name: "image-name~dark@2x.png", data: Data()),
        ])
    
        let fileSystem = try TestFileSystem(folders: [catalog])
        let targetURL = URL(fileURLWithPath: "/Output.doccarchive")
        
        var action = try ConvertAction(
            documentationBundleURL: catalog.absoluteURL,
            outOfProcessResolver: nil,
            analyze: false,
            targetDirectory: targetURL,
            htmlTemplateDirectory: Folder.emptyHTMLTemplateDirectory.absoluteURL,
            emitDigest: false,
            currentPlatforms: nil,
            dataProvider: fileSystem,
            fileManager: fileSystem,
            temporaryDirectory: fileSystem.uniqueTemporaryDirectory()
        )
        
        let result = try action.perform(logHandle: .none)
        XCTAssertEqual(result.outputs, [targetURL])
        
        XCTAssertEqual(fileSystem.dump(subHierarchyFrom: targetURL.path), """
        Output.doccarchive/
        ├─ data/
        │  ╰─ documentation/
        │     ╰─ something.json
        ├─ downloads/
        │  ╰─ unit-test/
        ├─ images/
        │  ╰─ unit-test/
        │     ├─ image-name.png
        │     ├─ image-name@2x.png
        │     ├─ image-name~dark.png
        │     ╰─ image-name~dark@2x.png
        ├─ metadata.json
        ╰─ videos/
           ╰─ unit-test/
        """)
        
        XCTAssert(fileSystem.fileExists(atPath: targetURL.appendingPathComponent("images/unit-test/image-name.png").path))
        let pageURL = targetURL.appendingPathComponent("data/documentation/something.json")
        XCTAssert(fileSystem.fileExists(atPath: pageURL.path))
        
        let renderNode = try JSONDecoder().decode(RenderNode.self, from: fileSystem.contentsOfURL(pageURL))
        
        XCTAssertEqual(renderNode.references.keys.sorted(), ["image-name"])
        let imageReference = try XCTUnwrap(renderNode.references["image-name"] as? ImageReference)
        
        XCTAssertEqual(imageReference.altText, "Some alt text")
        XCTAssertEqual(imageReference.asset.variants.values.map(\.absoluteString).sorted(), [
            "/images/unit-test/image-name.png",
            "/images/unit-test/image-name@2x.png",
            "/images/unit-test/image-name~dark.png",
            "/images/unit-test/image-name~dark@2x.png"
        ])
    }
    
    #endif
}

private extension LinkDestinationSummary {
    // A convenience initializer for test data.
    init(
        kind: DocumentationNode.Kind,
        relativePresentationURL: URL,
        referenceURL: URL,
        title: String,
        language: SourceLanguage,
        abstract: String?,
        taskGroups: [TaskGroup],
        usr: String? = nil,
        availableLanguages: Set<SourceLanguage>,
        platforms: [PlatformAvailability]?,
        topicImages: [TopicImage]?,
        references: [RenderReference]?,
        redirects: [URL]?
    ) {
        self.init(
            kind: kind,
            language: language,
            relativePresentationURL: relativePresentationURL,
            referenceURL: referenceURL,
            title: title,
            abstract: abstract.map { [.text($0)] },
            availableLanguages: availableLanguages,
            platforms: platforms,
            taskGroups: taskGroups,
            usr: usr,
            declarationFragments: nil,
            redirects: redirects,
            topicImages: topicImages,
            references: references,
            variants: []
        )
    }
}

private extension ImageReference {
    // A convenience initializer for test data.
    init(name: String, altText: String?, userInterfaceStyle: UserInterfaceStyle, displayScale: DisplayScale) {
        var asset = DataAsset()
        asset.register(
            URL(string: "/images/\(name)")!,
            with: DataTraitCollection(userInterfaceStyle: userInterfaceStyle, displayScale: displayScale)
        )
        self.init(
            identifier: RenderReferenceIdentifier(name),
            altText: altText,
            imageAsset: asset
        )
    }
}

extension File {
    /// A URL of the file node if it was located in the root of the file system.
    var absoluteURL: URL { return URL(string: "/\(name)")! }
}

extension Folder {
    /// Recreates a disk-based directory as a `Folder`.
    static func createFromDisk(url: URL) throws -> Folder {
        var content = [File]()
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            for case let fileURL as URL in enumerator {
                if FileManager.default.fileExists(atPath: fileURL.path), fileURL.hasDirectoryPath {
                    content.append(try createFromDisk(url: fileURL))
                } else {
                    if fileURL.lastPathComponent == "Info.plist",
                       let infoPlistData = FileManager.default.contents(atPath: fileURL.path),
                       let infoPlist = try? PropertyListSerialization.propertyList(from: infoPlistData, options: [], format: nil) as? [String: Any],
                       let displayName = infoPlist["CFBundleDisplayName"] as? String,
                       let identifier = infoPlist["CFBundleIdentifier"] as? String {
                        content.append(InfoPlist(displayName: displayName, identifier: identifier))
                    } else {
                        content.append(CopyOfFile(original: fileURL, newName: fileURL.lastPathComponent))
                    }
                }
            }
        }
        return Folder(name: url.lastPathComponent, content: content)
    }
}
