/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities
@testable import SwiftDocC
import SwiftDocCTestUtilities

class ConvertSubcommandTests: XCTestCase {
    private let testCatalogURL = Bundle.module.url(
        forResource: "TestCatalog", withExtension: "docc", subdirectory: "Test Catalogs")!
    
    private let testTemplateURL = Bundle.module.url(
        forResource: "Test Template", withExtension: nil, subdirectory: "Test Resources")!
    
    func testOptionsValidation() throws {
        // create source catalog directory
        let sourceURL = try createTemporaryDirectory(named: "documentation")
        try "".write(to: sourceURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        
        // create template dir
        let rendererTemplateDirectory = try createTemporaryDirectory()
        try "".write(to: rendererTemplateDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        
        // Tests a single input.
        do {
            setenv(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path, 1)
            XCTAssertNoThrow(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test no inputs.
        do {
            unsetenv(TemplateOption.environmentVariableKey)
            XCTAssertNoThrow(try Docc.Convert.parse([]))
        }
        
        // Test missing input folder throws
        do {
            setenv(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path, 1)
            XCTAssertThrowsError(try Docc.Convert.parse([
                URL(fileURLWithPath: "123").path,
            ]))
        }
        
        // Test input folder is file throws
        do {
            let sourceAsSingleFileURL = sourceURL.appendingPathComponent("file-name.txt")
            try "some text".write(to: sourceAsSingleFileURL, atomically: true, encoding: .utf8)
            defer {
                try? FileManager.default.removeItem(at: sourceAsSingleFileURL)
            }
            
            setenv(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path, 1)
            XCTAssertThrowsError(try Docc.Convert.parse([
                sourceAsSingleFileURL.path,
            ]))
        }
        
        
        // Test no template folder does not throw
        do {
            unsetenv(TemplateOption.environmentVariableKey)
            XCTAssertNoThrow(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test default template
        do {
            unsetenv(TemplateOption.environmentVariableKey)
            let tempFolder = try createTemporaryDirectory()
            let doccExecutableLocation = tempFolder
                .appendingPathComponent("bin")
                .appendingPathComponent("docc-executable-name")
            let defaultTemplateDir = tempFolder
                .appendingPathComponent("share")
                .appendingPathComponent("docc")
                .appendingPathComponent("render", isDirectory: true)
            let originalDoccExecutableLocation = TemplateOption.doccExecutableLocation
            
            TemplateOption.doccExecutableLocation = doccExecutableLocation
            defer {
                TemplateOption.doccExecutableLocation = originalDoccExecutableLocation
            }
            try FileManager.default.createDirectory(at: defaultTemplateDir, withIntermediateDirectories: true, attributes: nil)
            defer {
                try? FileManager.default.removeItem(at: defaultTemplateDir)
            }
            try "".write(to: defaultTemplateDir.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
            
            let convert = try Docc.Convert.parse([
                testCatalogURL.path,
            ])
            XCTAssertEqual(
                convert.templateOption.templateURL?.standardizedFileURL,
                defaultTemplateDir.standardizedFileURL
            )
            let action = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(
                action.htmlTemplateDirectory,
                defaultTemplateDir.standardizedFileURL
            )
        }
        
        // Test bad template folder throws
        do {
            setenv(TemplateOption.environmentVariableKey, URL(fileURLWithPath: "123").path, 1)
            XCTAssertThrowsError(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test default target folder.
        do {
            setenv(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path, 1)
            let parseResult = try Docc.Convert.parse([
                sourceURL.path,
            ])
            
            XCTAssertEqual(parseResult.outputURL, sourceURL.appendingPathComponent(".docc-build"))
        }
    }

    func testDefaultCurrentWorkingDirectory() {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)

        XCTAssertTrue(
            FileManager.default.changeCurrentDirectoryPath(testCatalogURL.path),
            "The test env is invalid if the current working directory is not set to the current working directory"
        )

        do {
            // Passing no argument should default to the current working directory.
            let convert = try Docc.Convert.parse([])
            let convertAction = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(convertAction.rootURL?.absoluteURL, testCatalogURL.absoluteURL)
        } catch {
            XCTFail("Failed to run docc convert without arguments.")
        }
    }

    func testInvalidTargetPathOptions() throws {
        let fakeRootPath = "/nonexistentrootfolder/subfolder"
        // Test throws on non-existing parent folder.
        for path in ["/tmp/output", "/tmp", "/"] {
            setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
            XCTAssertThrowsError(try Docc.Convert.parse([
                "--output-path", fakeRootPath + path,
                testCatalogURL.path,
            ]), "Did not refuse target folder path '\(path)'")
        }
    }
  
    func testAnalyzerIsTurnedOffByDefault() throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        let convertOptions = try Docc.Convert.parse([
            testCatalogURL.path,
        ])
        
        XCTAssertFalse(convertOptions.analyze)
    }
    
    func testInfoPlistFallbacks() throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        
        // Default to nil when not passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
            ])
            
            XCTAssertNil(convertOptions.fallbackCatalogDisplayName)
            XCTAssertNil(convertOptions.fallbackCatalogIdentifier)
            XCTAssertNil(convertOptions.fallbackCatalogVersion)
            XCTAssertNil(convertOptions.defaultCodeListingLanguage)
        }
        
        func checkFallbacks(_ convertOptions: Docc.Convert, line: UInt = #line) {
            XCTAssertEqual(convertOptions.fallbackCatalogDisplayName, "DisplayName", line: line)
            XCTAssertEqual(convertOptions.fallbackCatalogIdentifier, "com.example.test", line: line)
            XCTAssertEqual(convertOptions.fallbackCatalogVersion, "1.2.3", line: line)
            XCTAssertEqual(convertOptions.defaultCodeListingLanguage, "swift", line: line)
        }
        
        // Are set when passed (old name, to be removed rdar://72449411)
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--display-name", "DisplayName",
                "--bundle-identifier", "com.example.test",
                "--bundle-version", "1.2.3",
                "--default-code-listing-language", "swift",
            ])
            
            checkFallbacks(convertOptions)
        }
        
        // Are set when passed (deprecated names)
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--fallback-display-name", "DisplayName",
                "--fallback-bundle-identifier", "com.example.test",
                "--fallback-bundle-version", "1.2.3",
                "--default-code-listing-language", "swift",
            ])
            
            checkFallbacks(convertOptions)
        }
        
        // Are set when passed 
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--fallback-display-name", "DisplayName",
                "--fallback-catalog-identifier", "com.example.test",
                "--fallback-catalog-version", "1.2.3",
                "--default-code-listing-language", "swift",
            ])
            
            checkFallbacks(convertOptions)
        }
    }
    
    func testAdditionalSymbolGraphFiles() throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        
        // Default to [] when not passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
            ])
            
            XCTAssertEqual(convertOptions.additionalSymbolGraphDirectory, nil)
        }
        
        // Is set when passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--additional-symbol-graph-dir",
                "/path/to/folder-of-symbol-graph-files",
            ])
            
            XCTAssertEqual(
                convertOptions.additionalSymbolGraphDirectory,
                URL(fileURLWithPath: "/path/to/folder-of-symbol-graph-files")
            )
        }
        
        // Is recursively scanned to find symbol graph files set when passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--additional-symbol-graph-dir",
                testCatalogURL.path,
            ])
            
            let action = try ConvertAction(fromConvertCommand: convertOptions)
            XCTAssertEqual(action.converter.catalogDiscoveryOptions.additionalSymbolGraphFiles.map { $0.lastPathComponent }.sorted(), [
                "FillIntroduced.symbols.json",
                "MyKit@SideKit.symbols.json",
                "mykit-iOS.symbols.json",
                "sidekit.symbols.json",
            ])
        }
        
        // Deprecated option is still supported
        do {
            let convertOptions = try Docc.Convert.parse([
                testCatalogURL.path,
                "--additional-symbol-graph-files",
                "/path/to/first.symbols.json",
                "/path/to/second.symbols.json",
            ])
            
            XCTAssertEqual(convertOptions.additionalSymbolGraphFiles, [
                URL(fileURLWithPath: "/path/to/first.symbols.json"),
                URL(fileURLWithPath: "/path/to/second.symbols.json"),
            ])
            
            let action = try ConvertAction(fromConvertCommand: convertOptions)
            XCTAssertEqual(action.converter.catalogDiscoveryOptions.additionalSymbolGraphFiles, [
                URL(fileURLWithPath: "/path/to/first.symbols.json"),
                URL(fileURLWithPath: "/path/to/second.symbols.json"),
            ])
        }
    }
    
    func testIndex() throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        
        let convertOptions = try Docc.Convert.parse([
            testCatalogURL.path,
            "--index",
        ])
        
        XCTAssertEqual(convertOptions.index, true)
        
        let action = try ConvertAction(fromConvertCommand: convertOptions)
        
        XCTAssertEqual(action.buildLMDBIndex, true)
    }
    
    func testEmitLMDBIndex() throws {
        let convertOptions = try Docc.Convert.parse([
            testCatalogURL.path,
            "--emit-lmdb-index",
        ])
        
        XCTAssertTrue(convertOptions.emitLMDBIndex)
        
        let action = try ConvertAction(fromConvertCommand: convertOptions)
        
        XCTAssertTrue(action.buildLMDBIndex)
    }
    
    func testWithoutCatalog() throws {
        setenv(TemplateOption.environmentVariableKey, testTemplateURL.path, 1)
        
        let convertOptions = try Docc.Convert.parse([
            "--fallback-display-name", "DisplayName",
            "--fallback-catalog-identifier", "com.example.test",
            "--fallback-catalog-version", "1.2.3",
            
            "--additional-symbol-graph-dir",
            testCatalogURL.path,
        ])
        
        // Verify the options
        
        XCTAssertNil(convertOptions.documentationCatalog.url)
        
        XCTAssertEqual(convertOptions.fallbackCatalogDisplayName, "DisplayName")
        XCTAssertEqual(convertOptions.fallbackCatalogIdentifier, "com.example.test")
        XCTAssertEqual(convertOptions.fallbackCatalogVersion, "1.2.3")
        
        XCTAssertEqual(
            convertOptions.additionalSymbolGraphDirectory,
            testCatalogURL
        )
        
        // Verify the action
        
        let action = try ConvertAction(fromConvertCommand: convertOptions)
        XCTAssertNil(action.rootURL)
        XCTAssertNil(action.converter.rootURL)
        
        XCTAssertEqual(action.converter.catalogDiscoveryOptions.additionalSymbolGraphFiles.map { $0.lastPathComponent }.sorted(), [
            "FillIntroduced.symbols.json",
            "MyKit@SideKit.symbols.json",
            "mykit-iOS.symbols.json",
            "sidekit.symbols.json",
        ])
    }

    func testExperimentalEnableCustomTemplatesFlag() throws {
        let commandWithoutFlag = try Docc.Convert.parse([testCatalogURL.path])
        let actionWithoutFlag = try ConvertAction(fromConvertCommand: commandWithoutFlag)
        XCTAssertFalse(commandWithoutFlag.experimentalEnableCustomTemplates)
        XCTAssertFalse(actionWithoutFlag.experimentalEnableCustomTemplates)

        let commandWithFlag = try Docc.Convert.parse([
            "--experimental-enable-custom-templates",
            testCatalogURL.path,
        ])
        let actionWithFlag = try ConvertAction(fromConvertCommand: commandWithFlag)
        XCTAssertTrue(commandWithFlag.experimentalEnableCustomTemplates)
        XCTAssertTrue(actionWithFlag.experimentalEnableCustomTemplates)
    }
}
