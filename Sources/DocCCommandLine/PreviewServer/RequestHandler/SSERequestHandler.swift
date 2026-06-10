/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import NIO
import NIOHTTP1

/// A request handler that establishes a Server-Sent Events connection for live reload.
struct SSERequestHandler: RequestHandlerFactory {
    /// The endpoint path for live reload SSE connections.
    static let path = "/__docc-live-reload__"

    func create<ChannelHandler: ChannelInboundHandler>(
        channelHandler: ChannelHandler
    ) -> RequestHandler where ChannelHandler.OutboundOut == HTTPServerResponsePart {
        return { context, head in
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/event-stream")
            headers.add(name: "Cache-Control", value: "no-cache")
            headers.add(name: "Connection", value: "keep-alive")

            let responseHead = HTTPResponseHead(
                matchingRequestHead: head,
                status: .ok,
                headers: headers
            )
            context.write(channelHandler.wrapOutboundOut(.head(responseHead)), promise: nil)

            // Send initial comment to confirm connection is established
            var buffer = context.channel.allocator.buffer(capacity: 16)
            buffer.writeString(": connected\n\n")
            context.write(channelHandler.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.flush()

            // Register this channel for reload notifications
            LiveReloadClients.shared.register(context.channel)

            // Connection stays open - no .end is sent
        }
    }
}
#endif
