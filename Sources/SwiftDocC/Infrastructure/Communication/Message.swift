/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A message to send or receive from a documentation renderer using a communication bridge.
public struct Message {
    /// The type of the message.
    ///
    /// Clients can use the type of the message to determine which handler to invoke.
    public var type: MessageType
    
    /// The payload of the message.
    ///
    /// The data associated with a message is encodable, so a communication bridge can encode it when a client sends a
    /// message.
    public var data: AnyCodable?
    
    /// An identifier for the message.
    ///
    /// The identifier helps clients keep track of which messages they've received, and messages for which they're awaiting a
    /// response in a request-response model.
    public var identifier: String?
    
    /// Creates a message given a type, a data payload, and an identifier.
    /// - Parameters:
    ///   - type: The type of the message.
    ///   - data: The data payload of the message.
    ///   - identifier: The identifier of the message.
    public init(type: MessageType, data: AnyCodable?, identifier: String?) {
        self.type = type
        self.data = data
        self.identifier = identifier
    }
    
    /// Generates a unique string identifier for a message.
    public static func generateUUID() -> String {
        return UUID().uuidString
    }
    
    /// Creates a message that indicates a renderer has finished rendering documentation content.
    ///
    /// The string value of this message type is `rendered`.
    public static func rendered(identifier: String = generateUUID()) -> Message {
        return .init(type: .rendered, data: nil, identifier: identifier)
    }
    
    /// Creates a message that indicates a request for code-color preferences.
    ///
    /// This message is sent by renderer to request code-color preferences that renderers use when syntax highlighting code listings.
    /// The string value of this message type is `requestCodeColors`.
    public static func requestCodeColors(identifier: String = generateUUID()) -> Message {
        return .init(type: .requestCodeColors, data: nil, identifier: identifier)
    }
    
    /// Creates a message that indicates what code colors a renderer uses to syntax highlight code listings.
    ///
    /// A "codeColors" message is sent as a response to a `requestCodeColors` message and provides code colors
    /// preferences that a renderer uses when syntax highlighting code. The string value of this message type is `codeColors`.
    ///
    /// - Parameters:
    ///   - codeColors: The code colors information that a renderer uses to syntax highlight code listings.
    ///   - identifier: An identifier for the message.
    public static func codeColors(_ codeColors: CodeColors, identifier: String = generateUUID()) -> Message {
        return .init(type: .codeColors, data: AnyCodable(codeColors), identifier: identifier)
    }
}
