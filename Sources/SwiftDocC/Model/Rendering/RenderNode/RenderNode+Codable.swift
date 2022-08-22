/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension RenderNode: Codable {
    private enum CodingKeys: CodingKey {
        case schemaVersion, identifier, sections, references, metadata, kind, hierarchy
        case abstract, topicSections, topicSectionsStyle, defaultImplementationsSections, primaryContentSections, relationshipsSections, declarationSections, seeAlsoSections, returnsSection, parametersSection, sampleCodeDownload, downloadNotAvailableSummary, deprecationSummary, diffAvailability, interfaceLanguage, variants, variantOverrides
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SemanticVersion.self, forKey: .schemaVersion)
        
        identifier = try container.decode(ResolvedTopicReference.self, forKey: .identifier)
        sections = try container.decode([CodableRenderSection].self, forKey: .sections).map { $0.section }
        references = try container.decode([String: CodableRenderReference].self, forKey: .references).mapValues({$0.reference})
        metadata = try container.decode(RenderMetadata.self, forKey: .metadata)
        kind = try container.decode(Kind.self, forKey: .kind)
        hierarchy = try container.decodeIfPresent(RenderHierarchy.self, forKey: .hierarchy)
        topicSectionsStyle = try container.decodeIfPresent(TopicsSectionStyle.self, forKey: .topicSectionsStyle) ?? .list
        
        primaryContentSectionsVariants = try container.decodeVariantCollectionArrayIfPresent(
            ofValueType: CodableContentSection?.self,
            forKey: .primaryContentSections
        )
        
        relationshipSectionsVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [RelationshipsRenderSection].self,
            forKey: .relationshipsSections
        ) ?? .init(defaultValue: [])
        
        topicSectionsVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [TaskGroupRenderSection].self,
            forKey: .topicSections
        ) ?? .init(defaultValue: [])
        
        defaultImplementationsSectionsVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [TaskGroupRenderSection].self,
            forKey: .defaultImplementationsSections
        ) ?? .init(defaultValue: [])
        
        abstractVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [RenderInlineContent]?.self,
            forKey: .abstract
        )
        
        seeAlsoSectionsVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [TaskGroupRenderSection].self,
            forKey: .seeAlsoSections
        ) ?? .init(defaultValue: [])
        
        sampleDownload = try container.decodeIfPresent(SampleDownloadSection.self, forKey: .sampleCodeDownload)
        downloadNotAvailableSummary = try container.decodeIfPresent([RenderBlockContent].self, forKey: .downloadNotAvailableSummary)
        
        deprecationSummaryVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: [RenderBlockContent]?.self,
            forKey: .deprecationSummary
        )
        
        diffAvailability = try container.decodeIfPresent(DiffAvailability.self, forKey: .diffAvailability)
        variants = try container.decodeIfPresent([RenderNode.Variant].self, forKey: .variants)
        variantOverrides = try container.decodeIfPresent(VariantOverrides.self, forKey: .variantOverrides)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(sections.map(CodableRenderSection.init), forKey: .sections)
        
        try container.encode(metadata, forKey: .metadata)
        try container.encode(kind, forKey: .kind)
        try container.encode(hierarchy, forKey: .hierarchy)
        if topicSectionsStyle != .list {
            try container.encode(topicSectionsStyle, forKey: .topicSectionsStyle)
        }
        
        try container.encodeVariantCollection(abstractVariants, forKey: .abstract, encoder: encoder)
        
        try container.encodeVariantCollectionIfNotEmpty(topicSectionsVariants, forKey: .topicSections, encoder: encoder)
        try container.encodeVariantCollectionIfNotEmpty(defaultImplementationsSectionsVariants, forKey: .defaultImplementationsSections, encoder: encoder)
        try container.encodeVariantCollectionIfNotEmpty(relationshipSectionsVariants, forKey: .relationshipsSections, encoder: encoder)
        try container.encodeVariantCollectionIfNotEmpty(seeAlsoSectionsVariants, forKey: .seeAlsoSections, encoder: encoder)
        try container.encodeVariantCollectionArrayIfNotEmpty(primaryContentSectionsVariants, forKey: .primaryContentSections, encoder: encoder)
        
        try container.encodeIfPresent(sampleDownload, forKey: .sampleCodeDownload)
        try container.encodeIfPresent(downloadNotAvailableSummary, forKey: .downloadNotAvailableSummary)
        
        try container.encodeVariantCollection(deprecationSummaryVariants, forKey: .deprecationSummary, encoder: encoder)
        
        try container.encodeIfPresent(diffAvailability, forKey: .diffAvailability)
        try container.encodeIfPresent(variants, forKey: .variants)
        
        if !encoder.skipsEncodingReferences {
            try container.encode(references.mapValues(CodableRenderReference.init), forKey: .references)
        }
        
        // We should only encode variant overrides now if we're _not_ skipping the encoding of
        // references or if there are just no references to encode.
        //
        // Otherwise, any variant overrides that are accumulated while encoding the references
        // later on, will be missed.
        if !encoder.skipsEncodingReferences || references.isEmpty,
            let variantOverrides = variantOverrides ?? encoder.userInfoVariantOverrides,
            !variantOverrides.isEmpty
        {
            // Emit the variant overrides that are defined on the render node, if present.
            // Otherwise, the variant overrides
            // that have been accumulated while encoding the properties of the render node.
            try container.encode(variantOverrides, forKey: .variantOverrides)
        }
    }
}

extension KeyedEncodingContainer {
    /// Encodes the given `Collection<T>` if it contains any elements.
    mutating func encodeIfNotEmpty<T>(_ value: T, forKey key: KeyedEncodingContainer.Key) throws where T : Encodable, T : Collection {
        if !value.isEmpty {
            try encode(value, forKey: key)
        }
    }
}
