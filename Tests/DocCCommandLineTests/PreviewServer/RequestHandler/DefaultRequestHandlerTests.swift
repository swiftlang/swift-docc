/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
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

struct DefaultRequestHandlerTests {
    @Test
    func defaultHandlerServesIndexData() throws {
        let (fileSystem, folderURL) = try makeTestFileSystemWithFolder(containing: [
            TextFile(name: "index.html", utf8Content: "Hello!"),
        ])

        // Default handler should be invoked for any non-asset path
        let request = makeRequestHead(uri: "/random-path")
        let factory = DefaultRequestHandler(rootURL: folderURL, fileManager: fileSystem)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        #expect(response.body == "Hello!")
        #expect(response.head?.headers["Content-type"] == ["text/html"])
        
        // The preview server sends no-cache headers so that the developer doesn't get stale previews while iterating on their documentation.
        #expect(response.head?.headers["ETag"] == [])
        #expect(response.head?.headers["Pragma"] == ["no-cache"])
        #expect(response.head?.headers["Cache-Control"].first?.contains("no-cache") == true)
    }
    
    @Test
    func defaultHandlerServerIndexDataEvenForExistingPath() throws {
        let (fileSystem, folderURL) = try makeTestFileSystemWithFolder(containing: [
            TextFile(name: "index.html", utf8Content: "Hello!"),
            TextFile(name: "existing.html", utf8Content: "Existing!"),
        ])

        // Default handler should handle even paths that do exist on disc
        let request = makeRequestHead(uri: "/existing.html")
        let factory = DefaultRequestHandler(rootURL: folderURL, fileManager: fileSystem)
        let response = try responseWithPipeline(request: request, handler: factory)

        #expect(response.body == "Hello!")
    }
}
#endif
