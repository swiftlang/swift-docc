/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation

@testable import SwiftDocCUtilities
@testable import SwiftDocC
import SwiftDocCTestUtilities

@testable import NIO
@testable import NIOHTTP1

// rdar85046362
// Disabling this test due to accessing the temp directory and
// making network calls. The temp directories are accessible by all jobs on a
// bot, so they are subject to noise. Network calls are slow and can also be
// very noisy.
// class PreviewServerTests: XCTestCase {
class PreviewServerTests {

     func createTemporaryDirectory(
         fileManager: FileManager = .default
     ) throws -> URL {
         fatalError("This test is disabled by not conforming to XCTestCase. This helper is added here to make the code compile. This should never be called.")
     }
    
    public func createTempFolder(content: [File]) throws -> URL {
        fatalError("This test is disabled by not conforming to XCTestCase. This helper is added here to make the code compile. This should never be called.")
    }
    
    func testPreviewServerBeforeStarted() throws {
        // Create test content
        let tempFolderURL = try createTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "index"),
        ])

        let socketURL = try createTemporaryDirectory().appendingPathComponent("sock")
        
        // Run test server
        var log = LogHandle.none
        let server = try PreviewServer(contentURL: tempFolderURL, bindTo: .socket(path: socketURL.path), username: "username", password: "password", logHandle: &log)

        // Assert server starts
        let expectationStarted = AsynchronousExpectation(description: "Server before start")
        DispatchQueue.global().async {
            do {
                try server.start() {
                    expectationStarted.fulfill()
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        
        XCTAssertNotEqual(expectationStarted.wait(timeout: 5.0), .timedOut)
        
        do {
            try server.stop()
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    private func assertServer(socketPath: String, path: String, matchesContent expectedContent: String, file: StaticString = #file, line: UInt = #line) {
        let client = HTTPClient(to: .unixDomainSocket(path: socketPath), path: path)
        XCTAssertNoThrow(try client.connect(), file: (file), line: line)
        XCTAssertEqual(client.handler.statusCode, 200, file: (file), line: line)
        XCTAssertEqual(client.handler.response, expectedContent, file: (file), line: line)
    }

    private func assertServerError(socketPath: String, path: String, errorStatusCode: UInt, file: StaticString = #file, line: UInt = #line) {
        let client = HTTPClient(to: .unixDomainSocket(path: socketPath), path: path)
        XCTAssertNoThrow(try client.connect(), file: (file), line: line)
        XCTAssertNil(client.handler.response, file: (file), line: line)
        XCTAssertEqual(client.handler.statusCode, errorStatusCode, file: (file), line: line)
    }

    private func makeTempFolder() throws -> URL {
        // Create test content
        try createTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "index"),
            TextFile(name: "theme-settings.js", utf8Content: "java script content"),
            TextFile(name: "theme-settings.json", utf8Content: "JSON content"),
            TextFile(name: "favicon.ico", utf8Content: "icon content"),
            TextFile(name: "apple-logo.svg", utf8Content: "svg content"),
            Folder(name: "data", content: [
                TextFile(name: "test.js", utf8Content: "data content"),
            ]),
            Folder(name: "css", content: [
                TextFile(name: "test.css", utf8Content: "css content"),
            ]),
            Folder(name: "js", content: [
                TextFile(name: "test.js", utf8Content: "js content"),
            ]),
            Folder(name: "fonts", content: [
                TextFile(name: "test.tff", utf8Content: "fonts content"),
            ]),
            Folder(name: "images", content: [
                TextFile(name: "test.png", utf8Content: "images content"),
            ]),
            Folder(name: "img", content: [
                TextFile(name: "test.gif", utf8Content: "img content"),
            ]),
            Folder(name: "videos", content: [
                TextFile(name: "test.mov", utf8Content: "videos content"),
            ]),
            Folder(name: "downloads", content: [
                TextFile(name: "test.zip", utf8Content: "downloads content"),
            ])
        ])
    }
    
    func testPreviewServerPaths() throws {
        let tempFolderURL = try makeTempFolder()
        
        // Socket URL
        let socketURL = try createTemporaryDirectory().appendingPathComponent("sock")
        
        // Create the server
        var log = LogHandle.none
        let server = try PreviewServer(contentURL: tempFolderURL, bindTo: .socket(path: socketURL.path), username: "username", password: "password", logHandle: &log)

        // Start the server
        let expectationStarted = AsynchronousExpectation(description: "Server before start")
        DispatchQueue.global().async {
            do {
                try server.start() {
                    expectationStarted.fulfill()
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        XCTAssertNotEqual(expectationStarted.wait(timeout: 5.0), .timedOut)

        // Test server paths
        assertServer(socketPath: socketURL.path, path: "/", matchesContent: "index")
        assertServer(socketPath: socketURL.path, path: "/theme-settings.js", matchesContent: "java script content")
        assertServer(socketPath: socketURL.path, path: "/theme-settings.json", matchesContent: "JSON content")
        assertServer(socketPath: socketURL.path, path: "/favicon.ico", matchesContent: "icon content")
        assertServer(socketPath: socketURL.path, path: "/apple-logo.svg", matchesContent: "svg content")
        assertServer(socketPath: socketURL.path, path: "/data/test.js", matchesContent: "data content")
        assertServer(socketPath: socketURL.path, path: "/css/test.css", matchesContent: "css content")
        assertServer(socketPath: socketURL.path, path: "/js/test.js", matchesContent: "js content")
        assertServer(socketPath: socketURL.path, path: "/fonts/test.tff", matchesContent: "fonts content")
        assertServer(socketPath: socketURL.path, path: "/images/test.png", matchesContent: "images content")
        assertServer(socketPath: socketURL.path, path: "/img/test.gif", matchesContent: "img content")
        assertServer(socketPath: socketURL.path, path: "/videos/test.mov", matchesContent: "videos content")
        assertServer(socketPath: socketURL.path, path: "/downloads/test.zip", matchesContent: "downloads content")

        assertServerError(socketPath: socketURL.path, path: "/downloads/NOTFOUND.zip", errorStatusCode: 404)
        
        // Verify that the server stops serving content.
        XCTAssertNoThrow(try server.stop())

        let client = HTTPClient(to: .unixDomainSocket(path: socketURL.path), path: "/")
        XCTAssertThrowsError(try client.connect())
    }
    
    func testConcurrentRequests() throws {
        let tempFolderURL = try makeTempFolder()
        
        // Socket URL
        let socketURL = try createTemporaryDirectory().appendingPathComponent("sock")
        
        // Create the server
        var log = LogHandle.none
        let server = try PreviewServer(contentURL: tempFolderURL, bindTo: .socket(path: socketURL.path), username: "username", password: "password", logHandle: &log)

        // Start the server
        let expectationStarted = AsynchronousExpectation(description: "Server before start")
        DispatchQueue.global().async {
            do {
                try server.start() {
                    expectationStarted.fulfill()
                }
            } catch {
                XCTFail(error.localizedDescription)
            }
        }
        XCTAssertNotEqual(expectationStarted.wait(timeout: 5.0), .timedOut)
        
        // Make 5000 HTTP requests; 1000 concurrent batches x 5 requests
        DispatchQueue.concurrentPerform(iterations: 1000) { _ in
            assertServer(socketPath: socketURL.path, path: "/data/test.js", matchesContent: "data content")
            assertServer(socketPath: socketURL.path, path: "/css/test.css", matchesContent: "css content")
            assertServer(socketPath: socketURL.path, path: "/js/test.js", matchesContent: "js content")
            assertServer(socketPath: socketURL.path, path: "/fonts/test.tff", matchesContent: "fonts content")
            assertServerError(socketPath: socketURL.path, path: "/js/NotFound.js", errorStatusCode: 404)
        }
        XCTAssertNoThrow(try server.stop())
    }
    
    func testPreviewServerBindDescription() {
        let localhostBind = PreviewServer.Bind.localhost(port: 1234)
        XCTAssertEqual("\(localhostBind)", "localhost:1234")
        let socketBind = PreviewServer.Bind.socket(path: "/tmp/file.sock")
        XCTAssertEqual("\(socketBind)", "/tmp/file.sock")
    }
}
