/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import XCTest
@testable import SwiftDocC
@testable import CommandLine
import TestUtilities

class PreviewActionIntegrationTests: XCTestCase {
    private func createMinimalDocsBundle() -> Folder {
        let overviewURL = Bundle.module.url(
            forResource: "Overview", withExtension: "tutorial", subdirectory: "Test Resources")!
        let uncuratedArticleURL = Bundle.module.url(
            forResource: "UncuratedArticle", withExtension: "md", subdirectory: "Test Resources")!
        let imageURL = Bundle.module.url(
            forResource: "image", withExtension: "png", subdirectory: "Test Resources")!
        
        let symbolURL = Bundle.module.url(
            forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
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
    
    func testWatchRecoversAfterConversionErrors() async throws {
        #if os(macOS)
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: createMinimalDocsBundle())
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: templateURL)
        }
        
        // A FileHandle to read action's output.
        let pipeURL = try createTemporaryDirectory().appendingPathComponent("pipe")
        try Data().write(to: pipeURL)
        let fileHandle = try FileHandle(forUpdating: pipeURL)
        defer { fileHandle.closeFile() }

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
        
        let preview = try PreviewAction(
            port: 8080, // We ignore this value when we set the `bindServerToSocketPath` property below.
            createConvertAction: createConvertAction
        )
        defer {
            try? preview.stop()
        }
        
        preview.bindServerToSocketPath = try createTemporaryTestSocketPath()
        
        let logStorage = LogHandle.LogStorage()

        // The technology output file URL
        let convertedOverviewURL = outputURL
            .appendingPathComponent("data")
            .appendingPathComponent("tutorials")
            .appendingPathComponent("Overview.json")
        
