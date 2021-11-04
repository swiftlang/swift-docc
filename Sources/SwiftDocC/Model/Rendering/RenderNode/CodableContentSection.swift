/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A Codable container for reference pages sections.
///
/// This allows decoding a ``RenderSection`` into its appropriate concrete type, based on the section's
/// ``RenderSection/kind``.
public struct CodableContentSection: Codable {
    var section: RenderSection
    
    /// Creates a codable content section from the given section.
    public init(_ section: RenderSection) {
        self.section = section
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(RenderSectionKind.self, forKey: .kind)
        
        switch kind {
            case .discussion:
                section = try ContentRenderSection(from: decoder)
            case .content:
                section = try ContentRenderSection(from: decoder)
            case .taskGroup:
                section = try TaskGroupRenderSection(from: decoder)
            case .relationships:
                section = try RelationshipsRenderSection(from: decoder)
            case .declarations:
                section = try DeclarationsRenderSection(from: decoder)
            case .parameters:
                section = try ParametersRenderSection(from: decoder)
            case .attributes:
                section = try AttributesRenderSection(from: decoder)
            case .properties:
                section = try PropertiesRenderSection(from: decoder)
            case .restParameters:
                section = try RESTParametersRenderSection(from: decoder)
            case .restEndpoint:
                section = try RESTEndpointRenderSection(from: decoder)
            case .restBody:
                section = try RESTBodyRenderSection(from: decoder)
            case .restResponses:
                section = try RESTResponseRenderSection(from: decoder)
            case .plistDetails:
                section = try PlistDetailsRenderSection(from: decoder)
            case .possibleValues:
                section = try PossibleValuesRenderSection(from: decoder)
            default: fatalError()
        }
    }

    private enum CodingKeys: CodingKey {
        case kind
    }
    
    public func encode(to encoder: Encoder) throws {
        try section.encode(to: encoder)
    }
}
