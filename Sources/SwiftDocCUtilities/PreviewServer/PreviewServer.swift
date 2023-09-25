/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import Foundation
import SwiftDocC

import NIO
import NIOHTTP1

/// A preview server that delivers documentation from a directory on disk.
///
/// Call ``start()`` to bind the server to the given localhost port or socket, and
/// respond to HTTP requests.
///
/// ### Design
/// The server responds to two types of requests and ignores all others:
///  - a request to one of the pre-defined assets directories like /images/myimage.png or /downloads/project.zip returns the contents of the target file.
///  - a request to any other path outside of those directories returns a catch-all response with the main documentation page.
///
/// ### Performance
/// This lightweight server is optimized to provide documentation preview
/// from the command line to a single or a few clients. Thus, it does for example blockingly
/// load files from disk and it does *not* implement performance optimizations like an in-memory cache
/// (i.e. it hits the disk for each file it sends to the client). Also it will not maintain a
/// backlog of more than 16 pending client connections.
/// ## Topics
/// ### Serving Documentation
/// - ``init(contentURL:bindTo:logHandle:)``
/// - ``Bind``
/// - ``start(onReady:)``
/// - ``stop()``
final class PreviewServer {
    /// A list of errors specific to the preview server workflow.
    enum Error: DescribedError {
        /// The server failed to initialize or bind a port or socket.
        case failedToStart
        /// The server did not find the content directory.
        case pathNotFound(String)
        /// Cannot bind the server to the given address
        case cannotStartServer(host: String, port: Int)
        /// The given port is not available
        case portNotAvailable(host: String, port: Int)
        
        var errorDescription: String {
            switch self {
                case .failedToStart: return "Failed to start preview server"
                case .pathNotFound(let path): return "The preview content path '\(path)' is not found"
                case .cannotStartServer(let host, let port): return "Can't start the preview server on host \(host) and port \(port)"
                case .portNotAvailable(let host, let port): return "Port \(port) is not available on host \(host) at the moment, "
                    + "try a different port number by adding the option '--port XXXX' "
                    + "to your command invocation where XXXX is the desired (free) port."
            }
        }
    }
    
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)

    private var bootstrap: ServerBootstrap!
    internal var channel: Channel!
    
    private let contentURL: URL
    
    /// A list of server-bind destinations.
    public enum Bind: CustomStringConvertible {
        /// A port on the local machine.
        case localhost(host: String, port: Int)
        
        /// A file socket on disk.
        case socket(path: String)
        
        var description: String {
            switch self {
            case .localhost(host: let host, port: let port):
                return "\(host):\(port)"
            case .socket(path: let path):
                return path
            }
        }
    }
    
    /// Where to try binding the server; can be an ip address or a socket.
    private let bindTo: Bind
    
    /// The output to write log messages to.
    private var logHandle: LogHandle
    
    /// Creates a new preview server with the given content directory, bind destination, and credentials.
    ///
    /// - Parameters:
    ///   - contentURL: The root URL on disk from which to serve content.
    ///   - bindTo: Bind destination such as a localhost port or a file socket.
    ///   - logHandle: A file handle to write logs to.
    init(contentURL: URL, bindTo: Bind, logHandle: inout LogHandle) throws {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let contentPathExists = FileManager.default.fileExists(atPath: contentURL.path, isDirectory: &isDirectory)
        guard contentPathExists && isDirectory.boolValue else {
            throw Error.pathNotFound(contentURL.path)
        }
        
        self.contentURL = contentURL
        self.bindTo = bindTo
        self.logHandle = logHandle
    }

    /// Starts a new preview server and waits until it terminates.
    ///
    /// This method will block until the server channel is closed; to unblock it call ``stop()``.
    /// - Parameter onReady: A closure that's executed after the server is bound successfully
    ///   to its destination but before it has started serving content.
    func start(onReady: (() -> Void)? = nil) throws {
        // Create a server bootstrap
        let fileIO = NonBlockingFileIO(threadPool: threadPool)
        bootstrap = ServerBootstrap(group: group)
            // Learn more about the `listen` command pending clients backlog from its reference;
            // do that by typing `man 2 listen` on your command line.
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            // Enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Configure the channel handler - it handles plain HTTP requests
            .childChannelInitializer { channel in
                // HTTP pipeline
                return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                    channel.pipeline.addHandler(PreviewHTTPHandler(fileIO: fileIO, rootURL: self.contentURL))
                }
            }
            
            // Enable TCP_NODELAY for the accepted Channels
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
        
        // Start the server
        threadPool.start()
        
        do {
            // Bind to the given destination
            switch bindTo {
            case .localhost(let host, let port):
                channel = try bootstrap.bind(host: host, port: port).wait()
            case .socket(let path):
                channel = try bootstrap.bind(unixDomainSocketPath: path).wait()
            }
        } catch let error as NIO.IOError where error.errnoCode == EADDRINUSE {
            // The given port is not available.
            switch bindTo {
                case .localhost(let host, let port): throw Error.portNotAvailable(host: host, port: port)
                default: throw error
            }
        } catch {
            // Cannot bind the given address/port.
            switch bindTo {
                case .localhost(let host, let port): throw Error.cannotStartServer(host: host, port: port)
                default: throw error
            }
        }
        
        guard let _ = channel.localAddress else {
            throw Error.failedToStart
        }
        
        onReady?()
        
        // This will block until the server is stopped
        try channel.closeFuture.wait()
    }
    
    /// Stops the current preview server.
    /// - throws: If the server fails to close the communication channel or the async infrastructure.
    func stop() throws {
        if let feature = channel?.close(mode: .all) {
            try feature.wait()
        }
        try group.syncShutdownGracefully()
        try threadPool.syncShutdownGracefully()
        print("Stopped preview server at \(bindTo)", to: &logHandle)
    }
}
#endif
