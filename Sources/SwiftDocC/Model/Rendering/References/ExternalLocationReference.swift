/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A specialized ``DownloadReference`` used for references to external links.
///
/// `@CallToAction` directives can link either to a local file or to a URL, whether relative or
/// absolute. Directives that use the `file` argument will create a ``DownloadReference`` and copy
/// the file from the catalog into the resulting archive.
///
/// An `ExternalLocationReference` is intended to encode to Render JSON compatible with a
/// ``DownloadReference``, but with the `url` set to the text given in the `@CallToAction`'s `url`
/// argument.
@available(*, deprecated, message: "Use DownloadReference and its `init(identifier:verbatimURL:checksum)` initializer instead.")
public struct ExternalLocationReference: RenderReference, URLReference {
    public static var baseURL: URL = DownloadReference.baseURL

    public private(set) var type: RenderReferenceType = .externalLocation

    public let identifier: RenderReferenceIdentifier

    public var url: String

    enum CodingKeys: String, CodingKey {
        case type
        case identifier
        case url
    }

    public init(identifier: RenderReferenceIdentifier) {
        self.identifier = identifier
        self.url = identifier.identifier
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.identifier = try container.decode(RenderReferenceIdentifier.self, forKey: .identifier)
        self.url = try container.decode(String.self, forKey: .url)
        self.type = try container.decode(RenderReferenceType.self, forKey: .type)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(url, forKey: .url)
    }
}
