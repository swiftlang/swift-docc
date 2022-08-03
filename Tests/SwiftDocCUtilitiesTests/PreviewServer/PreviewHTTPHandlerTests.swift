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
import SwiftDocCTestUtilities

import NIO
import NIOHTTP1

class PreviewHTTPHandlerTests: XCTestCase {
    let fileIO = NonBlockingFileIO(threadPool: NIOThreadPool(numberOfThreads: 2))

    /// Tests the three different responses we offer: static file, default, and error.
    func testPreviewHandler() throws {
        let tempFolderURL = try createTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "index"),
            Folder(name: "css", content: [
                TextFile(name: "test.css", utf8Content: "css"),
            ])
        ])

        let channel = EmbeddedChannel()
        let channelHandler = PreviewHTTPHandler(fileIO: fileIO, rootURL: tempFolderURL)

        let response = Response()
        
        XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPResponseEncoder()).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(response).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(channelHandler).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPServerPipelineHandler()).wait())

        XCTAssertNoThrow(try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait())

        // Request a page
        do {
            let request = makeRequestHead(uri: "/tutorials")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .ok)
            XCTAssertEqual(response.body, "index")
        }

        // Request an asset
        do {
            let request = makeRequestHead(uri: "/css/test.css")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .ok)
            XCTAssertEqual(response.body, "css")
        }

        // Not found error
        do {
            let request = makeRequestHead(uri: "/css/notfound.css")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .notFound)
            XCTAssertEqual(response.body, "")
        }
        
        // Passed credentials when none required
        do {
            let request = makeRequestHead(uri: "/tutorials", headers: [("Authorization", "Basic \("USER:PASS".data(using: .utf8)!.base64EncodedString())")])
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .ok)
            XCTAssertEqual(response.body, "index")
        }
    }
    
    func testPreviewAuthHandler() throws {
        let tempFolderURL = try createTempFolder(content: [
            TextFile(name: "index.html", utf8Content: "index"),
            Folder(name: "css", content: [
                TextFile(name: "test.css", utf8Content: "css"),
            ])
        ])

        let channel = EmbeddedChannel()
        defer {
            // Close the test channel, ignore any leftovers
            _ = try? channel.finish()
        }
        
        let channelHandler = PreviewHTTPHandler(fileIO: fileIO, rootURL: tempFolderURL, credentials: (user: "user", pass: "pass"))

        let response = Response()
        
        XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPResponseEncoder()).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(response).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(channelHandler).wait())
        XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPServerPipelineHandler()).wait())

        XCTAssertNoThrow(try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait())

        // Request page without credentials
        do {
            let request = makeRequestHead(uri: "/tutorials")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .unauthorized)
            XCTAssertEqual(response.body, "")
        }

        // Request asset without credentials, e.g. verify we authorize before serving content
        do {
            let request = makeRequestHead(uri: "/css/test.css")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .unauthorized)
            XCTAssertEqual(response.body, "")
        }

        // Request error without credentials, e.g. verify we authorize before error handler
        do {
            let request = makeRequestHead(uri: "/css/notfound.css")
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .unauthorized)
            XCTAssertEqual(response.body, "")
        }

        // Request with valid credentials
        do {
            let request = makeRequestHead(uri: "/tutorials", headers: [("Authorization", "Basic \("user:pass".data(using: .utf8)!.base64EncodedString())")])
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .ok)
            XCTAssertEqual(response.body, "index")
        }

        // Request error with valid credentials
        do {
            let request = makeRequestHead(uri: "/css/notfound.css", headers: [("Authorization", "Basic \("user:pass".data(using: .utf8)!.base64EncodedString())")])
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .notFound)
            XCTAssertEqual(response.body, "")
        }

        // Request with invalid credentials
        do {
            let request = makeRequestHead(uri: "/tutorials", headers: [("Authorization", "Basic \("USER:PASS".data(using: .utf8)!.base64EncodedString())")])
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)))
            XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)))
            
            XCTAssertEqual(response.head?.status, .forbidden)
            XCTAssertEqual(response.body, "")
        }
    }
}
