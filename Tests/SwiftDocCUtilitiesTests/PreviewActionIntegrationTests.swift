/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class PreviewActionIntegrationTests: XCTestCase {
    func json(contentsOf url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        guard let result = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            XCTFail("Failed to load JSON from \(url.path)")
            return [:]
        }
        return result
    }
    
    private func createMinimalDocsBundle() -> Folder {
        let overviewURL = Bundle.module.url(
            forResource: "Overview", withExtension: "tutorial", subdirectory: "Test Resources")!
        let uncuratedArticleURL = Bundle.module.url(
            forResource: "UncuratedArticle", withExtension: "md", subdirectory: "Test Resources")!
        let imageURL = Bundle.module.url(
            forResource: "image", withExtension: "png", subdirectory: "Test Resources")!
        
        let symbolURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
            .appendingPathComponent("mykit-iOS.symbols.json")
         
        // Write source documentation bundle.
        let source = Folder(name: "unit-test.docc", content: [
            Folder(name: "Symbols", content: [
                CopyOfFile(original: symbolURL),
            ]),
            Folder(name: "Resources", content: [
                CopyOfFile(original: imageURL),
                CopyOfFile(original: overviewURL),
                CopyOfFile(original: uncuratedArticleURL),
            ]),
            InfoPlist(displayName: "TestBundle", identifier: "com.test.example")
        ])
        
        return source
    }
    
    private func createPreviewSetup(source: Folder) throws -> (sourceURL: URL, outputURL: URL, templateURL: URL) {
        // Source URL.
        let sourceURL = try source.write(inside: createTemporaryDirectory())
            
        // Output URL.
        let outputURL = try createTemporaryDirectory().appendingPathComponent(".docc-build")
        
        // HTML template URL.
        let htmlURL = Bundle.module.url(
            forResource: "Test Template", withExtension: nil, subdirectory: "Test Resources")!
            .appendingPathComponent("index.html")

        let template = Folder(name: "template", content: [
            CopyOfFile(original: htmlURL)
        ])
        let templateURL = try template.write(inside: createTemporaryDirectory())
        
        return (sourceURL: sourceURL, outputURL: outputURL, templateURL: templateURL)
    }
    
    /// Test the fix for <rdar://problem/48615392>.
    func testWatchRecoversAfterConversionErrors() throws {
        #if os(macOS)
        throw XCTSkip("This test is flaky rdar://90866510")
        
//        // Source files.
//        let source = createMinimalDocsBundle()
//        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: source)
//
//        let logStorage = LogHandle.LogStorage()
//        var logHandle = LogHandle.memory(logStorage)
//
//        let convertActionTempDirectory = try createTemporaryDirectory()
//        let createConvertAction = {
//            try ConvertAction(
//                documentationBundleURL: sourceURL,
//                outOfProcessResolver: nil,
//                analyze: false,
//                targetDirectory: outputURL,
//                htmlTemplateDirectory: templateURL,
//                emitDigest: false,
//                currentPlatforms: nil,
//                fileManager: FileManager.default,
//                temporaryDirectory: convertActionTempDirectory)
//        }
//
//        guard let preview = try? PreviewAction(
//                tlsCertificateKey: nil,
//                tlsCertificateChain: nil,
//                serverUsername: nil,
//                serverPassword: nil,
//                port: 8080, // We ignore this value when we set the `bindServerToSocketPath` property below.
//                createConvertAction: createConvertAction) else {
//            XCTFail("Could not create preview action from parameters")
//            return
//        }
//
//        let socketURL = try createTemporaryDirectory().appendingPathComponent("sock")
//        preview.bindServerToSocketPath = socketURL.path
//
//        // The technology output file URL
//        let convertedOverviewURL = outputURL
//            .appendingPathComponent("data")
//            .appendingPathComponent("tutorials")
//            .appendingPathComponent("Overview.json")
//
//        // Start watching the source and get the initial (successful) state.
//        do {
//            let logOutputExpectation = asyncLogExpectation(log: logStorage, description: "Did produce log output") { $0.contains("=======")  }
//
//            // Start the preview and keep it running for the asserts that follow inside this test.
//            DispatchQueue.global().async {
//                var action = preview as Action
//                do {
//                    let result = try action.perform(logHandle: logHandle)
//
//                    guard !result.problems.containsErrors else {
//                        throw ErrorsEncountered()
//                    }
//
//                    if !result.problems.isEmpty {
//                        print(result.problems.localizedDescription, to: &logHandle)
//                    }
//                } catch {
//                    XCTFail(error.localizedDescription)
//                }
//            }
//
//            wait(for: [logOutputExpectation], timeout: 20.0)
//
//            // Check the log output to confirm that expected informational
//            // text is printed
//            let logOutput = logStorage.text
//
//            // rdar://71318888
//            let expectedLogIntroductoryOutput = """
//                Input: \(sourceURL.path)
//                Template: \(templateURL.path)
//                """
//            XCTAssertTrue(logOutput.hasPrefix(expectedLogIntroductoryOutput), """
//                Missing expected input and template information in log/print output
//                """)
//
//            if let previewInfoStart = logOutput.range(of: "=====\n")?.upperBound,
//                let previewInfoEnd = logOutput[previewInfoStart...].range(of: "\n=====")?.lowerBound {
//                XCTAssertEqual(logOutput[previewInfoStart..<previewInfoEnd], """
//                Starting Local Preview Server
//                \t Address: http://localhost:8080/documentation/mykit
//                \t          http://localhost:8080/tutorials/overview
//                """)
//            } else {
//                XCTFail("Missing preview information in log/print output")
//            }
//
//            XCTAssertTrue(FileManager.default.fileExists(atPath: convertedOverviewURL.path, isDirectory: nil))
//        }
//
//        // Verify conversion result.
//        let json1 = try json(contentsOf: convertedOverviewURL)
//        guard let sections = json1["sections"] as? [[String: Any]],
//            let intro = sections.first( where: { $0["kind"] as? String == "hero" }),
//            let initialIntroTitle = intro["title"] as? String else {
//            XCTFail("Couldn't parse converted markdown")
//            return
//        }
//
//        XCTAssertEqual(initialIntroTitle, "Technology X")
//
//        let invalidJSONSymbolGraphURL = sourceURL.appendingPathComponent("invalid-incomplete-data.symbols.json")
//
//        // Start watching the source and detect failed conversion.
//        do {
//            let outputExpectation = asyncLogExpectation(log: logStorage, description: "Did produce output") { $0.contains("Compilation failed") }
//
//            // this is invalid JSON and will result in an error
//            try "{".write(to: invalidJSONSymbolGraphURL, atomically: true, encoding: .utf8)
//
//            // Wait for watch to produce output.
//            wait(for: [outputExpectation], timeout: 20.0)
//        }
//
//        // Start watching the source and detect recovery and successful conversion after a failure.
//        do {
//            let outputExpectation = asyncLogExpectation(log: logStorage, description: "Did finish conversion") { $0.contains("Done") }
//
//            try FileManager.default.removeItem(at: invalidJSONSymbolGraphURL)
//
//            // Wait for watch to produce output.
//            wait(for: [outputExpectation], timeout: 20.0)
//
//            // Check conversion result.
//            let finalJSON = try json(contentsOf: convertedOverviewURL)
//            guard let sections = finalJSON["sections"] as? [[String: Any]],
//                let intro = sections.first( where: { $0["kind"] as? String == "hero" }),
//                let finalIntroTitle = intro["title"] as? String else {
//                XCTFail("Couldn't parse converted markdown")
//                return
//            }
//            XCTAssertEqual(finalIntroTitle, "Technology X")
//        }
//
//        // Make sure to stop the preview process so it doesn't stay alive on the machine running the tests.
//        try preview.stop()
//
//        try FileManager.default.removeItem(at: sourceURL)
//        try FileManager.default.removeItem(at: outputURL)
//        try FileManager.default.removeItem(at: templateURL)
        #endif
    }
    
    class MemoryOutputChecker {
        init(storage: LogHandle.LogStorage, expectation: XCTestExpectation, condition: @escaping (String)->Bool) {
            self.storage = storage
            self.expectation = expectation
            self.condition = condition
        }
        var invalidated = false
        let storage: LogHandle.LogStorage
        let expectation: XCTestExpectation
        let condition: (String)->Bool
    }
    
    /// Helper class to fulfill an expectation when given condition is met.
    class OutputChecker {
        init(fileURL: URL, expectation: XCTestExpectation, condition: @escaping (String)->Bool) {
            self.url = fileURL
            self.expectation = expectation
            self.condition = condition
        }
        
        var url: URL
        let expectation: XCTestExpectation
        let condition: (String)->Bool
    }
    
    /// Check the contents of the log file for the expectation.
    func checkOutput(timer: Timer) {
        if let checker = timer.userInfo as? OutputChecker {
            if let data = try? Data(contentsOf: checker.url),
                let text = String(data: data, encoding: .utf8),
                checker.condition(text) {
                // Expectation is met.
                checker.expectation.fulfill()
            }
        }
        if let checker = timer.userInfo as? MemoryOutputChecker, !checker.invalidated {
            if checker.condition(checker.storage.text) {
                // Expectation is met.
                checker.invalidated = true
                checker.expectation.fulfill()
            }
        }
    }

    func testThrowsHumanFriendlyErrorWhenCannotStartServerOnAGivenPort() throws {
        // Binding an invalid address
        try assert(bindPort: -1, expectedErrorMessage: "Can't start the preview server on port -1")
    }
    
    func assert(bindPort: Int, expectedErrorMessage: String, file: StaticString = #file, line: UInt = #line) throws {
        #if os(macOS)
        // Source files.
        let source = createMinimalDocsBundle()
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: source)
        
        // A FileHandle to read action's output.
        let pipeURL = try createTemporaryDirectory().appendingPathComponent("pipe")
        try Data().write(to: pipeURL)
        let fileHandle = try FileHandle(forUpdating: pipeURL)
        defer { fileHandle.closeFile() }

        let workspace = DocumentationWorkspace()
        _ = try! DocumentationContext(dataProvider: workspace)

        let engine = DiagnosticEngine()

        let convertActionTempDirectory = try createTemporaryDirectory()
        let createConvertAction = {
            try ConvertAction(
                documentationBundleURL: sourceURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: outputURL,
                htmlTemplateDirectory: templateURL,
                emitDigest: false,
                currentPlatforms: nil,
                fileManager: FileManager.default,
                temporaryDirectory: convertActionTempDirectory,
                diagnosticEngine: engine)
        }
        
        guard let preview = try? PreviewAction(
                tlsCertificateKey: nil,
                tlsCertificateChain: nil,
                serverUsername: nil,
                serverPassword: nil,
                port: bindPort,
                createConvertAction: createConvertAction) else {
            XCTFail("Could not create preview action from parameters", file: file, line: line)
            return
        }

        // Start watching the source and get the initial (successful) state.
        do {
            // Wait for watch to produce output.
            let logOutputExpectation = expectation(description: "Did produce log output")
            let logChecker = OutputChecker(fileURL: pipeURL, expectation: logOutputExpectation) { output in
                return output.contains("=======")
            }
            let logTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(checkOutput), userInfo: logChecker, repeats: true)

            let erroredExpectation = expectation(description: "preview command failed with error")

            // Start the preview and keep it running for the asserts that follow inside this test.
            DispatchQueue.global().async {
                guard let result = try? preview.perform(logHandle: .file(fileHandle)) else {
                    XCTFail("Couldn't convert test bundle", file: file, line: line)
                    return
                }
                
                XCTAssertTrue(result.didEncounterError, "Did not find an error when running preview", file: file, line: line)
                XCTAssertNotNil(engine.problems.first(where: { problem -> Bool in
                    problem.diagnostic.localizedDescription.contains(expectedErrorMessage)
                }), "Didn't find expected error message '\(expectedErrorMessage)'", file: file, line: line)

                // Verify that the failed server is not added to the server list
                XCTAssertNil(servers[preview.serverIdentifier])

                // Verify that we've checked the error thrown.
                erroredExpectation.fulfill()
            }

            wait(for: [logOutputExpectation, erroredExpectation], timeout: 20.0)
            logTimer.invalidate()
        }
        try preview.stop()
        #endif
    }

    func testHumanErrorMessageForUnavailablePort() throws {
        #if os(macOS)
        // Source files.
        let source = createMinimalDocsBundle()
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: source)
        
        let logStorage = LogHandle.LogStorage()
        let logHandle = LogHandle.memory(logStorage)
        
        let convertActionTempDirectory = try createTemporaryDirectory()
        let createConvertAction = {
            try ConvertAction(
                documentationBundleURL: sourceURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: outputURL,
                htmlTemplateDirectory: templateURL,
                emitDigest: false,
                currentPlatforms: nil,
                fileManager: FileManager.default,
                temporaryDirectory: convertActionTempDirectory)
        }
        
        guard let preview = try? PreviewAction(
                tlsCertificateKey: nil,
                tlsCertificateChain: nil,
                serverUsername: nil,
                serverPassword: nil,
                port: 0, // Use port 0 to pick a random free port number
                createConvertAction: createConvertAction) else {
            XCTFail("Could not create preview action from parameters")
            return
        }

        // Start watching the source and get the initial (successful) state.
        do {
            // Wait for watch to produce output.
            let logOutputExpectation = asyncLogExpectation(log: logStorage, description: "Did produce log output") { $0.contains("=======") }

            // Start the preview and keep it running for the asserts that follow inside this test.
            DispatchQueue.global().async {
                guard let _ = try? preview.perform(logHandle: logHandle) else {
                    XCTFail("Couldn't convert test bundle")
                    return
                }
            }

            wait(for: [logOutputExpectation], timeout: 20.0)
        }
        
        // Verify the preview server is added to the list of servers
        XCTAssertNotNil(servers[preview.serverIdentifier])
        
        // We have one preview running on the given port
        let boundPort = try XCTUnwrap(servers[preview.serverIdentifier]?.channel.localAddress?.port)

        // Try to start another preview on the same port
        try assert(bindPort: boundPort, expectedErrorMessage: "Port \(boundPort) is not available at the moment, try a different port number")

        try preview.stop()
        
        // Verify the server is removed from the server list
        XCTAssertNil(servers[preview.serverIdentifier])
        
        try FileManager.default.removeItem(at: sourceURL)
        try FileManager.default.removeItem(at: outputURL)
        try FileManager.default.removeItem(at: templateURL)
        #endif
    }
    
    func testCancelsConversion() throws {
        #if os(macOS)

        // Source files.
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: createMinimalDocsBundle())
        
        let logStorage = LogHandle.LogStorage()
        var logHandle = LogHandle.memory(logStorage)

        var convertFuture: () -> Void = {}
        
        let convertActionTempDirectory = try createTemporaryDirectory()
        /// Create the convert action and store it
        let createConvertAction = { () -> ConvertAction in
            var convertAction = try ConvertAction(
                documentationBundleURL: sourceURL,
                outOfProcessResolver: nil,
                analyze: false,
                targetDirectory: outputURL,
                htmlTemplateDirectory: templateURL,
                emitDigest: false,
                currentPlatforms: nil,
                fileManager: FileManager.default,
                temporaryDirectory: convertActionTempDirectory)
                
            // Inject a future to control how long the conversion takes
            convertAction.willPerformFuture = convertFuture
            
            return convertAction
        }
        
        guard let preview = try? PreviewAction(
                tlsCertificateKey: nil,
                tlsCertificateChain: nil,
                serverUsername: nil,
                serverPassword: nil,
                port: 8080, // We ignore this value when we set the `bindServerToSocketPath` property below.
                createConvertAction: createConvertAction) else {
            XCTFail("Could not create preview action from parameters")
            return
        }

        let socketURL = try createTemporaryDirectory().appendingPathComponent("sock")
        preview.bindServerToSocketPath = socketURL.path
        
        // Start watching the source and get the initial (successful) state.
        do {
            let logOutputExpectation = asyncLogExpectation(log: logStorage, description: "Did produce log output") { $0.contains("=======") }
            
            // Start the preview and keep it running for the asserts that follow inside this test.
            DispatchQueue.global().async {
                var action = preview as Action
                do {
                    let result = try action.perform(logHandle: logHandle)

                    guard !result.problems.containsErrors else {
                        throw ErrorsEncountered()
                    }
                
                    if !result.problems.isEmpty {
                        print(result.problems.localizedDescription, to: &logHandle)
                    }
                } catch {
                    XCTFail(error.localizedDescription)
                }
            }

            wait(for: [logOutputExpectation], timeout: 20.0)

            // Bundle is now converted once.
            
            // Now trigger another conversion and cancel it.
            
            // Enable slow conversions so we have the chance to cancel the action
            convertFuture = { sleep(10) }
            
            // Expect that the first conversion has started
            let firstConversion = asyncLogExpectation(log: logStorage, description: "Trigger new conversion") { $0.contains("Source bundle was modified") }

            // Write one file to trigger a new conversion.
            try? "".write(to: sourceURL.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
            
            wait(for: [firstConversion], timeout: 20.0)

            // Expect that there will be a log about cancelling a running conversion.
            let reConvertOutputExpectation = asyncLogExpectation(log: logStorage, description: "Did re-convert bundle") { $0.contains("Conversion cancelled...") }

            // Write a second file to cancel the first conversion and trigger a new one.
            try? "".write(to: sourceURL.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
            
            // Wait for the conversions to complete
            wait(for: [reConvertOutputExpectation], timeout: 20.0)
        }

        // Make sure to stop the preview process so it doesn't stay alive on the machine running the tests.
        try preview.stop()
        
        try FileManager.default.removeItem(at: sourceURL)
        try FileManager.default.removeItem(at: outputURL)
        try FileManager.default.removeItem(at: templateURL)
        #endif
    }
    
    /// Returns an asynchronous expectation that checks a log for a given condition.
    func asyncLogExpectation(log: LogHandle.LogStorage, description: String, block: @escaping (String) -> Bool) -> XCTestExpectation {
        let checker = MemoryOutputChecker(storage: log, expectation: XCTestExpectation(description: description)) { output in
            return block(output)
        }

        _ = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { timer in
            if checker.condition(log.text) {
                timer.invalidate()
                checker.invalidated = true
                checker.expectation.fulfill()
            }
        })
        
        return checker.expectation
    }
    
    // MARK: -
    
    override static func setUp() {
        super.setUp()
        PreviewAction.allowConcurrentPreviews = true
    }
    
    override static func tearDown() {
        PreviewAction.allowConcurrentPreviews = false
        super.tearDown()
    }
}
