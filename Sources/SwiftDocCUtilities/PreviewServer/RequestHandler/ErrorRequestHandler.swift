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

struct RequestError: LocalizedError {
    let status: HTTPResponseStatus
    let message: String?
    
    init(status: HTTPResponseStatus, message: String? = nil) {
        self.status = status
        self.message = message
    }
}

/// A request handler that serves an error response.
struct ErrorRequestHandler: RequestHandlerFactory {
    let error: RequestError
    let headers: [(String, String)]
    
    /// Creates a new handler that responds to the client with the given error, optionally including extra headers.
    /// - Parameters:
    ///   - error: The error that the handler should send to the client. If `nil`, the handler will use a generic error.
    ///   - headers: Additional HTTP headers to include along with the response.
    init(error: RequestError? = nil, headers: [(String, String)] = []) {
        self.error = error ?? RequestError(status: .internalServerError, message: "Server Error")
        self.headers = headers
    }
    
    func create<ChannelHandler: ChannelInboundHandler>(channelHandler: ChannelHandler) -> RequestHandler
        where ChannelHandler.OutboundOut == HTTPServerResponsePart {
        
        return { context, head in
            var body = ByteBuffer()
            
            if let message = self.error.message {
                body = context.channel.allocator.buffer(capacity: message.utf8.count)
                body.writeString(message)
            }
            
            context.write(channelHandler.wrapOutboundOut(.head(HTTPResponseHead(matchingRequestHead: head, status: self.error.status, headers: HTTPHeaders(self.headers)))), promise: nil)
            context.write(channelHandler.wrapOutboundOut(.body(.byteBuffer(body))), promise: nil)
        }
    }
}
