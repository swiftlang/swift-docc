/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
@testable import SwiftDocCUtilities

import NIO
import NIOHTTP1

class DefaultRequestHandlerTests: XCTestCase {
    
    func testDefaultHandler() throws {
        let tempDir = try TempFolder(content: [
            TextFile(name: "index.html", utf8Content: "Hello!"),
        ], atRoot: createTemporaryDirectory(createDirectoryForLastPathComponent: false))

        // Default handler should be invoked for any non-asset path
        let request = makeRequestHead(path: "/random-path")
        let factory = DefaultRequestHandler(rootURL: tempDir.url)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        // Expected content
        XCTAssertEqual(response.body, "Hello!")
        
        // Expected content type
        XCTAssertEqual(response.head?.headers["Content-type"], ["text/html"])
        
        // No caching!
        XCTAssertEqual(response.head?.headers["ETag"], [])
        XCTAssertEqual(response.head?.headers["Pragma"], ["no-cache"])
        XCTAssertTrue(response.head?.headers["Cache-Control"].first?.contains("no-cache") ?? false)
    }
    
    func testDefaultHandlerForExistingPath() throws {
        let tempDir = try TempFolder(content: [
            TextFile(name: "index.html", utf8Content: "Hello!"),
            TextFile(name: "existing.html", utf8Content: "Existing!"),
        ], atRoot: createTemporaryDirectory(createDirectoryForLastPathComponent: false))

        // Default handler should handle even paths that do exist on disc
        let request = makeRequestHead(path: "/existing.html")
        let factory = DefaultRequestHandler(rootURL: tempDir.url)
        let response = try responseWithPipeline(request: request, handler: factory)
        
        // Expected content
        XCTAssertEqual(response.body, "Hello!")
    }

}
