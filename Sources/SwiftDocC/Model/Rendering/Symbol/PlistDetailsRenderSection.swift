/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A title style for a property list key or an entitlement key.
public enum TitleStyle: String, Codable {
    // Render links to the symbol using the "raw" name, for example, "com.apple.enableDataAccess".
    case symbol
    // Render links to the symbol using a special "IDE title" name, for example, "Enables Data Access".
    case title
}

/// A section that contains details about a property list key.
struct PlistDetailsRenderSection: RenderSection {
    public var kind: RenderSectionKind = .plistDetails
    /// A title for the section.
    public var title = "Details"
    
    /// Details for a property list key.
    struct Details: Codable {
        /// The name of the key.
        let name: String
        /// A list of types acceptable for this key's value.
        let value: [TypeDetails]
        /// A list of platforms to which this key applies.
        let platforms: [String]
        /// An optional, human-friendly name of the key.
        let ideTitle: String?
        /// A title rendering style.
        let titleStyle: TitleStyle
    }
    
    /// The details of the property key.
    public let details: Details
    
    // MARK: - Codable
    
    /// The list of keys you use to encode or decode this details section.
    public enum CodingKeys: String, CodingKey {
        case kind, title, details
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        details = try container.decode(Details.self, forKey: .details)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
    }
}
