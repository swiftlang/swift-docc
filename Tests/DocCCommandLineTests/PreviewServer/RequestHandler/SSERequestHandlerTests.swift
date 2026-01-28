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

import NIO
import NIOHTTP1

struct SSERequestHandlerTests {

    @Test
    func returnsCorrectHeaders() throws {
        let request = makeRequestHead(uri: SSERequestHandler.path)
        let factory = SSERequestHandler()
        let response = try responseWithPipeline(request: request, handler: factory)

        #expect(response.head?.status == .ok)
        #expect(response.head?.headers["Content-Type"] == ["text/event-stream"])
        #expect(response.head?.headers["Cache-Control"] == ["no-cache"])
        #expect(response.head?.headers["Connection"] == ["keep-alive"])
    }

    @Test
    func sendsInitialHeartbeat() throws {
        let request = makeRequestHead(uri: SSERequestHandler.path)
        let factory = SSERequestHandler()
        let response = try responseWithPipeline(request: request, handler: factory)

        #expect(response.body == ": connected\n\n")
    }

}
#endif
