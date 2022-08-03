/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import NIO
import NIOHTTP1
import XCTest
@testable import SwiftDocCUtilities

/// Makes a request head part with the given URI and headers.
func makeRequestHead(uri: String, headers: [(String, String)]? = nil) -> HTTPRequestHead {
    var head = HTTPRequestHead(version: .init(major: 1, minor: 1), method: .GET, uri: uri)
    if let headers = headers {
        for header in headers {
            head.headers.add(name: header.0, value: header.1)
        }
    }
    return head
}

/// A testing handler that, when gets a request,
/// triggers a predefined handler with a predefined request head.
final class MockHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    let requestHead: HTTPRequestHead
    let requestHandler: RequestHandlerFactory
    
    var requestError: RequestError?
    
    init(requestHead: HTTPRequestHead, requestHandler: RequestHandlerFactory) {
        self.requestHead = requestHead
        self.requestHandler = requestHandler
    }
    
    /// The received request doesn't matter - we always give the handler
    /// the preset request head.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        switch unwrapInboundIn(data) {
        case .end:
            // Trigger the preset handler
            let handler = requestHandler.create(channelHandler: self)
            do {
                try handler(context, requestHead)
            } catch let error as RequestError {
                requestError = error
            } catch { }
            context.flush()
        default: return
        }
    }
}

/// A testing channel handler that records the written response head, body, and error if any.
final class Response: ChannelOutboundHandler {
    typealias OutboundIn = HTTPServerResponsePart
    
    var head: HTTPResponseHead?
    var body: String?
    
    var requestError: RequestError?
    
    func write(context: ChannelHandlerContext, data: NIOAny, promise: EventLoopPromise<Void>?) {
        switch unwrapOutboundIn(data) {
        case .head(let head):
            self.head = head
        case .body(let data):
            switch data {
            case .byteBuffer(let buffer):
                self.body = buffer.getString(at: 0, length: buffer.writerIndex)
            default: break
            }
        default: break
        }
        context.write(data, promise: promise)
    }
}

/// Builds up a local host server channel pipeline, fire the preset request and returns the response.
func responseWithPipeline(request: HTTPRequestHead, handler factory: RequestHandlerFactory, file: StaticString = #file, line: UInt = #line) throws -> Response {
    let channel = EmbeddedChannel()
    let channelHandler = MockHandler(requestHead: request, requestHandler: factory)

    let response = Response()
    
    XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPResponseEncoder()).wait(), file: (file), line: line)
    XCTAssertNoThrow(try channel.pipeline.addHandler(response).wait(), file: (file), line: line)
    XCTAssertNoThrow(try channel.pipeline.addHandler(channelHandler).wait(), file: (file), line: line)
    XCTAssertNoThrow(try channel.pipeline.addHandler(HTTPServerPipelineHandler()).wait(), file: (file), line: line)

    XCTAssertNoThrow(try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait(), file: (file), line: line)

    XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.head(request)), file: (file), line: line)
    XCTAssertNoThrow(try channel.writeInbound(HTTPServerRequestPart.end(nil)), file: (file), line: line)

    response.requestError = channelHandler.requestError
    return response
}
