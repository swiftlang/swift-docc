/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type-erasing container for metadata.
public struct AnyMetadata {
    /// The metadata value.
    public var value: Any
    
    public init(_ value: Any) {
        self.value = value
    }
}

extension AnyMetadata: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            value = ()
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyMetadata].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyMetadata].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyMetadata failed to decode the value.")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self.value {
        case is Void:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyMetadata($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyMetadata($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyMetadata failed to encode the inner value: " + debugDescription)
            throw EncodingError.invalidValue(value, context)
        }
    }
}

extension AnyMetadata: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        return String(describing: value)
    }
    
}
