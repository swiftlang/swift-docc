/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A description of the intent of a communication-bridge message.
///
/// Clients can use the type of the message to determine which handler to invoke.
///
/// - Note: Message types are backed by strings, so you can add new types without breaking the public API.
public struct MessageType: Codable, RawRepresentable, Hashable, CustomDebugStringConvertible {
    public var rawValue: String
    
    /// Creates a type from a raw value.
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// A message that indicates a renderer has finished rendering documentation content.
    public static let rendered = MessageType(rawValue: "rendered")
    
    /// A message that indicates a request for code-color preferences.
    ///
    /// Use code-color preferences to control how a renderer syntax highlighted code listings.
    public static let requestCodeColors = MessageType(rawValue: "requestCodeColors")
    
    /// A message that indicates what code colors a renderer uses to syntax highlight code listings.
    public static let codeColors = MessageType(rawValue: "codeColors")
    
    public var debugDescription: String {
        return "MessageType(\(rawValue))"
    }
}
