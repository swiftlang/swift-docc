/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a list of attributes.
public struct AttributesRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .attributes
    /// The section title.
    public let title: String
    /// The list of attributes in this section.
    public let attributes: [RenderAttribute]?
    
    /// Creates a new attributes section.
    /// - Parameter title: The section title.
    /// - Parameter attributes: The list of attributes.
    public init(title: String, attributes: [RenderAttribute]) {
        self.title = title
        self.attributes = attributes
    }
    
    // MARK: - Codable
    
    /// The list of keys you use to encode or decode the section data.
    public enum CodingKeys: String, CodingKey {
        case kind, title, attributes
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        attributes = try container.decodeIfPresent([RenderAttribute].self, forKey: .attributes)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(attributes, forKey: .attributes)
    }
}

/// A single renderable attribute.
public enum RenderAttribute: Codable, Equatable {
    /// The list of keys to use to encode/decode the attribute.
    public enum CodingKeys: CodingKey, Hashable {
        case title, value, values, kind
    }
    
    /// A list of the plain-text names of supported attributes.
    public enum Kind: String, Codable {
        case `default`, minimum, minimumExclusive, maximum, maximumExclusive, allowedValues, allowedTypes
    }
    /// A default value, for example `none`.
    case `default`(String)
    /// A minimum value, for example `1.0`.
    case minimum(String)
    /// A minimum value (excluding the given one) for example `1.0`.
    case minimumExclusive(String)
    /// A maximum value, for example `10.0`.
    case maximum(String)
    /// A maximum value (excluding the given one), for example `10.0`.
    case maximumExclusive(String)
    /// A list of allowed values, for example `none`, `some`, and `all`.
    case allowedValues([String])
    /// A list of allowed type declarations for the value being described,
    /// for example `String`, `Int`, and `Double`.
    case allowedTypes([[DeclarationRenderSection.Token]])
    
    /// A title for this attribute.
    var title: String {
        switch self {
        case .default: return "Default value"
        case .minimum: return "Minimum"
        case .minimumExclusive: return "Minimum"
        case .maximum: return "Maximum"
        case .maximumExclusive: return "Maximum"
        case .allowedValues: return "Possible Values"
        case .allowedTypes: return "Possible Types"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        switch try container.decode(Kind.self, forKey: .kind) {
        case .default:
            self = .default(try container.decode(String.self, forKey: .value))
        case .minimum:
            self = .minimum(try container.decode(String.self, forKey: .value))
        case .minimumExclusive:
            self = .minimumExclusive(try container.decode(String.self, forKey: .value))
        case .maximum:
            self = .maximum(try container.decode(String.self, forKey: .value))
        case .maximumExclusive:
            self = .maximumExclusive(try container.decode(String.self, forKey: .value))
        case .allowedValues:
            self = .allowedValues(try container.decode([String].self, forKey: .values))
        case .allowedTypes:
            self = .allowedTypes(try container.decode([[DeclarationRenderSection.Token]].self, forKey: .values))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .default(let value):
            try container.encode(Kind.default, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .minimum(let value):
            try container.encode(Kind.minimum, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .minimumExclusive(let value):
            try container.encode(Kind.minimumExclusive, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .maximum(let value):
            try container.encode(Kind.maximum, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .maximumExclusive(let value):
            try container.encode(Kind.maximumExclusive, forKey: .kind)
            try container.encodeIfPresent(value, forKey: .value)
        case .allowedValues(let values):
            try container.encode(Kind.allowedValues, forKey: .kind)
            try container.encodeIfPresent(values, forKey: .values)
        case .allowedTypes(let values):
            try container.encode(Kind.allowedTypes, forKey: .kind)
            try container.encodeIfPresent(values, forKey: .values)
        }
    }
}