        // Start watching the source and get the initial (successful) state.
        do {
            let didStartServerExpectation = asyncLogExpectation(log: logStorage, description: "Did start the preview server", expectedText: "=======")
            
            // Start the preview and keep it running for the asserts that follow inside this test.
            Task {
                var logHandle = LogHandle.memory(logStorage)
                let result = try await preview.perform(logHandle: &logHandle)
                
                guard !result.problems.containsErrors else {
                    throw ErrorsEncountered()
                }
            }
            
            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didStartServerExpectation], timeout: 20.0)
            
            // Check the log output to confirm that expected informational text is printed
            let logOutput = logStorage.text
            
            let expectedLogIntroductoryOutput = """
            Input: \(sourceURL.path)
            Template: \(templateURL.path)
            """
            XCTAssertTrue(logOutput.hasPrefix(expectedLogIntroductoryOutput), """
            Missing expected input and template information in log/print output
            """)
            
            if let previewInfoStart = logOutput.range(of: "=====\n")?.upperBound,
               let previewInfoEnd = logOutput[previewInfoStart...].range(of: "\n=====")?.lowerBound {
                XCTAssertEqual(logOutput[previewInfoStart..<previewInfoEnd], """
                Starting Local Preview Server
                \t Address: http://localhost:8080/documentation/mykit
                \t          http://localhost:8080/tutorials/overview
                """)
            } else {
                XCTFail("Missing preview information in log/print output")
            }
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: convertedOverviewURL.path, isDirectory: nil))
        }

        // Verify conversion result.
        let overview = try JSONDecoder().decode(RenderNode.self, from: Data(contentsOf: convertedOverviewURL))
        let introSection = try XCTUnwrap(overview.sections.first(where: { $0.kind == .hero }) as? IntroRenderSection)
        XCTAssertEqual(introSection.title, "Technology X")

        let invalidJSONSymbolGraphURL = sourceURL.appendingPathComponent("invalid-incomplete-data.symbols.json")

        // Start watching the source and detect failed conversion.
        do {
            let didFailRebuiltExpectation = asyncLogExpectation(log: logStorage, description: "Did notice changed input and failed rebuild", expectedText: "Compilation failed")

            // this is invalid JSON and will result in an error
            try "{".write(to: invalidJSONSymbolGraphURL, atomically: true, encoding: .utf8)

            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didFailRebuiltExpectation], timeout: 20.0)
        }

        // Start watching the source and detect recovery and successful conversion after a failure.
        do {
            let didSuccessfullyRebuiltExpectation = asyncLogExpectation(log: logStorage, description: "Did notice changed input (again) and finished rebuild", expectedText: "Done")

            try FileManager.default.removeItem(at: invalidJSONSymbolGraphURL)

            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didSuccessfullyRebuiltExpectation], timeout: 20.0)

            // Check conversion result.
            let overview = try JSONDecoder().decode(RenderNode.self, from: Data(contentsOf: convertedOverviewURL))
            let introSection = try XCTUnwrap(overview.sections.first(where: { $0.kind == .hero }) as? IntroRenderSection)
            XCTAssertEqual(introSection.title, "Technology X")
        }
        #endif
    }
    
    func testThrowsHumanFriendlyErrorWhenCannotStartServerOnAGivenPort() async throws {
        // Binding an invalid address
        try await assert(bindPort: -1, expectedErrorMessage: "Can't start the preview server on port -1")
    }
    
    func assert(bindPort: Int, expectedErrorMessage: String, file: StaticString = #filePath, line: UInt = #line) async throws {
        #if os(macOS)
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: createMinimalDocsBundle())
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: templateURL)
        }
        
        // A FileHandle to read action's output.
        let pipeURL = try createTemporaryDirectory().appendingPathComponent("pipe")
        try Data().write(to: pipeURL)
        let fileHandle = try FileHandle(forUpdating: pipeURL)
        defer { fileHandle.closeFile() }

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
        
        let preview = try PreviewAction(
            port: bindPort,
            createConvertAction: createConvertAction
        )
        defer {
            try? preview.stop()
        }
        
        // Build documentation the first time, start the preview server, and start watching the inputs and for changes.
        do {
            let didStartServerExpectation = asyncLogExpectation(url: pipeURL, description: "Did start the preview server", expectedText: "=======")
            let didEncounterErrorExpectation = expectation(description: "preview command failed with error")

            // Start the preview and keep it running for the asserts that follow inside this test.
            Task {
                var logHandle = LogHandle.file(fileHandle)
                let result = try await preview.perform(logHandle: &logHandle)

                XCTAssertTrue(result.didEncounterError, "Did not find an error when running preview", file: file, line: line)
                XCTAssertNotNil(preview.convertAction.diagnosticEngine.problems.first(where: { problem -> Bool in
                    DiagnosticConsoleWriter.formattedDescription(for: problem.diagnostic).contains(expectedErrorMessage)
                }), "Didn't find expected error message '\(expectedErrorMessage)'", file: file, line: line)

                // Verify that the failed server is not added to the server list
                XCTAssertNil(servers[preview.serverIdentifier])

                // Verify that we've checked the error thrown.
                didEncounterErrorExpectation.fulfill()
            }

            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didStartServerExpectation, didEncounterErrorExpectation], timeout: 20.0)
        }
        #endif
    }

    func testHumanErrorMessageForUnavailablePort() async throws {
        #if os(macOS)
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: createMinimalDocsBundle())
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: templateURL)
        }
        
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
        
        let preview = try PreviewAction(
            port: 0, // Use port 0 to pick a random free port number
            createConvertAction: createConvertAction
        )

        // Build documentation the first time, start the preview server, and start watching the inputs and for changes.
        do {
            let logStorage = LogHandle.LogStorage()
            let didStartServerExpectation = asyncLogExpectation(log: logStorage, description: "Did start the preview server", expectedText: "=======")
            
            // Start the preview and keep it running for the asserts that follow inside this test.
            Task {
                var logHandle = LogHandle.memory(logStorage)
                _ = try await preview.perform(logHandle: &logHandle)
            }
            
            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didStartServerExpectation], timeout: 20.0)
        }
        
        // Verify the preview server is added to the list of servers
        XCTAssertNotNil(servers[preview.serverIdentifier])
        
        // We have one preview running on the given port
        let boundPort = try XCTUnwrap(servers[preview.serverIdentifier]?.channel.localAddress?.port)

        // Try to start another preview on the same port
        try await assert(bindPort: boundPort, expectedErrorMessage: "Port \(boundPort) is not available at the moment, try a different port number")

        try preview.stop()
        
        // Verify the server is removed from the server list
        XCTAssertNil(servers[preview.serverIdentifier])
        #endif
    }
    
    func testCancelsConversion() async throws {
        #if os(macOS)
        let (sourceURL, outputURL, templateURL) = try createPreviewSetup(source: createMinimalDocsBundle())
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
            try? FileManager.default.removeItem(at: outputURL)
            try? FileManager.default.removeItem(at: templateURL)
        }
        
        // This variable is captured by the `createConvertAction` closure and modified later in the test.
        var extraTestWork: () async -> Void = {}
        
        let convertActionTempDirectory = try createTemporaryDirectory()
        // Create the convert action and store it
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
                
            // Inject extra "work" to slow dow the documentation build so that the directory monitor has time to cancel it.
            convertAction._extraTestWork = extraTestWork
            
            return convertAction
        }
        
        let preview = try PreviewAction(
            port: 8080, // We ignore this value when we set the `bindServerToSocketPath` property below.
            createConvertAction: createConvertAction
        )

        defer {
            // Make sure to stop the preview process so it doesn't stay alive on the machine running the tests.
            try? preview.stop()
        }
        
        preview.bindServerToSocketPath = try createTemporaryTestSocketPath()
        
        let logStorage = LogHandle.LogStorage()
        // Start watching the source and get the initial (successful) state.
        do {
            let didStartServerExpectation = asyncLogExpectation(log: logStorage, description: "Did start the preview server", expectedText: "=======")
            
            // Start the preview and keep it running for the asserts that follow inside this test.
            Task {
                var logHandle = LogHandle.memory(logStorage)
                let result = try await preview.perform(logHandle: &logHandle)
                
                guard !result.problems.containsErrors else {
                    throw ErrorsEncountered()
                }
            }
            
            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [didStartServerExpectation], timeout: 20.0)
        }
        
        // At this point the documentation is converted once and the server and directory monitor is running.
        
        // Artificially slow down the remaining conversions so that the directory monitor (which has a 1 second debounce)
        // has a chance to cancel and restart the conversion.
        extraTestWork = {
            // The test won't wait the full 10 seconds.
            // The conversion (including this extra work) will be cancelled as soon as the directory monitor notices the change.
            try? await Task.sleep(for: .seconds(10))
        }
        
        // Modify a file in the catalog and wait for the preview server to notice the change and start rebuilding the documentation.
        do {
            let expectation = asyncLogExpectation(log: logStorage, description: "Did notice changed input and started rebuilding", expectedText: "Source bundle was modified")
            
            // Modify a file in the catalog to trigger a rebuild.
            try? "".write(to: sourceURL.appendingPathComponent("file1.txt"), atomically: true, encoding: .utf8)
            
            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [expectation], timeout: 20.0)
        }
        
        // Modify another file to cancel the first rebuild (triggered by the first modification above) and wait for the preview
        // server to notice the change and cancel the in-progress rebuild.
        do {
            let expectation = asyncLogExpectation(log: logStorage, description: "Did notice changed input again and cancelled the first rebuild", expectedText: "Conversion cancelled...")
            
            // Modify a file in the catalog to trigger a rebuild.
            try? "".write(to: sourceURL.appendingPathComponent("file2.txt"), atomically: true, encoding: .utf8)
            
            // This should only take 1.5 seconds (1 second for the directory monitor debounce and 0.5 seconds for the expectation poll interval)
            await fulfillment(of: [expectation], timeout: 20.0)
            // This assertion is always true if the expectation was fulfilled. However, in the past this expectation has sometimes (but very rarely) failed.
            // If that happens we want to print the full preview action log to help investigate what went wrong.
            XCTAssert(logStorage.text.contains("Conversion cancelled..."),
                      """
                      PreviewAction log output doesn't contain 'Conversion cancelled...'.
                      Full log output from the preview action that ran in this test (to investigate the issue):
                      --------------------------------------------------
                      \(logStorage.text)
                      --------------------------------------------------
                      """)
        }
        
        #endif
    }
    
    // MARK: Log output expectations
    
    private func asyncLogExpectation(url: URL, description: String, expectedText: String) -> XCTestExpectation {
        _asyncLogExpectation(text: {
            (try? String(data: Data(contentsOf: url), encoding: .utf8)) ?? ""
        }, description: description, expectedText: expectedText)
    }
    
    private func asyncLogExpectation(log: LogHandle.LogStorage, description: String, expectedText: String) -> XCTestExpectation {
        _asyncLogExpectation(text: { log.text }, description: description, expectedText: expectedText)
    }
    
    private func _asyncLogExpectation(text: @escaping () -> String, description: String, expectedText: String) -> XCTestExpectation {
        let expectation = XCTestExpectation(description: description)
        
        Task {
            // Poll every 0.5 seconds until the expectation contains the expected text.
            while true {
                // Yield for 0.5 seconds
                do {
                    try await Task.sleep(for: .seconds(0.5))
                } catch {
                    return // End the task by exiting if task was cancelled
                }
                
                if text().contains(expectedText) {
                    expectation.fulfill()
                    return // End the task by exiting when the expectation is fulfilled.
                }
            }
        }
        
        return expectation
    }
    
    // MARK: -
    
    private func createTemporaryTestSocketPath() throws -> String {
        // The unix domain socket paths have a character limit that we need to stay under.
        
        func isShortEnoughUnixDomainSocket(_ url: URL) -> Bool {
            url.path.utf8.count <= 103
        }
        
        // Prefer a temporary socket URL that's relative to the unit test bundle location if possible
        let bundleRelativeSocketURL = try createTemporaryDirectory().appendingPathComponent("s", isDirectory: false)
        if isShortEnoughUnixDomainSocket(bundleRelativeSocketURL) {
            return bundleRelativeSocketURL.path
        }
        
        // If that URL was to long, try a temporary socket URL in the user's shared temporary directory.
        // The added "doc" and UUID components should be sufficient to avoid collisions with other tests or other processes.
        
        let tempDir = URL(fileURLWithPath: Foundation.NSTemporaryDirectory())
            .appendingPathComponent("docc", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        
        let socketURL = tempDir.appendingPathComponent("s", isDirectory: false)
        
        // If we couldn't create short enough socket path, skip the tests rather than fail them to avoid flakiness in the CI.
        // The current implementation _should_ result in a path that's around 92 characters long, so the 11 character headroom
        // should cover some amount of hypothetical changes to the `NSTemporaryDirectory` length and the `UUID().uuidString` length.
        try XCTSkipIf(!isShortEnoughUnixDomainSocket(socketURL),
                      "Temporary socket path \(socketURL.path.singleQuoted) is too long (\(socketURL.path.utf8.count) character) to start a preview server.")
        
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        return socketURL.path
    }
    
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
