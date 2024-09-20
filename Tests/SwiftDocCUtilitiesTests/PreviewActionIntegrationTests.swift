/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities
import SwiftDocCTestUtilities

class PreviewActionIntegrationTests: XCTestCase {
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
                port: bindPort,
                createConvertAction: createConvertAction) else {
            XCTFail("Could not create preview action from parameters", file: file, line: line)
            return
        }
        defer {
            do {
                try preview.stop()
            } catch {
                XCTFail("Failed to stop preview server", file: file, line: line)
            }
        }
        // Start watching the source and get the initial (successful) state.
        do {
            let engine = preview.convertAction.diagnosticEngine
            
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
                    DiagnosticConsoleWriter.formattedDescription(for: problem.diagnostic).contains(expectedErrorMessage)
                }), "Didn't find expected error message '\(expectedErrorMessage)'", file: file, line: line)

                // Verify that the failed server is not added to the server list
                XCTAssertNil(servers[preview.serverIdentifier])

                // Verify that we've checked the error thrown.
                erroredExpectation.fulfill()
            }

            wait(for: [logOutputExpectation, erroredExpectation], timeout: 20.0)
            logTimer.invalidate()
        }
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
                        print(DiagnosticConsoleWriter.formattedDescription(for: result.problems), to: &logHandle)
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
#endif
