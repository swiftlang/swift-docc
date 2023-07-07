/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A reference to a resource that can be downloaded.
public struct DownloadReference: RenderReference, URLReference, Equatable {
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

    /// Indicates whether the ``url`` property should be encoded verbatim into Render JSON.
    ///
    /// This is used during encoding to determine whether to filter ``url`` through the
    /// `renderURL(for:)` method. In case the URL was loaded from JSON, we don't want to modify it
    /// further after a round-trip.
    private var encodeUrlVerbatim = false

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
    ///   - checksum: The SHA512 hash value for the resource.
    public init(identifier: RenderReferenceIdentifier, renderURL url: URL, checksum: String?) {
        self.identifier = identifier
        self.url = url
        self.checksum = checksum
    }

    /// Creates a new reference to a downloadable resource, with a URL that should be encoded as-is.
    ///
    /// - Parameters:
    ///   - identifier: An identifier for the resource's reference.
    ///   - url: The path to the resource. This will be encoded as-is into the Render JSON.
    ///   - checksum: The SHA512 hash value for the resource.
    public init(identifier: RenderReferenceIdentifier, verbatimURL url: URL, checksum: String?) {
        self.identifier = identifier
        self.url = url
        self.checksum = checksum
        self.encodeUrlVerbatim = true
    }

    @available(*, deprecated, message: "Use 'init(identifier:renderURL:checksum:)' instead")
    public init(identifier: RenderReferenceIdentifier, renderURL url: URL, sha512Checksum: String) {
        self.init(identifier: identifier, renderURL: url, checksum: sha512Checksum)
    }

    enum CodingKeys: CodingKey {
        case type
        case identifier
        case url
        case checksum
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(RenderReferenceType.self, forKey: .type)
        self.identifier = try container.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        self.url = try container.decode(URL.self, forKey: .url)
        self.encodeUrlVerbatim = true
        self.checksum = try container.decodeIfPresent(String.self, forKey: .checksum)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(checksum, forKey: .checksum)
        
        // Render URL
        if !encodeUrlVerbatim {
            try container.encode(renderURL(for: url), forKey: .url)
        } else {
            try container.encode(url, forKey: .url)
        }
    }

    static public func ==(lhs: DownloadReference, rhs: DownloadReference) -> Bool {
        lhs.identifier == rhs.identifier
        && lhs.url == rhs.url
        && lhs.checksum == rhs.checksum
    }
}

extension DownloadReference {
    private func renderURL(for url: URL) -> URL {
        url.isAbsoluteWebURL ? url : destinationURL(for: url.lastPathComponent)
    }
}
