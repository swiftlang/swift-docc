/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(NIOHTTP1)
import Foundation
import Testing
@testable import DocCCommandLine

import NIO
import NIOHTTP1

@Suite
@MainActor
struct LiveReloadClientsTests {

    @Test
    func registeredChannelReceivesNotification() throws {
        let clients = LiveReloadClients()
        let channel = EmbeddedChannel()
        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        defer { _ = try? channel.finish() }

        clients.register(channel)
        clients.notifyAll()
        (channel.eventLoop as! EmbeddedEventLoop).run()

        guard case .body(.byteBuffer(let buffer)) = try channel.readOutbound(as: HTTPServerResponsePart.self) else {
            Issue.record("Expected body response part")
            return
        }
        #expect(buffer.getString(at: 0, length: buffer.readableBytes) == "event: reload\ndata: {}\n\n")
    }

    @Test
    func closedChannelDoesNotReceiveNotification() throws {
        let clients = LiveReloadClients()
        let channel = EmbeddedChannel()
        try channel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        defer { _ = try? channel.finish() }

        clients.register(channel)
        try channel.close().wait()
        (channel.eventLoop as! EmbeddedEventLoop).run()

        clients.notifyAll()
        (channel.eventLoop as! EmbeddedEventLoop).run()

        #expect(try channel.readOutbound(as: HTTPServerResponsePart.self) == nil)
    }

    @Test
    func notifyAllWritesToMultipleChannels() throws {
        let clients = LiveReloadClients()
        let channel1 = EmbeddedChannel()
        let channel2 = EmbeddedChannel()
        try channel1.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        try channel2.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        defer {
            _ = try? channel1.finish()
            _ = try? channel2.finish()
        }

        clients.register(channel1)
        clients.register(channel2)
        clients.notifyAll()
        (channel1.eventLoop as! EmbeddedEventLoop).run()
        (channel2.eventLoop as! EmbeddedEventLoop).run()

        guard case .body(.byteBuffer(let buffer1)) = try channel1.readOutbound(as: HTTPServerResponsePart.self) else {
            Issue.record("Expected body response part for channel1")
            return
        }
        guard case .body(.byteBuffer(let buffer2)) = try channel2.readOutbound(as: HTTPServerResponsePart.self) else {
            Issue.record("Expected body response part for channel2")
            return
        }
        let expectedMessage = "event: reload\ndata: {}\n\n"
        #expect(buffer1.getString(at: 0, length: buffer1.readableBytes) == expectedMessage)
        #expect(buffer2.getString(at: 0, length: buffer2.readableBytes) == expectedMessage)
    }

    @Test
    func inactiveChannelSkippedDuringNotify() throws {
        let clients = LiveReloadClients()
        let activeChannel = EmbeddedChannel()
        let inactiveChannel = EmbeddedChannel()
        try activeChannel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        try inactiveChannel.connect(to: SocketAddress(ipAddress: "127.0.0.1", port: 1)).wait()
        defer {
            _ = try? activeChannel.finish()
            _ = try? inactiveChannel.finish()
        }

        clients.register(activeChannel)
        clients.register(inactiveChannel)

        try inactiveChannel.close().wait()
        (inactiveChannel.eventLoop as! EmbeddedEventLoop).run()

        clients.notifyAll()
        (activeChannel.eventLoop as! EmbeddedEventLoop).run()
        (inactiveChannel.eventLoop as! EmbeddedEventLoop).run()

        #expect(try activeChannel.readOutbound(as: HTTPServerResponsePart.self) != nil)
        #expect(try inactiveChannel.readOutbound(as: HTTPServerResponsePart.self) == nil)
    }
}
#endif
