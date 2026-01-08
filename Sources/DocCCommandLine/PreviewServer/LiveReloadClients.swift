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
import Foundation

/// Manages SSE client connections for live reload notifications.
///
/// This class uses a lock instead of an actor to ensure NIO channels
/// are always accessed from compatible execution contexts.
final class LiveReloadClients: @unchecked Sendable {
    /// Shared instance for coordinating reload notifications across the preview server.
    static let shared = LiveReloadClients()

    private var clients: [ObjectIdentifier: any Channel] = [:]
    private let lock = NSLock()

    private init() {}

    /// Registers a channel to receive reload notifications.
    ///
    /// The channel is automatically removed when the connection closes.
    func register(_ channel: any Channel) {
        let id = ObjectIdentifier(channel)
        lock.lock()
        clients[id] = channel
        lock.unlock()

        channel.closeFuture.whenComplete { [weak self] _ in
            self?.remove(id)
        }
    }

    private func remove(_ id: ObjectIdentifier) {
        lock.lock()
        clients.removeValue(forKey: id)
        lock.unlock()
    }

    /// Sends a reload event to all connected SSE clients.
    func notifyAll() {
        let message = "event: reload\ndata: {}\n\n"

        lock.lock()
        let currentClients = clients
        lock.unlock()

        for (id, channel) in currentClients {
            guard channel.isActive else {
                remove(id)
                continue
            }
            // Schedule write on the channel's event loop
            channel.eventLoop.execute {
                var buffer = channel.allocator.buffer(capacity: message.utf8.count)
                buffer.writeString(message)
                // Wrap as HTTP body part for the HTTP pipeline
                let part = HTTPServerResponsePart.body(.byteBuffer(buffer))
                channel.writeAndFlush(part, promise: nil)
            }
        }
    }
}
#endif
