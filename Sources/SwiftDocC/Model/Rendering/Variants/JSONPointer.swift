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
public struct JSONPointer: Codable, CustomStringConvertible {
    /// The path components of the pointer.
    ///
    /// The path components of the pointer are not escaped.
    public var pathComponents: [String]
    
    public var description: String {
        "/\(pathComponents.map(Self.escape).joined(separator: "/"))"
    }
    
    /// Creates a JSON Pointer given its path components.
    ///
    /// The components are assumed to be properly escaped per [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
    public init<Components: Sequence>(pathComponents: Components) where Components.Element == String {
        self.pathComponents = Array(pathComponents)
    }
    
    /// Returns the pointer with the first path component removed.
    public func removingFirstPathComponent() -> JSONPointer {
        JSONPointer(pathComponents: pathComponents.dropFirst())
    }
    
    func prependingPathComponents(_ components: [String]) -> JSONPointer {
        JSONPointer(pathComponents: components + pathComponents)
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
        self.pathComponents = codingPath.map { component in
            if let intValue = component.intValue {
                // If the coding key is an index into an array, emit the index as a string.
                return "\(intValue)"
            } else {
                // Otherwise, emit the property name, escaped per the JSON Pointer specification.
                return component.stringValue
            }
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let stringValue = try container.decode(String.self)
        self.pathComponents = stringValue.removingLeadingSlash.components(separatedBy: "/").map(Self.unescape)
    }
    
    /// Escapes a path component of a JSON pointer.
    static func escape(_ pointerPathComponents: String) -> String {
        applyEscaping(pointerPathComponents, shouldUnescape: false)
    }
    
    /// Unescaped a path component of a JSON pointer.
    static func unescape(_ pointerPathComponents: String) -> String {
        applyEscaping(pointerPathComponents, shouldUnescape: true)
    }
    
    /// Applies an escaping operation to the path component of a JSON pointer.
    /// - Parameters:
    ///   - pointerPathComponent: The path component to escape.
    ///   - shouldUnescape: Whether this function should unescape or escape the path component.
    /// - Returns: The escaped value if `shouldUnescape` is false, otherwise the escaped value.
    private static func applyEscaping(_ pointerPathComponent: String, shouldUnescape: Bool) -> String {
        EscapedCharacters.allCases
            .reduce(pointerPathComponent) { partialResult, characterThatNeedsEscaping in
                partialResult
                    .replacingOccurrences(
                        of: characterThatNeedsEscaping[
                            keyPath: shouldUnescape ? \EscapedCharacters.escaped : \EscapedCharacters.rawValue
                        ],
                        with: characterThatNeedsEscaping[
                            keyPath: shouldUnescape ? \EscapedCharacters.rawValue : \EscapedCharacters.escaped
                        ]
                    )
            }
    }
}
