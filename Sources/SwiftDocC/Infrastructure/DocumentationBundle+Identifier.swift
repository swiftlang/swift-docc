/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension DocumentationBundle {
    /// A stable and locally unique identifier for a collection of documentation inputs.
    public struct Identifier: RawRepresentable {
        public let rawValue: String
        
        public init(rawValue: String) {
            // To ensure that the identifier can be used as a valid "host" component of a resolved topic reference's url,
            // replace any consecutive sequence of unsupported characters with a "-".
            self.rawValue = rawValue
                .components(separatedBy: Self.charactersToReplace)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
        }
        
        private static let charactersToReplace = CharacterSet.urlHostAllowed.inverted
    }
}

extension DocumentationBundle.Identifier: Hashable {}
extension DocumentationBundle.Identifier: Sendable {}

// Support creating an identifier from a string literal.
extension DocumentationBundle.Identifier: ExpressibleByStringLiteral {
    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }
}

// Sort identifiers based on their raw string value.
extension DocumentationBundle.Identifier: Comparable {
    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// Print as a single string value
extension DocumentationBundle.Identifier: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}

// Encode and decode the identifier as a single string value.
extension DocumentationBundle.Identifier: Codable {
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
