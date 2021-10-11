/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC

import NIO
import NIOHTTP1
import NIOSSL

/// A preview server that delivers documentation from a directory on disk.
///
/// Call ``start()`` to bind the server to the given localhost port or socket, and
/// respond to HTTP requests. To serve the preview over SSL on the local network,
/// provide a credentials chain when initializing the server.
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
/// - ``init(contentURL:bindTo:username:password:tlsCertificateChainURL:tlsCertificateKeyURL:logHandle:)``
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
    
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    private let threadPool = NIOThreadPool(numberOfThreads: System.coreCount)

    private var bootstrap: ServerBootstrap!
    internal var channel: Channel!
    
    private let contentURL: URL
    private let username: String?
    private let password: String?
    private let tlsCertificateChainURL: URL?
    private let tlsCertificateKeyURL: URL?
    
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
    
    /// The output to write log mesages to.
    private var logHandle: LogHandle
    
    /// Creates a new preview server with the given content directory, bind destination, and credentials.
    ///
    /// If you want to serve content over SSL provide a `username`, `password`, `tlsCertificateChainURL`, and `tlsCertificateKeyURL`.
    /// DocC requires you to provide the two certificates in order to create an encrypted communication channel, and
    /// additionally a username and password to authenticate users when serving documentation over a local network.
    ///
    /// If you use a self-signed SSL certificate to serve content from a local machine,
    /// web browsers might warn visitors that the connection is not secure.
    /// - Note: When you start the preview server with SSL enabled on macOS, you will be required to approve
    ///   network access via the standard system dialogue.
    /// - Parameters:
    ///   - contentURL: The root URL on disk from which to serve content.
    ///   - bindTo: Bind destination such as a localhost port or a file socket.
    ///   - username: A username to require, if serving secure content.
    ///   - password: A password to require, if serving secure content.
    ///   - tlsCertificateChainURL: A certificate chain to use for SSL, if serving secure content.
    ///   - tlsCertificateKeyURL: A certificate key to use for SSL, if serving secure content.
    ///   - logHandle: A file handle to write logs to.
    init(contentURL: URL, bindTo: Bind, username: String?, password: String?, tlsCertificateChainURL: URL? = nil, tlsCertificateKeyURL: URL? = nil, logHandle: inout LogHandle) throws {
        var isDirectory = ObjCBool(booleanLiteral: false)
        let contentPathExists = FileManager.default.fileExists(atPath: contentURL.path, isDirectory: &isDirectory)
        guard contentPathExists && isDirectory.boolValue else {
            throw Error.pathNotFound(contentURL.path)
        }
        
        self.contentURL = contentURL
        self.bindTo = bindTo
        self.username = username
        self.password = password
        self.tlsCertificateChainURL = tlsCertificateChainURL
        self.tlsCertificateKeyURL = tlsCertificateKeyURL
        self.logHandle = logHandle
    }

    /// Starts a new preview server and waits until it terminates.
    ///
    /// This method will block until the server channel is closed; to unblock it call ``stop()``.
    /// - Parameter onReady: A closure that's executed after the server is bound successfully
    ///   to its destination but before it has started serving content.
    func start(onReady: (() -> Void)? = nil) throws {
        // An optional SSL context if required
        let sslContext: NIOSSL.NIOSSLContext?
        
        if let tlsCertificateChainURL = tlsCertificateChainURL,
            let tlsCertificateKeyURL = tlsCertificateKeyURL {
            
            print("SSL certificate chain: \(tlsCertificateChainURL.path)", to: &logHandle)
            
            // Will throw if cannot parse the provided PEM file
            let certificateChain = try NIOSSLCertificate.fromPEMFile(tlsCertificateChainURL.path)
                .map(NIOSSLCertificateSource.certificate)

            sslContext = try NIOSSLContext(
                configuration: TLSConfiguration.makeServerConfiguration(
                    certificateChain: certificateChain,
                    privateKey: .file(tlsCertificateKeyURL.path)
                )
            )
        } else {
            sslContext = nil
        }
        
        // Create a server bootstrap
        let fileIO = NonBlockingFileIO(threadPool: threadPool)
        bootstrap = ServerBootstrap(group: group)
            // Learn more about the `listen` command pending clients backlog from its reference;
            // do that by typing `man 2 listen` on your command line.
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            // Enable SO_REUSEADDR for the server itself
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)

            // Configure the channel handler - it either handles plain HTTP requests or HTTPS over SSL
            .childChannelInitializer { channel in
                if let sslContext = sslContext {
                    let sslHandler = NIOSSLServerHandler(context: sslContext)
                    
                    var credentials: (user: String, pass: String)?
                    if let username = self.username, let password = self.password {
                        credentials = (username, password)
                    }
                    
                    // HTTPS pipeline
                    return channel.pipeline.addHandler(sslHandler).flatMap {
                        channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: nil, withErrorHandling: true).flatMap {
                            channel.pipeline.addHandler(PreviewHTTPHandler(fileIO: fileIO, rootURL: self.contentURL, credentials: credentials))
                        }
                    }
                } else {
                    // HTTP pipeline
                    return channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap {
                        channel.pipeline.addHandler(PreviewHTTPHandler(fileIO: fileIO, rootURL: self.contentURL))
                    }
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
            case .localhost(let port):
                if sslContext != nil {
                    // If SSL is enabled, we bind to address `0.0.0.0` explicitly which
                    // will cause docc to request access to incoming network connections
                    // and allow users to connect to the preview server with external devices.
                    channel = try bootstrap.bind(to: SocketAddress(ipAddress: "0.0.0.0", port: port)).wait()
                } else {
                    // Otherwise we bind to `localhost` which will not trigger this request.
                    channel = try bootstrap.bind(host: "localhost", port: port).wait()
                }
            case .socket(let path):
                channel = try bootstrap.bind(unixDomainSocketPath: path).wait()
            }
        } catch let error as NIO.IOError where error.errnoCode == EADDRINUSE {
            // The given port is not available.
            switch bindTo {
                case .localhost(let port): throw Error.portNotAvailable(port: port)
                default: throw error
            }
        } catch {
            // Cannot bind the given address/port.
            switch bindTo {
                case .localhost(let port): throw Error.cannotStartServer(port: port)
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
