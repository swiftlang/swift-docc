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
        case cannotStartServer(port: Int)
        /// The given port is not available
        case portNotAvailable(port: Int)
        
        var errorDescription: String {
            switch self {
                case .failedToStart: return "Failed to start preview server"
                case .pathNotFound(let path): return "The preview content path '\(path)' is not found"
                case .cannotStartServer(let port): return "Can't start the preview server on port \(port)"
                case .portNotAvailable(let port): return "Port \(port) is not available at the moment, "
                    + "try a different port number by adding the option '--port XXXX' "
                    + "to your command invocation where XXXX is the desired (free) port."
            }
        }
    }
    
    private struct State {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)
        
        var bootstrap: ServerBootstrap!
        var channel: (any Channel)!
    }
    
    private var state = Synchronized(State())
    
    @_spi(Testing)
    public var _boundPort: Int? {
        state.sync {
            $0.channel.localAddress?.port
        }
    }
    
    private let contentURL: URL
    private let fileManager: any FileManagerProtocol
    
    /// A list of server-bind destinations.
    public enum Bind: CustomStringConvertible {
        /// A port on the local machine.
        case localhost(port: Int)
        
        /// A file socket on disk.
        case socket(path: String)
        
        var description: String {
            switch self {
            case .localhost(port: let port):
                return "localhost:\(port)"
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
    ///   - fileManager: The file manager that the server uses to read the files to respond to page requests.
    init(contentURL: URL, bindTo: Bind, logHandle: inout LogHandle, fileManager: any FileManagerProtocol) throws {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let contentPathExists = FileManager.default.fileExists(atPath: contentURL.path, isDirectory: &isDirectory)
        guard contentPathExists && isDirectory.boolValue else {
            throw Error.pathNotFound(contentURL.path)
        }
        
        self.contentURL = contentURL
        self.bindTo = bindTo
        self.logHandle = logHandle
        self.fileManager = fileManager
    }

    /// Starts a new preview server and waits until it terminates.
    ///
    /// This method will block until the server channel is closed; to unblock it call ``stop()``.
    /// - Parameter onReady: A closure that's executed after the server is bound successfully
    ///   to its destination but before it has started serving content.
    func start(onReady: (() -> Void)? = nil) throws {
        let closeFuture = try state.sync {
            // Create a server bootstrap
            $0.bootstrap = ServerBootstrap(group: $0.group)
                // Learn more about the `listen` command pending clients backlog from its reference;
                // do that by typing `man 2 listen` on your command line.
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                // Enable SO_REUSEADDR for the server itself
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                // Configure the channel handler - it handles plain HTTP requests
                .childChannelInitializer { [contentURL, fileManager] channel in
                    // HTTP pipeline
                    return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                        channel.pipeline.addHandler(PreviewHTTPHandler(rootURL: contentURL, fileManager: fileManager))
                    }
                }
                // Enable TCP_NODELAY for the accepted Channels
                .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
                .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
                .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)
            
            // Start the server
            $0.threadPool.start()
            
            switch bindTo {
            case .localhost(let port):
                // Customize the errors when binding to a localhost port
                do {
                    $0.channel = try $0.bootstrap.bind(host: "localhost", port: port).wait()
                } catch let error as NIO.IOError where error.errnoCode == EADDRINUSE {
                    throw Error.portNotAvailable(port: port)
                } catch {
                    throw Error.cannotStartServer(port: port)
                }
                
            case .socket(let path):
                $0.channel = try $0.bootstrap.bind(unixDomainSocketPath: path).wait()
            }
            
            guard let _ = $0.channel.localAddress else {
                throw Error.failedToStart
            }
            
            // Return the closeFuture so that we can `wait()` it outside the synchronization scope.
            return $0.channel.closeFuture
        }
        
        onReady?()
        
        // This will block until the server is stopped
        try closeFuture.wait()
    }
    
    /// Stops the current preview server.
    /// - throws: If the server fails to close the communication channel or the async infrastructure.
    func stop() throws {
        try state.sync {
            if let feature = $0.channel?.close(mode: .all) {
                try feature.wait()
            }
            try $0.group.syncShutdownGracefully()
            try $0.threadPool.syncShutdownGracefully()
        }
        print("Stopped preview server at \(bindTo)", to: &logHandle)
    }
    
    deinit {
        // Only synchronize around the `isWritable` check (as opposed to the full deinitialization scope).
        // The synchronization lock isn't reentrant and `stop()` also acquires the lock to close and shut down.
        if state.sync({ $0.channel?.isWritable }) == true {
            try? stop()
        }
    }
}
#endif
