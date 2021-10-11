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

/// An HTTP request handler that serves file assets and the default app page.
///
/// A custom HTTP handler that's able to serve compiled documentation
/// via a web server bound to a port on the local machine or a socket.
///
/// ### Features
/// - HTTP Basic Authentication when serving content to local network over SSL
/// - Serving static files from pre-defined assets directory paths
/// - A catch-all default GET response handler for all non-asset requests
/// - Ignores unknown requests
///
/// ### Life cycle
/// The handler is a simple state machine alternating between 'idle' and 'requestInProgress' states
/// while going through the following cycle:
///
/// 1. ``state`` is `.idle`
/// 2. ``channelRead(context:data:)`` is called with HTTP request `head` context
/// 3. ``state`` is set to `.requestInProgress(head, handler)`
/// 4. ``channelRead(context:data:)`` is called with HTTP request `end` context
/// 5. ``state`` is set to `.idle`
/// 6. response data is flushed to the client (go to 1)
final class PreviewHTTPHandler: ChannelInboundHandler {
    /// The handler's expected input data format.
    public typealias InboundIn = HTTPServerRequestPart
    
    /// The handler's expected output data format.
    public typealias OutboundOut = HTTPServerResponsePart
    
    /// The current handler's request state.
    private enum State {
        case idle, requestInProgress(requestHead: HTTPRequestHead, handler: RequestHandler)
    }
    
    // MARK: - Properties
    private var state: State = .idle
    
    private var keepAlive = false
    private let rootURL: URL

    private var handlerFuture: EventLoopFuture<Void>?
    private let fileIO: NonBlockingFileIO

    // When serving content on local network over SSL we authorize users via these credentials
    private let credentials: (user: String, pass: String)?
    
    /// - Parameters:
    ///   - fileIO: Async file I/O.
    ///   - rootURL: The root of the content directory to serve.
    ///   - credentials: Optional user credentials to authorize incoming requests.
    public init(fileIO: NonBlockingFileIO, rootURL: URL, credentials: (user: String, pass: String)? = nil) {
        self.rootURL = rootURL
        self.fileIO = fileIO
        self.credentials = credentials
    }
    
    /// Handles incoming data on a channel.
    ///
    /// When receiving a request's head this method prepares the correct handler
    /// for the requested resource.
    ///
    /// When receiving a request's tail this method sends content back to the
    /// client and if neccessary verifies user-provided credentials when serving content over SSL.
    /// - Parameters:
    ///   - context: A channel context.
    ///   - data: The current inbound request data.
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let requestPart = unwrapInboundIn(data)
        
        switch (requestPart, state) {
        case (.head(let head), _):
            let handler: RequestHandlerFactory
            if FileRequestHandler.isAssetPath(head.uri) {
                // Serve a static asset file.
                handler = FileRequestHandler(rootURL: rootURL, fileIO: fileIO)
            } else {
                // Serve the fallback index file.
                handler = DefaultRequestHandler(rootURL: rootURL)
            }
            state = .requestInProgress(requestHead: head, handler: handler.create(channelHandler: self))
            
        case (.end, .requestInProgress(let head, let handler)):
            // In case the handler was initialized with user credentials,
            // do verify they match the sent "Authorization" header
            if let credentials = credentials {
                
                // Verify the user sent credentials over via the HTTP headers
                let authorizationHeaders = head.headers["Authorization"]
                guard !authorizationHeaders.isEmpty else {
                    error(context: context, requestPart: requestPart, head: head, status: .unauthorized, headers: [("WWW-Authenticate", "Basic realm=\"Preview server\"")])
                    return
                }
                
                let credentialsToken = [credentials.user, credentials.pass].joined(separator: ":")
                    .data(using: .utf8)!.base64EncodedString()
                
                guard authorizationHeaders[0] == "Basic \(credentialsToken)" else {
                    error(context: context, requestPart: requestPart, head: head, status: .forbidden)
                    return
                }
            }
            
            defer {
                // Complete the response to the client, reset ``state``
                completeResponse(context, trailers: nil, promise: nil)
            }
            
            // Call the pre-defined during the `head` context handler.
            do {
                try handler(context, head)
            } catch {
                let errorHandler = ErrorRequestHandler(error: error as? RequestError)
                    .create(channelHandler: self)
                
                // The error handler will never throw.
                try! errorHandler(context, head)
            }
            
        // Ignore other parts of a request, e.g. POST data or others.
        default: break
        }
    }

    /// Complete the current response and flush the buffer to the client.
    private func completeResponse(_ context: ChannelHandlerContext, trailers: HTTPHeaders?, promise: EventLoopPromise<Void>?) {
        guard case State.requestInProgress = state else { return }
        state = .idle
        
        let promise = promise ?? context.eventLoop.makePromise()
        
        // If we don't need to keep the connection alive, close `context` after flushing the response
        if !self.keepAlive {
            promise.futureResult.whenComplete { _ in context.close(promise: nil) }
        }

        context.writeAndFlush(self.wrapOutboundOut(.end(trailers)), promise: promise)
    }
    
    /// Replaces the current in-progress response with an error response and flushes the output to the client.
    private func error(context: ChannelHandlerContext, requestPart: PreviewHTTPHandler.InboundIn, head: HTTPRequestHead, status: HTTPResponseStatus, headers: [(String, String)] = []) {
        let errorHandler = ErrorRequestHandler(error: RequestError(status: status), headers: headers)
            .create(channelHandler: self)
        
        try! errorHandler(context, head)
        completeResponse(context, trailers: nil, promise: nil)
    }
}
