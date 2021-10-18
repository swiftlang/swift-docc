/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A pointer to a specific value in a JSON document.
///
/// For more information, see [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
public struct JSONPointer: Codable {
    /// The components of the pointer.
    public var components: [String]
    
    /// Creates a JSON Pointer given its path components.
    ///
    /// The components are assumed to be properly escaped per [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
    public init(components: [String]) {
        self.components = components
    }
    
    /// An enum representing characters that need escaping in JSON Pointer values.
    ///
    /// The characters that need to be escaped in JSON Pointer values are defined in
    /// [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
    public enum EscapedCharacters: String, CaseIterable {
        /// The tilde character.
        ///
        /// This character is encoded as `~0` in JSON Pointer.
        case tilde = "~"
        
        /// The forward slash character.
        ///
        /// This character is encoded as `~1` in JSON Pointer.
        case forwardSlash = "/"
        
        /// The escaped character.
        public var escaped: String {
            switch self {
            case .tilde: return "~0"
            case .forwardSlash: return "~1"
            }
        }
    }
    
    /// Creates a JSON pointer given a coding path.
    ///
    /// Use this initializer when creating JSON pointers during encoding. This initializer escapes components as defined by
    /// [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
    public init(from codingPath: [CodingKey]) {
        self.components = codingPath.map { component in
            if let intValue = component.intValue {
                // If the coding key is an index into an array, emit the index as a string.
                return "\(intValue)"
            } else {
                // Otherwise, emit the property name, escaped per the JSON Pointer specification.
                return EscapedCharacters.allCases
                    .reduce(component.stringValue) { partialResult, characterThatNeedsEscaping in
                        partialResult
                            .replacingOccurrences(
                                of: characterThatNeedsEscaping.rawValue,
                                with: characterThatNeedsEscaping.escaped
                            )
                    }
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("/\(components.joined(separator: "/"))")
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self.components = stringValue.removingLeadingSlash.components(separatedBy: "/")
    }
}
