/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import NIO
import NIOHTTP1

typealias RequestHandler = ((ChannelHandlerContext, HTTPRequestHead) throws -> Void)

/// A factory that creates a request handler.
///
/// Conforming types are factories creating specialized channel handlers. For example ``ErrorRequestHandler``.
protocol RequestHandlerFactory {
    func create<ChannelHandler: ChannelInboundHandler>(channelHandler: ChannelHandler) -> RequestHandler
        where ChannelHandler.OutboundOut == HTTPServerResponsePart
}
