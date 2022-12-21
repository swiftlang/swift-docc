/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to a resource that can be downloaded.
public struct DownloadReference: RenderReference, URLReference {
    /// The name you use for the directory that contains download items.
    ///
    /// This is the name of the directory within the generated build folder
    /// that contains downloads.
    public static let locationName = "downloads"

    public static var baseURL = URL(string: "/\(locationName)/")!
    
    public var type: RenderReferenceType = .download
    
    public var identifier: RenderReferenceIdentifier
    
    /// The location of the downloadable resource.
    public var url: URL
    
    /// The SHA512 hash value for the resource.
    public var checksum: String?

    @available(*, deprecated, renamed: "checksum")
    public var sha512Checksum: String {
        get {
            return checksum ?? ""
        }
        set {
            if newValue.isEmpty {
                self.checksum = nil
            } else {
                self.checksum = newValue
            }
        }
    }
    
    /// Creates a new reference to a downloadable resource.
    ///
    /// - Parameters:
    ///   - identifier: An identifier for the resource's reference.
    ///   - url: The path to the resource.
    ///   - sha512Checksum: The SHA512 hash value for the resource.
    public init(identifier: RenderReferenceIdentifier, renderURL url: URL, checksum: String?) {
        self.identifier = identifier
        self.url = url
        self.checksum = checksum
    }

    @available(*, deprecated, message: "Use 'init(identifier:renderURL:checksum:)' instead")
    public init(identifier: RenderReferenceIdentifier, renderURL url: URL, sha512Checksum: String) {
        self.init(identifier: identifier, renderURL: url, checksum: sha512Checksum)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeIfPresent(checksum, forKey: .checksum)
        
        // Render URL
        try container.encode(renderURL(for: url), forKey: .url)
    }
}

extension DownloadReference {
    private func renderURL(for url: URL) -> URL {
        url.isAbsoluteWebURL ? url : destinationURL(for: url.lastPathComponent)
    }
}
