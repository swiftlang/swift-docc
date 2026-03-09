/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import DocCCommandLine
@testable import SwiftDocC
import DocCTestUtilities
import ArgumentParser

class ConvertSubcommandTests: XCTestCase {
    private let testBundleURL = Bundle.module.url(
        forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
    
    private let testTemplateURL = Bundle.module.url(
        forResource: "Test Template", withExtension: nil, subdirectory: "Test Resources")!

    override func setUpWithError() throws {
        // By default, run all tests in a temporary directory to ensure that they are not affected
        // by the machine environment.
        let priorWorkingDirectory = FileManager.default.currentDirectoryPath
        let temporaryDirectory = try createTemporaryDirectory()
        FileManager.default.changeCurrentDirectoryPath(temporaryDirectory.path)
        addTeardownBlock {
            FileManager.default.changeCurrentDirectoryPath(priorWorkingDirectory)
        }

        // By default, send all warnings to `.none` instead of filling the
        // test console output with unrelated messages.
        Docc.Convert._errorLogHandle = .none

        // Set the documentation template to a well-defined default so that options parsing isn't
        // affected by other tests' changing it.
        let existingTemplate = ProcessInfo.processInfo.environment[TemplateOption.environmentVariableKey]
        SetEnvironmentVariable(TemplateOption.environmentVariableKey, testTemplateURL.path)
        addTeardownBlock {
            if let existingTemplate = existingTemplate {
                SetEnvironmentVariable(TemplateOption.environmentVariableKey, existingTemplate)
            } else {
                UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
            }
        }
    }

    func testOptionsValidation() throws {
        // create source bundle directory
        let sourceURL = try createTemporaryDirectory(named: "documentation")
        try "".write(to: sourceURL.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        
        // create template dir
        let rendererTemplateDirectory = try createTemporaryDirectory()
        try "".write(to: rendererTemplateDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)

        // Tests a single input.
        do {
            SetEnvironmentVariable(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path)
            XCTAssertNoThrow(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test no inputs.
        do {
            UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
            XCTAssertNoThrow(try Docc.Convert.parse([]))
        }
        
        // Test missing input folder throws
        do {
            SetEnvironmentVariable(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path)
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
            
            SetEnvironmentVariable(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path)
            XCTAssertThrowsError(try Docc.Convert.parse([
                sourceAsSingleFileURL.path,
            ]))
        }
        
        
        // Test no template folder does not throw
        do {
            UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
            XCTAssertNoThrow(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test default template
        do {
            UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)
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
                testBundleURL.path,
            ])
            XCTAssertEqual(
                convert.templateOption.templateURL?.standardizedFileURL,
                defaultTemplateDir.standardizedFileURL
            )
            let action = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(
                action.htmlTemplateDirectory?.standardizedFileURL,
                defaultTemplateDir.standardizedFileURL
            )
        }
        
        // Test bad template folder throws
        do {
            SetEnvironmentVariable(TemplateOption.environmentVariableKey, URL(fileURLWithPath: "123").path)
            XCTAssertThrowsError(try Docc.Convert.parse([
                sourceURL.path,
            ]))
        }
        
        // Test default target folder.
        do {
            SetEnvironmentVariable(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path)
            let parseResult = try Docc.Convert.parse([
                sourceURL.path,
            ])
            
            XCTAssertEqual(parseResult.outputURL, sourceURL.appendingPathComponent(".docc-build"))
        }
    }

    func testDefaultCurrentWorkingDirectory() {
        XCTAssertTrue(
            FileManager.default.changeCurrentDirectoryPath(testBundleURL.path),
            "The test env is invalid if the current working directory is not set to the current working directory"
        )

        do {
            // Passing no argument should default to the current working directory.
            let convert = try Docc.Convert.parse([])
            let convertAction = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(convertAction.rootURL?.absoluteURL, testBundleURL.absoluteURL)
        } catch {
            XCTFail("Failed to run docc convert without arguments.")
        }
    }

    func testInvalidTargetPathOptions() throws {
        let fakeRootPath = "/nonexistentrootfolder/subfolder"
        // Test throws on non-existing parent folder.
        for outputOption in ["-o", "--output-path"] {
            for path in ["/tmp/output", "/tmp", "/"] {
                XCTAssertThrowsError(try Docc.Convert.parse([
                    outputOption, fakeRootPath + path,
                    testBundleURL.path,
                ]), "Did not refuse target folder path '\(path)'")
            }
        }
    }

    func testAnalyzerIsTurnedOffByDefault() throws {
        let convertOptions = try Docc.Convert.parse([
            testBundleURL.path,
        ])
        
        XCTAssertFalse(convertOptions.diagnosticOptions.analyze)
    }
    
    func testInfoPlistFallbacks() throws {
        // Default to nil when not passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
            ])
            
            XCTAssertNil(convertOptions.infoPlistFallbacks.fallbackBundleDisplayName)
            XCTAssertNil(convertOptions.infoPlistFallbacks.fallbackBundleIdentifier)
            XCTAssertNil(convertOptions.infoPlistFallbacks.defaultCodeListingLanguage)
        }
        
        // Are set when passed (old name, to be removed rdar://72449411)
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--display-name", "DisplayName",
                "--bundle-identifier", "com.example.test",
                "--default-code-listing-language", "swift",
            ])
            
            XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleDisplayName, "DisplayName")
            XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleIdentifier, "com.example.test")
            XCTAssertEqual(convertOptions.infoPlistFallbacks.defaultCodeListingLanguage, "swift")
        }
        
        // Are set when passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--fallback-display-name", "DisplayName",
                "--fallback-bundle-identifier", "com.example.test",
                "--default-code-listing-language", "swift",
            ])
            
            XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleDisplayName, "DisplayName")
            XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleIdentifier, "com.example.test")
            XCTAssertEqual(convertOptions.infoPlistFallbacks.defaultCodeListingLanguage, "swift")
        }
    }
    
    func testAdditionalSymbolGraphFiles() throws {
        // Default to [] when not passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
            ])
            
            XCTAssertEqual(convertOptions.inputsAndOutputs.additionalSymbolGraphDirectory, nil)
        }
        
        // Is set when passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--additional-symbol-graph-dir",
                "/path/to/folder-of-symbol-graph-files",
            ])
            
            XCTAssertEqual(
                convertOptions.inputsAndOutputs.additionalSymbolGraphDirectory,
                URL(fileURLWithPath: "/path/to/folder-of-symbol-graph-files")
            )
        }
        
        // Is recursively scanned to find symbol graph files set when passed
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--additional-symbol-graph-dir",
                testBundleURL.path,
            ])

            XCTAssertEqual(convertOptions.bundleDiscoveryOptions.additionalSymbolGraphFiles.map { $0.lastPathComponent }.sorted(), [
                "FillIntroduced.symbols.json",
                "MyKit@SideKit.symbols.json",
                "mykit-iOS.symbols.json",
                "sidekit.symbols.json",
            ])
        }
    }
    
    func testEmitLMDBIndex() throws {
        let convertOptions = try Docc.Convert.parse([
            testBundleURL.path,
            "--emit-lmdb-index",
        ])
        
        XCTAssertTrue(convertOptions.featureFlags.emitLMDBIndex)
        
        let action = try ConvertAction(fromConvertCommand: convertOptions)
        
        XCTAssertTrue(action.buildLMDBIndex)
    }
    
    func testWithoutBundle() throws {
        let convertOptions = try Docc.Convert.parse([
            "--fallback-display-name", "DisplayName",
            "--fallback-bundle-identifier", "com.example.test",
            
            "--additional-symbol-graph-dir",
            testBundleURL.path,
        ])
        
        // Verify the options
        
        XCTAssertNil(convertOptions.inputsAndOutputs.documentationCatalog.url)
        
        XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleDisplayName, "DisplayName")
        XCTAssertEqual(convertOptions.infoPlistFallbacks.fallbackBundleIdentifier, "com.example.test")
        
        XCTAssertEqual(
            convertOptions.inputsAndOutputs.additionalSymbolGraphDirectory,
            testBundleURL
        )
        
        // Verify the action
        
        let action = try ConvertAction(fromConvertCommand: convertOptions)
        XCTAssertNil(action.rootURL)
        
        XCTAssertEqual(convertOptions.bundleDiscoveryOptions.additionalSymbolGraphFiles.map { $0.lastPathComponent }.sorted(), [
            "FillIntroduced.symbols.json",
            "MyKit@SideKit.symbols.json",
            "mykit-iOS.symbols.json",
            "sidekit.symbols.json",
        ])
    }

    func testExperimentalEnableCustomTemplatesFlag() throws {
        let commandWithoutFlag = try Docc.Convert.parse([testBundleURL.path])
        let actionWithoutFlag = try ConvertAction(fromConvertCommand: commandWithoutFlag)
        XCTAssertFalse(commandWithoutFlag.featureFlags.experimentalEnableCustomTemplates)
        XCTAssertFalse(actionWithoutFlag.experimentalEnableCustomTemplates)

        let commandWithFlag = try Docc.Convert.parse([
            "--experimental-enable-custom-templates",
            testBundleURL.path,
        ])
        let actionWithFlag = try ConvertAction(fromConvertCommand: commandWithFlag)
        XCTAssertTrue(commandWithFlag.featureFlags.experimentalEnableCustomTemplates)
        XCTAssertTrue(actionWithFlag.experimentalEnableCustomTemplates)
    }
    
    func testExperimentalEnableDeviceFrameSupportFlag() throws {
        let originalFeatureFlagsState = FeatureFlags.current
        
        defer {
            FeatureFlags.current = originalFeatureFlagsState
        }
        
        let commandWithoutFlag = try Docc.Convert.parse([testBundleURL.path])
        _ = try ConvertAction(fromConvertCommand: commandWithoutFlag)
        XCTAssertFalse(commandWithoutFlag.featureFlags.enableExperimentalDeviceFrameSupport)
        XCTAssertFalse(FeatureFlags.current.isExperimentalDeviceFrameSupportEnabled)

        let commandWithFlag = try Docc.Convert.parse([
            "--enable-experimental-device-frame-support",
            testBundleURL.path,
        ])
        _ = try ConvertAction(fromConvertCommand: commandWithFlag)
        XCTAssertTrue(commandWithFlag.featureFlags.enableExperimentalDeviceFrameSupport)
        XCTAssertTrue(FeatureFlags.current.isExperimentalDeviceFrameSupportEnabled)
    }
    
    func testExperimentalEnableExternalLinkSupportFlag() throws {
        let originalFeatureFlagsState = FeatureFlags.current
        defer {
            FeatureFlags.current = originalFeatureFlagsState
        }
        
        let commandWithoutFlag = try Docc.Convert.parse([testBundleURL.path])
        _ = try ConvertAction(fromConvertCommand: commandWithoutFlag)
        XCTAssertFalse(commandWithoutFlag.featureFlags.enableExperimentalLinkHierarchySerialization)
        XCTAssertFalse(FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled)

        let commandWithFlag = try Docc.Convert.parse([
            "--enable-experimental-external-link-support",
            testBundleURL.path,
        ])
        _ = try ConvertAction(fromConvertCommand: commandWithFlag)
        XCTAssertTrue(commandWithFlag.featureFlags.enableExperimentalLinkHierarchySerialization)
        XCTAssertTrue(FeatureFlags.current.isExperimentalLinkHierarchySerializationEnabled)
    }
    
    func testExperimentalEnableOverloadedSymbolPresentation() throws {
        let originalFeatureFlagsState = FeatureFlags.current
        defer {
            FeatureFlags.current = originalFeatureFlagsState
        }
        
        let commandWithoutFlag = try Docc.Convert.parse([testBundleURL.path])
        _ = try ConvertAction(fromConvertCommand: commandWithoutFlag)
        XCTAssertFalse(commandWithoutFlag.featureFlags.enableExperimentalOverloadedSymbolPresentation)
        XCTAssertFalse(FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled)

        let commandWithFlag = try Docc.Convert.parse([
            "--enable-experimental-overloaded-symbol-presentation",
            testBundleURL.path,
        ])
        _ = try ConvertAction(fromConvertCommand: commandWithFlag)
        XCTAssertTrue(commandWithFlag.featureFlags.enableExperimentalOverloadedSymbolPresentation)
        XCTAssertTrue(FeatureFlags.current.isExperimentalOverloadedSymbolPresentationEnabled)
    }
    
    func testLinkDependencyValidation() throws {
        let originalErrorLogHandle = Docc.Convert._errorLogHandle
        let originalDiagnosticFormattingOptions = Docc.Convert._diagnosticFormattingOptions
        defer {
            Docc.Convert._errorLogHandle = originalErrorLogHandle
            Docc.Convert._diagnosticFormattingOptions = originalDiagnosticFormattingOptions
        }
        Docc.Convert._diagnosticFormattingOptions = .formatConsoleOutputForTools
        
        let rendererTemplateDirectory = try createTemporaryDirectory()
        try "".write(to: rendererTemplateDirectory.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        SetEnvironmentVariable(TemplateOption.environmentVariableKey, rendererTemplateDirectory.path)

        let dependencyDir = try createTemporaryDirectory()
            .appendingPathComponent("SomeDependency.doccarchive", isDirectory: true)
        let fileManager = FileManager.default
        
        let argumentsToParse = [
            testBundleURL.path,
            "--dependency",
            dependencyDir.path
        ]
        
        // The dependency doesn't exist
        do {
            let logStorage = LogHandle.LogStorage()
            Docc.Convert._errorLogHandle = .memory(logStorage)
            
            let command = try Docc.Convert.parse(argumentsToParse)
            XCTAssertEqual(command.linkResolutionOptions.dependencies, [])
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), """
            warning: No documentation archive exist at '\(dependencyDir.path)'.
            """)
        }
        // The dependency is a file instead of a directory
        do {
            let logStorage = LogHandle.LogStorage()
            Docc.Convert._errorLogHandle = .memory(logStorage)
            
            try "Some text".write(to: dependencyDir, atomically: true, encoding: .utf8)
            
            let command = try Docc.Convert.parse(argumentsToParse)
            XCTAssertEqual(command.linkResolutionOptions.dependencies, [])
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), """
            warning: Dependency at '\(dependencyDir.path)' is not a directory.
            """)
            
            try fileManager.removeItem(at: dependencyDir)
        }
        // The dependency doesn't have the necessary files
        do {
            let logStorage = LogHandle.LogStorage()
            Docc.Convert._errorLogHandle = .memory(logStorage)
            
            try fileManager.createDirectory(at: dependencyDir, withIntermediateDirectories: false)
            
            let command = try Docc.Convert.parse(argumentsToParse)
            XCTAssertEqual(command.linkResolutionOptions.dependencies, [])
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), """
            warning: Dependency at '\(dependencyDir.path)' doesn't contain a is not a 'linkable-entities.json' file.
            warning: Dependency at '\(dependencyDir.path)' doesn't contain a is not a 'link-hierarchy.json' file.
            """)
        }
        do {
            let logStorage = LogHandle.LogStorage()
            Docc.Convert._errorLogHandle = .memory(logStorage)
            
            try "".write(to: dependencyDir.appendingPathComponent("linkable-entities.json"), atomically: true, encoding: .utf8)
            try "".write(to: dependencyDir.appendingPathComponent("link-hierarchy.json"), atomically: true, encoding: .utf8)
            
            let command = try Docc.Convert.parse(argumentsToParse)
            XCTAssertEqual(command.linkResolutionOptions.dependencies, [dependencyDir])
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .newlines), "")
        }
    }
    
    func testTransformForStaticHostingFlagWithoutHTMLTemplate() throws {
        UnsetEnvironmentVariable(TemplateOption.environmentVariableKey)

        // Since there's no custom template set (and relative HTML template lookup isn't
        // supported in the test harness), we expect `transformForStaticHosting` to
        // be false in every possible scenario of the flag, even when explicitly requested.
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
            ])
            
            XCTAssertFalse(convertOptions.hostingOptions.transformForStaticHosting)
        }
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--transform-for-static-hosting",
            ])
            
            XCTAssertFalse(convertOptions.hostingOptions.transformForStaticHosting)
        }
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--no-transform-for-static-hosting",
            ])
            
            XCTAssertFalse(convertOptions.hostingOptions.transformForStaticHosting)
        }
    }
    
    func testTransformForStaticHostingFlagWithHTMLTemplate() throws {
        // Since we've provided an HTML template, we expect `transformForStaticHosting`
        // to be true by default, and when explicitly requested. It should only be false
        // when `--no-transform-for-static-hosting` is passed.
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
            ])
            
            XCTAssertTrue(convertOptions.hostingOptions.transformForStaticHosting)
        }
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--transform-for-static-hosting",
            ])
            
            XCTAssertTrue(convertOptions.hostingOptions.transformForStaticHosting)
        }
        
        do {
            let convertOptions = try Docc.Convert.parse([
                testBundleURL.path,
                "--no-transform-for-static-hosting",
            ])
            
            XCTAssertFalse(convertOptions.hostingOptions.transformForStaticHosting)
        }
    }
    
    func testTreatWarningAsError() throws {
        do {
            // Passing no argument should default to the current working directory.
            let convert = try Docc.Convert.parse([
                testBundleURL.path
            ])
            let convertAction = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(convertAction.treatWarningsAsErrors, false)
        } catch {
            XCTFail("Failed to run docc convert with minimal arguments.")
        }
        do {
            // Passing no argument should default to the current working directory.
            let convert = try Docc.Convert.parse([
                testBundleURL.path,
                "--warnings-as-errors"
            ])
            let convertAction = try ConvertAction(fromConvertCommand: convert)
            XCTAssertEqual(convertAction.treatWarningsAsErrors, true)
        } catch {
            XCTFail("Failed to run docc convert with minimal arguments.")
        }
    }
    
    func testParameterValidationFeatureFlag() throws {
        // The feature is enabled when no flag is passed.
        let noFlagConvert = try Docc.Convert.parse([])
        XCTAssertEqual(noFlagConvert.featureFlags.enableParametersAndReturnsValidation, true)
        
        // It's allowed to pass the redundant "--enable-..." flag.
        let enabledFlagConvert = try Docc.Convert.parse(["--enable-parameters-and-returns-validation"])
        XCTAssertEqual(enabledFlagConvert.featureFlags.enableParametersAndReturnsValidation, true)
        
        // Passing the "--disable-..." flag turns of the feature.
        let disabledFlagConvert = try Docc.Convert.parse(["--disable-parameters-and-returns-validation"])
        XCTAssertEqual(disabledFlagConvert.featureFlags.enableParametersAndReturnsValidation, false)
    }
    
    func testMentionedFeatureFlag() throws {
        // The feature is enabled when no flag is passed.
        let noFlagConvert = try Docc.Convert.parse([])
        XCTAssertEqual(noFlagConvert.featureFlags.enableMentionedIn, true)
        
        // It's allowed to pass the previous "--enable-experimental-..." flag.
        let oldFlagConvert = try Docc.Convert.parse(["--enable-experimental-mentioned-in"])
        XCTAssertEqual(oldFlagConvert.featureFlags.enableMentionedIn, true)
        
        // It's allowed to pass the redundant "--enable-..." flag.
        let enabledFlagConvert = try Docc.Convert.parse(["--enable-mentioned-in"])
        XCTAssertEqual(enabledFlagConvert.featureFlags.enableMentionedIn, true)
        
        // Passing the "--disable-..." flag turns of the feature.
        let disabledFlagConvert = try Docc.Convert.parse(["--disable-mentioned-in"])
        XCTAssertEqual(disabledFlagConvert.featureFlags.enableMentionedIn, false)
    }
    
    func testStaticHostingWithContentFlag() throws {
        // The feature is disabled when no flag is passed.
        let noFlagConvert = try Docc.Convert.parse([])
        XCTAssertEqual(noFlagConvert.hostingOptions.experimentalTransformForStaticHostingWithContent, false)
        
        let enabledFlagConvert = try Docc.Convert.parse(["--experimental-transform-for-static-hosting-with-content"])
        XCTAssertEqual(enabledFlagConvert.hostingOptions.experimentalTransformForStaticHostingWithContent, true)
        
        // The '...-transform...-with-content' flag also implies the base '--transform-...' flag.
        do {
            let originalErrorLogHandle = Docc.Convert._errorLogHandle
            let originalDiagnosticFormattingOptions = Docc.Convert._diagnosticFormattingOptions
            defer {
                Docc.Convert._errorLogHandle = originalErrorLogHandle
                Docc.Convert._diagnosticFormattingOptions = originalDiagnosticFormattingOptions
            }
            
            let logStorage = LogHandle.LogStorage()
            Docc.Convert._errorLogHandle = .memory(logStorage)
            Docc.Convert._diagnosticFormattingOptions = .formatConsoleOutputForTools
            
            let conflictingFlagsConvert = try Docc.Convert.parse(["--experimental-transform-for-static-hosting-with-content", "--no-transform-for-static-hosting"])
            XCTAssertEqual(conflictingFlagsConvert.hostingOptions.experimentalTransformForStaticHostingWithContent, true)
            XCTAssertEqual(conflictingFlagsConvert.hostingOptions.transformForStaticHosting, true)
            
            XCTAssertEqual(logStorage.text.trimmingCharacters(in: .whitespacesAndNewlines), """
            warning: Passing '--experimental-transform-for-static-hosting-with-content' also implies '--transform-for-static-hosting'. Passing '--no-transform-for-static-hosting' has no effect.
            """)
        }
    }

    // This test calls ``ConvertOptions.infoPlistFallbacks._unusedVersionForBackwardsCompatibility`` which is deprecated.
    // Deprecating the test silences the deprecation warning when running the tests. It doesn't skip the test.
    @available(*, deprecated) // We'll probably keep this deprecated property for a long time for backwards compatibility.
    func testVersionFlag() throws {
        let noFlagConvert = try Docc.Convert.parse([])
        XCTAssertEqual(noFlagConvert.infoPlistFallbacks._unusedVersionForBackwardsCompatibility, nil)

        let enabledFlagConvert = try Docc.Convert.parse(["--fallback-bundle-version", "1.2.3"])
        XCTAssertEqual(enabledFlagConvert.infoPlistFallbacks._unusedVersionForBackwardsCompatibility, "1.2.3")
    }
}
