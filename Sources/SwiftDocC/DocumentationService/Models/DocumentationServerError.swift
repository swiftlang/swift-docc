/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An error that occurs during the processing of a message by a documentation service.
public struct DocumentationServerError: DescribedError, Codable {
    /// The identifier of the error.
    public var identifier: String
    
    /// The human-readable description of the error.
    public var description: String
    
    public var errorDescription: String { description }
    
    /// An error that indicates that a received message has no service that can process it.
    public static func unsupportedMessageType() -> DocumentationServerError {
        DocumentationServerError(
            identifier: "unsupported-message-type",
            description: "The message type is not recognized by the service."
        )
    }
    
    /// An error that indicates that a received message could not be decoded, likely because it is encoded in an invalid format.
    public static func invalidMessage(underlyingError: String) -> DocumentationServerError {
        DocumentationServerError(
            identifier: "invalid-message",
            description: "The message is invalid and cannot be decoded: \(underlyingError)"
        )
    }
    
    /// An error that indicates that a response message could not be encoded.
    public static func invalidResponseMessage(underlyingError: String) -> DocumentationServerError {
        DocumentationServerError(
            identifier: "invalid-response-message",
            description: "The response message is invalid and cannot be encoded: \(underlyingError)"
        )
    }
}
