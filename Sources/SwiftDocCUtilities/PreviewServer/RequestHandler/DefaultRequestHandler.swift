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

/// A request handler that serves the default app page to clients.
///
/// The handler returns the contents of `index.html` in the root folder,
/// regardless of the requested URL. This behavior is suitable for
/// serving single-page web apps that display dynamic
/// content, depending on the requested URL path or query parameters.
struct DefaultRequestHandler: RequestHandlerFactory {
    
    /// The root of the documentation to serve.
    let rootURL: URL
    
    func create<ChannelHandler: ChannelInboundHandler>(channelHandler: ChannelHandler) -> RequestHandler
        where ChannelHandler.OutboundOut == HTTPServerResponsePart {
        
        return { context, head in
            let response = try Data(contentsOf: self.rootURL.appendingPathComponent("index.html"))
            
            var content = context.channel.allocator.buffer(capacity: response.count)
            content.writeBytes(response)
            
            var headers = HTTPHeaders()
            headers.add(name: "Content-Length", value: "\(response.count)")
            headers.add(name: "Content-Type", value: "text/html")
            
            // No caching of live preview
            headers.add(name: "Cache-Control", value: "no-store, no-cache, must-revalidate, post-check=0, pre-check=0")
            headers.add(name: "Pragma", value: "no-cache")

            let responseHead = HTTPResponseHead(matchingRequestHead: head, status: .ok, headers: headers)
            context.write(channelHandler.wrapOutboundOut(.head(responseHead)), promise: nil)
            context.write(channelHandler.wrapOutboundOut(.body(.byteBuffer(content))), promise: nil)
        }
    }
}
