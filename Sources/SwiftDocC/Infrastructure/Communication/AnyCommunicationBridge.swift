/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type-erased communication bridge.
struct AnyCommunicationBridge: CommunicationBridge {
    var onReceiveMessage: ((Message) -> ())?

    private var _send: (Message, Any) throws -> ()

    func send(_ message: Message, using handler: Any) throws {
        try _send(message, handler)
    }

    init<Bridge>(_ bridge: Bridge) where Bridge: CommunicationBridge {
        onReceiveMessage = bridge.onReceiveMessage

        _send = { message, handler in
            try bridge.send(message, using: handler as! Bridge.SendHandler)
        }
    }
}
