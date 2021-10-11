/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension DocumentationServer {
    /// A type of service message.
    ///
    /// The type of a service message is used to determine which service a server should invoke to process the message.
    struct MessageType: Codable, RawRepresentable, Hashable, CustomDebugStringConvertible,
                               ExpressibleByStringLiteral, Equatable {
        /// The string representation of the message.
        public var rawValue: String
        
        /// Creates a type from its string representation.
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        public init(stringLiteral value: StringLiteralType) {
            self.init(rawValue: value)
        }
        
        /// A type used to indicate error messages.
        public static let error = MessageType(rawValue: "error")
        
        public var debugDescription: String {
            "MessageType(\(rawValue))"
        }
    }
}
