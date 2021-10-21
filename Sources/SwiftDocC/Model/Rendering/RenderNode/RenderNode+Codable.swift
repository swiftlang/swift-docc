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
        case abstract, topicSections, defaultImplementationsSections, primaryContentSections, relationshipsSections, declarationSections, seeAlsoSections, returnsSection, parametersSection, sampleCodeDownload, downloadNotAvailableSummary, deprecationSummary, diffAvailability, interfaceLanguage, variants, variantOverrides
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
        
        primaryContentSections = (try container.decodeIfPresent([CodableContentSection].self, forKey: .primaryContentSections) ?? [CodableContentSection]()).map { $0.section }
        relationshipSections = try container.decodeIfPresent([RelationshipsRenderSection].self, forKey: .relationshipsSections) ?? []
        topicSections = try container.decodeIfPresent([TaskGroupRenderSection].self, forKey: .topicSections) ?? []
        defaultImplementationsSections = try container.decodeIfPresent([TaskGroupRenderSection].self, forKey: .defaultImplementationsSections) ?? []
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract)
        seeAlsoSections = try container.decodeIfPresent([TaskGroupRenderSection].self, forKey: .seeAlsoSections) ?? []
        sampleDownload = try container.decodeIfPresent(SampleDownloadSection.self, forKey: .sampleCodeDownload)
        downloadNotAvailableSummary = try container.decodeIfPresent([RenderBlockContent].self, forKey: .downloadNotAvailableSummary)
        deprecationSummary = try container.decodeIfPresent([RenderBlockContent].self, forKey: .deprecationSummary)
        diffAvailability = try container.decodeIfPresent(DiffAvailability.self, forKey: .diffAvailability)
        variants = try container.decodeIfPresent([RenderNode.Variant].self, forKey: .variants)
        variantOverrides = try container.decodeIfPresent(VariantOverrides.self, forKey: .variantOverrides)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(sections.map(CodableRenderSection.init), forKey: .sections)
        
        // Encode references if the `.skipsEncodingReferences` value is unset or false.
        if (encoder.userInfo[.skipsEncodingReferences] as? Bool) != true {
            try container.encode(references.mapValues(CodableRenderReference.init), forKey: .references)
        }
        
        try container.encode(metadata, forKey: .metadata)
        try container.encode(kind, forKey: .kind)
        try container.encode(hierarchy, forKey: .hierarchy)
        
        try container.encodeIfPresent(abstract, forKey: .abstract)
        
        try container.encodeIfNotEmpty(topicSections, forKey: .topicSections)
        try container.encodeIfNotEmpty(defaultImplementationsSections, forKey: .defaultImplementationsSections)
        try container.encodeIfNotEmpty(relationshipSections, forKey: .relationshipsSections)
        try container.encodeIfNotEmpty(seeAlsoSections, forKey: .seeAlsoSections)
        try container.encodeIfNotEmpty(primaryContentSections.map(CodableContentSection.init), forKey: .primaryContentSections)
        
        try container.encodeIfPresent(sampleDownload, forKey: .sampleCodeDownload)
        try container.encodeIfPresent(downloadNotAvailableSummary, forKey: .downloadNotAvailableSummary)
        try container.encodeIfPresent(deprecationSummary, forKey: .deprecationSummary)
        try container.encodeIfPresent(diffAvailability, forKey: .diffAvailability)
        try container.encodeIfPresent(variants, forKey: .variants)
        
        // Emit the variant overrides that are defined on the render node, if present. Otherwise, the variant overrides
        // that have been accumulated while encoding the properties of the render node.
        if let variantOverrides = variantOverrides ?? encoder.userInfo[.variantOverrides] as? VariantOverrides,
            !variantOverrides.isEmpty
        {
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
