/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An arbitrary-length version tuple.
public struct Version: Codable, RandomAccessCollection, ExpressibleByArrayLiteral, CustomStringConvertible, Equatable {
    private var elements: [Int]
    
    /// The start index of the version-components tuple.
    public var startIndex: Int {
        return elements.startIndex
    }
    /// The end index of the version-components tuple.
    public var endIndex: Int {
        return elements.endIndex
    }
    /// Returns the version component at the given index.
    public subscript(index: Int) -> Int {
        return elements[index]
    }
    /// Creates a new version with the given components.
    /// - Parameter elements: The components of a version, for example: 1, 0, 3.
    public init(arrayLiteral elements: Int...) {
        self.elements = elements
    }

    /// Creates a new version from the given string representation.
    /// - parameter versionString: A version as a string.
    /// - warning: Returns `nil` if the version string contains non-integer or
    ///   negative numeric components; for example the strings "1.2.3-beta6" and "1.-2.3"
    ///   are invalid inputs.
    public init?(versionString: String) {
        let stringComponents = versionString.components(separatedBy: ".")
        let intComponents = stringComponents.compactMap { Int($0) }
        guard intComponents.count == stringComponents.count,
            intComponents.count > 0 else {
            return nil
        }
        guard !intComponents.contains(where: { $0 < 0 }) else {
            return nil
        }
        self.elements = intComponents
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        if let versionFromString = Version(versionString: string) {
            self = versionFromString
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Failed to create Version from given string '\(string)'"
            )
        }
    }

    /// The string representation of the version.
    public var description: String {
        return elements.map(String.init).joined(separator: ".")
    }
}
