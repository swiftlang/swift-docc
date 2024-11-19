/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A pointer to a specific value in a JSON document.
///
/// For more information, see [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
public struct JSONPointer: Codable, CustomStringConvertible, Equatable {
    /// The path components of the pointer.
    ///
    /// The path components of the pointer are not escaped.
    public var pathComponents: [String]
    
    public var description: String {
        Self.escaped(pathComponents)
    }
    
    /// Creates a JSON Pointer given its path components.
    ///
    /// The components are assumed to be properly escaped per [RFC6901](https://datatracker.ietf.org/doc/html/rfc6901).
    public init(pathComponents: some Sequence<String>) {
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
        self.pathComponents = Self.unescaped(stringValue)
    }
    
    private static func escaped(_ pathComponents: [String]) -> String {
        // This code is called quite frequently for mixed language content.
        // Optimizing it has a measurable impact on the total documentation build time.
        
        var string: [UTF8.CodeUnit] = []
        string.reserveCapacity(
            pathComponents.reduce(0) { acc, component in
                acc + 1 /* the "/" separator */ + component.utf8.count
            }
        )
        
        for component in pathComponents {
            // The leading slash and component separator
            string.append(forwardSlash)
            
            // The escaped component
            for char in component.utf8 {
                switch char {
                case tilde:
                    string.append(contentsOf: escapedTilde)
                case forwardSlash:
                    string.append(contentsOf: escapedForwardSlash)
                default:
                    string.append(char)
                }
            }
        }
        
        return String(decoding: string, as: UTF8.self)
    }
    
    private static func unescaped(_ escapedRawString: String) -> [String] {
        escapedRawString.removingLeadingSlash.components(separatedBy: "/").map {
            // This code is called quite frequently for mixed language content.
            // Optimizing it has a measurable impact on the total documentation build time.
            
            var string: [UTF8.CodeUnit] = []
            string.reserveCapacity($0.utf8.count)
            
            var remaining = $0.utf8[...]
            while let char = remaining.popFirst() {
                guard char == tilde, let escapedCharacterIndicator = remaining.popFirst() else {
                    string.append(char)
                    continue
                }
                
                // Check the character
                switch escapedCharacterIndicator {
                case zero:
                    string.append(tilde)
                case one:
                    string.append(forwardSlash)
                default:
                    // This string isn't an escaped JSON Pointer. Return it as-is.
                    return $0
                }
            }
            
            return String(decoding: string, as: UTF8.self)
        }
    }
}

// A few UInt8 raw values for various UTF-8 characters that this implementation frequently checks for

private let tilde        = UTF8.CodeUnit(ascii: "~")
private let forwardSlash = UTF8.CodeUnit(ascii: "/")
private let zero         = UTF8.CodeUnit(ascii: "0")
private let one          = UTF8.CodeUnit(ascii: "1")

private let escapedTilde        = [tilde, zero]
private let escapedForwardSlash = [tilde, one]
