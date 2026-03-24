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

struct PreviewHTTPHandlerTests {
    /// Tests the three different responses we offer: static file, default, and error.
    @Test
    func handlesResponses() throws {
        let (fileSystem, folderURL) = try makeTestFileSystemWithFolder(containing: [
            TextFile(name: "index.html", utf8Content: "index"),
            Folder(name: "css", content: [
                TextFile(name: "test.css", utf8Content: "css"),
            ])
        ])

        let channel = EmbeddedChannel()
        let channelHandler = PreviewHTTPHandler(rootURL: folderURL, fileManager: fileSystem)

        let response = Response()
        
        try channel.pipeline.addHandler(response).wait()
        try channel.pipeline.addHandler(channelHandler).wait()

        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()

        // Request a page
        do {
            let request = makeRequestHead(uri: "/tutorials")
            try channel.writeInbound(HTTPServerRequestPart.head(request))
            try channel.writeInbound(HTTPServerRequestPart.end(nil))
            
            #expect(response.head?.status == .ok)
            #expect(response.body == "index")
        }

        // Request an asset
        do {
            let request = makeRequestHead(uri: "/css/test.css")
            try channel.writeInbound(HTTPServerRequestPart.head(request))
            try channel.writeInbound(HTTPServerRequestPart.end(nil))
            
            #expect(response.head?.status == .ok)
            #expect(response.body == "css")
        }

        // Not found error
        do {
            let request = makeRequestHead(uri: "/css/notfound.css")
            try channel.writeInbound(HTTPServerRequestPart.head(request))
            try channel.writeInbound(HTTPServerRequestPart.end(nil))
            
            #expect(response.head?.status == .notFound)
            #expect(response.body == "")
        }
        
        // Passed credentials when none required
        do {
            let request = makeRequestHead(uri: "/tutorials", headers: [("Authorization", "Basic \("USER:PASS".data(using: .utf8)!.base64EncodedString())")])
            try channel.writeInbound(HTTPServerRequestPart.head(request))
            try channel.writeInbound(HTTPServerRequestPart.end(nil))
            
            #expect(response.head?.status == .ok)
            #expect(response.body == "index")
        }
    }
}
#endif
