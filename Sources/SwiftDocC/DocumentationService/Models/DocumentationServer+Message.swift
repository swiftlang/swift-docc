/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension DocumentationServer {
    /// A message that can be provided to a documentation service.
    struct Message: Codable, Equatable {
        /// The type of the message.
        ///
        /// The message type is used to determine which service should process the message.
        public var type: MessageType
        
        /// The identifier of the message.
        public var identifier: String
        
        /// The payload of the message.
        ///
        /// The payload's encoding format is determine by the service that processes messages of its type.
        public var payload: Data?
        
        /// Closure that generates a random identifier.
        public static var randomIdentifierGenerator: () -> String = { UUID().uuidString }
        
        /// Creates a documentation service message.
        ///
        /// - Parameters:
        ///   - type: The type of the message, which is used to determine which service should process the message.
        ///   - identifier: The identifier of the message. By default, a random UUID string is created.
        ///   - payload: The payload of the message, encoded in the format its handling service expects.
        public init(
            type: MessageType,
            identifier: String = Self.randomIdentifierGenerator(),
            payload: Data?
        ) {
            self.type = type
            self.identifier = identifier
            self.payload = payload
        }
        
        /// Creates a documentation service message.
        ///
        /// - Parameters:
        ///   - type: The type of the message, which is used to determine which service should process the message.
        ///   - clientName: The name of the client creating this message, which this initializer uses as a prefix for the message's
        ///   identifier.
        ///   - payload: The payload of the message, encoded in the format its handling service expects.
        public init(type: MessageType, clientName: String, payload: Data?) {
            self.type = type
            self.identifier = "\(clientName)-\(Self.randomIdentifierGenerator())"
            self.payload = payload
        }
    }
}
