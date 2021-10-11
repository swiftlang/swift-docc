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

/// A full testing http client that requests a given path on a given destination - either host or socket
/// and records the response.
final class HTTPClient {
    
    /// A handler to make a GET request and store the response.
    final class HTTPGetHandler: ChannelInboundHandler {
        public typealias InboundIn = HTTPClientResponsePart
        public typealias OutboundOut = HTTPClientRequestPart
        
        let path: String
        init(path: String) {
            self.path = path
        }
        
        var response: String?
        var statusCode: UInt = 0
        
        public func channelActive(context: ChannelHandlerContext) {
            let requestHead = HTTPRequestHead(version: HTTPVersion(major: 1, minor: 1), method: .GET, uri: path)
            
            context.write(self.wrapOutboundOut(.head(requestHead)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(ByteBuffer.init()))), promise: nil)
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
        }

        public func channelRead(context: ChannelHandlerContext, data: NIOAny) {

            let clientResponse = self.unwrapInboundIn(data)
            
            switch clientResponse {
            case .head(let responseHead):
                statusCode = responseHead.status.code
            case .body(let byteBuffer):
                response = String(buffer: byteBuffer)
            case .end:
                context.close(promise: nil)
            }
        }

        public func errorCaught(context: ChannelHandlerContext, error: Error) {
            context.close(promise: nil)
        }
    }
    
    enum Bind {
        case ip(host: String, port: Int)
        case unixDomainSocket(path: String)
    }

    let group: MultiThreadedEventLoopGroup
    let to: Bind
    let handler: HTTPGetHandler
    
    init(to: Bind, path: String) {
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.to = to
        self.handler = HTTPGetHandler(path: path)
    }
    
    /// Makes a GET request and waits until it gets a response.
    func connect() throws {
        let handler = self.handler
        
        let bootstrap = ClientBootstrap(group: group)
            .channelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .channelInitializer { channel in
                channel.pipeline.addHTTPClientHandlers(position: .first,
                                                       leftOverBytesStrategy: .fireError).flatMap {
                                                        channel.pipeline.addHandler(handler)
                }
            }

        let channel: Channel
        switch to {
        case .ip(let host, let port):
            channel = try bootstrap.connect(host: host, port: port).wait()
        case .unixDomainSocket(let path):
            channel = try bootstrap.connect(unixDomainSocketPath: path).wait()
        }
        try channel.closeFuture.wait()
    }
    
    deinit {
        try? group.syncShutdownGracefully()
    }
}
