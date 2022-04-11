/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a list of properties.
///
/// Group ``RenderProperty`` properties in this section.
public struct PropertiesRenderSection: RenderSection {
    public var kind: RenderSectionKind = .properties
    /// The title for this section.
    public let title: String
    /// The list of properties.
    public let items: [RenderProperty]

    /// Creates a new property-list section.
    /// - Parameters:
    ///   - title: The title for this section.
    ///   - items: The list of properties.
    public init(title: String, items: [RenderProperty]) {
        self.title = title
        self.items = items
    }
    
    // MARK: - Codable
    
    /// The list of keys to use to encode/decode this section.
    public enum CodingKeys: String, CodingKey {
        case kind, title, items
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        items = try container.decode([RenderProperty].self, forKey: .items)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encode(items, forKey: .items)
    }
}

/// A named property with a declaration-style type, content, and
/// an optional list of attributes.
public struct RenderProperty: Codable, TextIndexing, Equatable {
    /// The name of the property.
    public let name: String
    /// The list of possible type declarations for the property's value.
    public let type: [DeclarationRenderSection.Token]
    /// The list of possible type declarations for the property's value including additional details, if available.
    public let typeDetails: [TypeDetails]?
    /// Additional details about the property, if available.
    public let content: [RenderBlockContent]?
    /// Additional list of attributes, if any.
    public let attributes: [RenderAttribute]?
    /// A mime-type associated with the property, if applicable.
    public let mimeType: String?
    /// If true, the property is required in its containing context.
    public var required: Bool? = false
    /// If true, the property is deprecated.
    public var deprecated: Bool? = false
    /// If true, the property can only be accessed and not modified.
    public var readOnly: Bool? = false
    /// A version of the platform that first introduced the property, if known.
    public var introducedVersion: String?
}

/// A type's details, including whether it's an array, and optionally the element's type.
public struct TypeDetails: Codable, Equatable {
    /// A base type name.
    ///
    /// The plain text name of a symbol's base type. For example, `Int` for an array of integers.
    public var baseType: String?
    /// If true, the type is an array.
    public var arrayMode: Bool? = false
}
