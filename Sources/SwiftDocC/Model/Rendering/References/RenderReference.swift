/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

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
    case image, video, file, fileType, xcodeRequirement, topic, section, download, link, externalLocation
    case unresolvable
}

/// The identifier of a render reference.
///
/// This structure wraps a string value to make handling of render identifiers more type safe and explicit.
public struct RenderReferenceIdentifier: Codable, Hashable, Equatable {
    /// The wrapped string identifier.
    public var identifier: String
    
    /// Creates a new render identifier.
    /// - Parameter identifier: The string identifier to wrap.
    public init(_ identifier: String) {
        self.identifier = identifier
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        identifier = try container.decode(String.self)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
    
    private enum CodingKeys: CodingKey {
        case identifier
    }
}

/// A reference that has a file.
public protocol URLReference {
    /// The base URL that file URLs of the conforming type are relative to.
    static var baseURL: URL { get }
}

extension URLReference {
    /// Transforms the given URL to ensure that it is relative to the base URL of the conforming type.
    ///
    /// The converter that writes the built documentation to the file system is responsible for copying the referenced file to this destination.
    /// - Parameters:
    ///   - url: The URL of the file.
    ///   - prefixComponent: An optional path component to add before the path of the file.
    /// - Returns: The transformed URL for the given file path.
    func renderURL(for url: URL, prefixComponent: String?) -> URL {
        // Web URLs should be left as-is
        guard !url.isAbsoluteWebURL else {
            return url
        }
        
        // URLs which are already relative to the base URL should be left as-is
        guard !url.pathComponents.starts(with: Self.baseURL.pathComponents) else {
            return url
        }

        return destinationURL(for: url.lastPathComponent, prefixComponent: prefixComponent)
    }
    
    /// Returns the URL for a given file path relative to the base URL of the conforming type.
    ///
    /// The converter that writes the built documentation to the file system is responsible for copying the referenced file to this destination.
    /// 
    /// - Parameters:
    ///   - path: The path of the file.
    ///   - prefixComponent: An optional path component to add before the path of the file.
    /// - Returns: The destination URL for the given file path.
    func destinationURL(for path: String, prefixComponent: String?) -> URL {
        var url = Self.baseURL
        if let bundleName = prefixComponent {
            url.appendPathComponent(bundleName, isDirectory: true)
        }
        url.appendPathComponent(path, isDirectory: false)
        return url
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

// Diffable conformance
extension RenderReferenceIdentifier: RenderJSONDiffable {
    /// Returns the difference between this RenderReferenceIdentifier and the given one.
    func difference(from other: RenderReferenceIdentifier, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)

        return diffBuilder.differences
    }
}
