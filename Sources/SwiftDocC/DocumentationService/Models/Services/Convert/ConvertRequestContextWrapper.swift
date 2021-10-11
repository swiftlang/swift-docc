/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A wrapper type that adds contextual information relating to a convert request.
public struct ConvertRequestContextWrapper<Payload: Codable>: Codable {
    /// The identifier of the convert request associated with this payload.
    public var convertRequestIdentifier: String?
    
    /// The original payload.
    public var payload: Payload
    
    /// Creates a convert request context wrapper given the convert request's identifier and a payload.
    public init(convertRequestIdentifier: String?, payload: Payload) {
        self.convertRequestIdentifier = convertRequestIdentifier
        self.payload = payload
    }
}
