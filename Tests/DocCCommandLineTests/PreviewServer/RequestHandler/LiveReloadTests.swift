/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import Foundation
import Testing
@testable import DocCCommandLine
import DocCTestUtilities

import NIO
import NIOHTTP1

/// Creates a temporary folder with the given content and returns its URL.
private func makeTempFolder(content: [any File]) throws -> URL {
    let tempDir = URL(fileURLWithPath: Foundation.NSTemporaryDirectory())
        .appendingPathComponent("LiveReloadTests-\(ProcessInfo.processInfo.globallyUniqueString)")
    let folder = Folder(name: tempDir.lastPathComponent, content: content)
    try folder.write(to: tempDir)
    return tempDir
}

struct LiveReloadTests {

    @Test
    func scriptNotInjectedByDefault() throws {
        let tempFolderURL = try makeTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "<html><body>Hello!</body></html>"),
        ])
        defer { try? FileManager.default.removeItem(at: tempFolderURL) }

        let request = makeRequestHead(uri: "/")
        let factory = DefaultRequestHandler(rootURL: tempFolderURL)
        let response = try responseWithPipeline(request: request, handler: factory)

        #expect(response.body == "<html><body>Hello!</body></html>")
        #expect(response.body?.contains("__docc-live-reload__") == false)
    }

    @Test
    func scriptInjectedWhenEnabled() throws {
        let tempFolderURL = try makeTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "<html><body>Hello!</body></html>"),
        ])
        defer { try? FileManager.default.removeItem(at: tempFolderURL) }

        let request = makeRequestHead(uri: "/")
        var factory = DefaultRequestHandler(rootURL: tempFolderURL)
        factory.injectLiveReload = true
        let response = try responseWithPipeline(request: request, handler: factory)

        let body = try #require(response.body)
        #expect(body.contains("EventSource"))
        #expect(body.contains("__docc-live-reload__"))
        #expect(body.contains("</body>"))

        // Verify the script comes before the closing body tag
        let scriptRange = try #require(body.range(of: "EventSource"))
        let bodyEndRange = try #require(body.range(of: "</body>"))
        #expect(scriptRange.lowerBound < bodyEndRange.lowerBound)
    }

    @Test
    func scriptNotInjectedWithoutBodyTag() throws {
        let tempFolderURL = try makeTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "<html>No body tag here</html>"),
        ])
        defer { try? FileManager.default.removeItem(at: tempFolderURL) }

        let request = makeRequestHead(uri: "/")
        var factory = DefaultRequestHandler(rootURL: tempFolderURL)
        factory.injectLiveReload = true
        let response = try responseWithPipeline(request: request, handler: factory)

        #expect(response.body == "<html>No body tag here</html>")
        #expect(response.body?.contains("EventSource") == false)
    }

}
#endif
