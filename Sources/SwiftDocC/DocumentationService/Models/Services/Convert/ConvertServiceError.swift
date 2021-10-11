/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An error that occurs during the processing of a documentation conversion request.
public struct ConvertServiceError: DescribedError, Codable {
    /// The identifier of the error.
    public var identifier: String
    
    /// The human-readable description of the error.
    public var description: String
    
    public var errorDescription: String { description }
    
    /// An error that indicates that a convert request has no associated payload.
    public static func missingPayload() -> ConvertServiceError {
        ConvertServiceError(
            identifier: "missing-payload",
            description: "The request is missing a payload."
        )
    }
    
    /// An error that indicates that an error occurred while converting documentation.
    public static func conversionError(underlyingError: String) -> ConvertServiceError {
        ConvertServiceError(
            identifier: "conversion-error",
            description: "The documentation content could not be converted: \(underlyingError)"
        )
    }
    
    /// An error that indicates that a received request could not be decoded, likely because it is encoded in an invalid format.
    public static func invalidRequest(underlyingError: String) -> ConvertServiceError {
        ConvertServiceError(
            identifier: "invalid-request",
            description: "The request is invalid and cannot be decoded: \(underlyingError)"
        )
    }
    
    /// An error that indicates that a response could not be encoded.
    public static func invalidResponseMessage(underlyingError: String) -> ConvertServiceError {
        ConvertServiceError(
            identifier: "invalid-response-message",
            description: "The response message is invalid and cannot be encoded: \(underlyingError)"
        )
    }
}
