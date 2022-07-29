/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A type-erased codable value.
///
/// An `AnyCodable` value forwards encoding and decoding operations to the underlying base.
public struct AnyCodable: Codable, CustomDebugStringConvertible, Equatable {
    public static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        do {
            let encoder = JSONEncoder()
            let lhsData = try encoder.encode(lhs)
            let rhsData = try encoder.encode(rhs)
            return lhsData == rhsData
        } catch {
            print("The AnyCodable value couldn't be encoded while checking for equality.")
            return false
        }
    }
    
    
    /// The base encodable value.
    public var value: Encodable
    
    /// Creates a codable value that wraps the given base.
    public init(_ encodable: Encodable) {
        value = encodable
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = JSON.null
        } else {
            value = try container.decode(JSON.self)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    public var debugDescription: String {
        return String(describing: value)
    }
}
