/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to a resource.
///
/// The reference can refer to a resource within a documentation bundle (e.g., another symbol) or an external resource (e.g., a web URL).
/// Check the conforming types to browse the different kinds of references.
public protocol RenderReference: Codable {
    /// The type of the reference.
    var type: RenderReferenceType { get }
    
    /// The identifier of the reference.
    ///
    /// The identifier can be used to look up a value in the render node's ``RenderNode/references`` dictionary.
    var identifier: RenderReferenceIdentifier { get }
}

/// The type of a reference.
public enum RenderReferenceType: String, Codable, Equatable {
    case image, video, file, fileType, xcodeRequirement, topic, section, download, link
    case unresolvable
}

/// The identifier of a render reference.
///
/// This structure wraps a string value to make handling of render identifiers more type safe and explicit.
public struct RenderReferenceIdentifier: Codable, Hashable {
    /// The wrapped string identifier.
    public var identifier: String
    
    /// Creates a new render identifier.
    /// - Parameter identifier: The string identifier to wrap.
    public init(_ identifier: String) {
        self.identifier = identifier
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        identifier = try container.decode(String.self)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}

/// A reference that has a file.
public protocol URLReference {
    /// The base URL that file URLs of the conforming type are relative to.
    static var baseURL: URL { get }
}

extension URLReference {
    /// Returns the URL for a given file path relative to the base URL of the conforming type.
    ///
    /// The converter that writes the built documentation to the file system is responsible for copying the referenced file to this destination.
    /// 
    /// - Parameter path: The path of the file.
    /// - Returns: The destination URL for the given file path.
    func destinationURL(for path: String) -> URL {
        return Self.baseURL.appendingPathComponent(path, isDirectory: false)
    }
}

extension RenderReferenceIdentifier {
    /// Creates a new render reference identifier, based on the path of the given external link.
    ///
    /// This is not a unique identifier. If you create two render reference identifiers with the same external link destination, they are equal and interchangeable .
    ///
    /// - Parameter linkDestination: The full path of the external link represented as a `String`.
    public init(forExternalLink linkDestination: String) {
        self.identifier = "\(linkDestination)"
    }
}
