/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
private import DocCCommon

extension RenderNode: Codable {
    enum CodingKeys: CodingKey {
        case schemaVersion, identifier, sections, references, metadata, kind, hierarchy
        case abstract, topicSections, topicSectionsStyle, defaultImplementationsSections, primaryContentSections, relationshipsSections, declarationSections, seeAlsoSections, returnsSection, parametersSection, sampleCodeDownload, downloadNotAvailableSummary, deprecationSummary, diffAvailability, interfaceLanguage, variants, variantOverrides
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(SemanticVersion.self, forKey: .schemaVersion)
        
        identifier = try container.decode(ResolvedTopicReference.self, forKey: .identifier)
        sections = try container.decode([CodableRenderSection].self, forKey: .sections).map { $0.section }
        references = try (container.decodeIfPresent([String: CodableRenderReference].self, forKey: .references) ?? [:]).mapValues({$0.reference})
        metadata = try container.decode(RenderMetadata.self, forKey: .metadata)
        kind = try container.decode(Kind.self, forKey: .kind)
        hierarchyVariants = try container.decodeVariantCollectionIfPresent(
            ofValueType: RenderHierarchy?.self,
            forKey: .hierarchy
        ) ?? .init(defaultValue: nil)
        topicSectionsStyle = try container.decodeIfPresent(TopicsSectionStyle.self, forKey: .topicSectionsStyle) ?? .list
        
        // Decoding RenderNode values is a bit complicated because of the variant overrides that lose the type information in the encoded data.
        //
        // To get the information about the variant values back into the variant collections, first decode only the default variant values.
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
        
        // After decoding the default variant values, check if there are any variant overrides that need to be applied.
        if container.allKeys.contains(.variantOverrides) {
            // Because the variant collections lost the information about the type of value when they transformed `VariantPatchOperation<Value>` into `JSONPatch`,
            // we need to inspect each variant overrides JSONPointer to trace which property it overrides to know what type to decode the patch's value as.
            
            // Iterate over each override
            var overridesListContainer = try container.nestedUnkeyedContainer(forKey: .variantOverrides)
            while !overridesListContainer.isAtEnd {
                let overrideContainer = try overridesListContainer.nestedContainer(keyedBy: OverrideCodingKeys.self)
                let traits = try overrideContainer.decode([RenderNode.Variant.Trait].self, forKey: .traits)
                
                // Iterate over each patch in that override
                var patchesListContainer = try overrideContainer.nestedUnkeyedContainer(forKey: .patch)
                while !patchesListContainer.isAtEnd {
                    let patchContainer = try patchesListContainer.nestedContainer(keyedBy: JSONPatchOperation.CodingKeys.self)
                    
                    // Decode only the type of patch operation and pointer.
                    // The value can only be decoded after tracing the pointer to the property it refers to.
                    let operation = try patchContainer.decode(PatchOperation.self, forKey: .operation)
                    let pointer = try patchContainer.decode(JSONPointer.self, forKey: .pointer)
                    
                    // To trace what the the JSON pointer is referring to, we inspect one path component at a time.
                    var remainingPathComponents = pointer.pathComponents
                    
                    guard !remainingPathComponents.isEmpty else {
                        throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unsupported JSON patch with empty 'path'")
                    }
                    
                    /// A small helper that creates a decoding error about an unsupported JSON patch value.
                    func makeUnsupportedJSONPatchError() -> DecodingError {
                        DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unsupported JSON patch for non-variant: \(operation.rawValue) at \(pointer)")
                    }
                    
                    // The first JSON pointer component is accessing some RenderNode property
                    switch RenderNode.CodingKeys(stringValue: remainingPathComponents.removeFirst()) {
                    case nil:
                        continue // This patch doesn't match any known RenderNode key. It may have been for an older format. Skip it.
                        
                    case .identifier:
                        // The only "identifier" element that we expect to patch is the language and we expect it to be fully replaced
                        guard remainingPathComponents == [ResolvedTopicReference.CodingKeys.interfaceLanguage.stringValue], operation == .replace else {
                            throw makeUnsupportedJSONPatchError()
                        }
                        // Instead of replacing the language we add it to the reference
                        let languageID = try patchContainer.decode(String.self, forKey: .value)
                        identifier = identifier.addingSourceLanguages([SourceLanguage(id: languageID)])
                        
                    // Raise a decoding error for any of the non-varying RenderNode properties
                    case .schemaVersion,
                         .kind,
                         .hierarchy,
                         .topicSectionsStyle,
                         .diffAvailability,
                         .sampleCodeDownload,
                         .downloadNotAvailableSummary,
                         .sections:
                        fallthrough
                    // Raise a decoding error for any of the old RenderNode properties
                    case .returnsSection,
                         .declarationSections,
                         .parametersSection,
                         .interfaceLanguage:
                        throw makeUnsupportedJSONPatchError()
                        
                    // Ignore the variant properties themselves
                    case .variantOverrides, .variants:
                        continue
                        
                    // Decode patches for the `[Value]` collections
                    case .topicSections:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &topicSectionsVariants, for: traits)
                    case .relationshipsSections:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &relationshipSectionsVariants, for: traits)
                    case .defaultImplementationsSections:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &defaultImplementationsSectionsVariants, for: traits)
                    case .seeAlsoSections:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &seeAlsoSectionsVariants, for: traits)
                          
                    // Decode patches for the `[Value]?` collections
                    case .abstract:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &abstractVariants, for: traits)
                    case .deprecationSummary:
                        try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &deprecationSummaryVariants, for: traits)

                    // Decode the patch for the primary content sections variant. Rather than a collection of `[Value?]`,
                    // the primary content sections is an array of variant collections of `Value?`
                    // Because it's the only property with this structure we have a fully custom implementation for it.
                    case .primaryContentSections:
                        // This is an array of `CodableContentSection?` value it's possible that we're modifying individual elements
                        if remainingPathComponents.isEmpty {
                            // The patch applies to the array of `CodableContentSection?` values
                            switch operation {
                            case .replace:
                                if try patchContainer.decodeNil(forKey: .value) {
                                    // Replacing with nothing is the same as removing
                                    primaryContentSectionsVariants = []
                                } else {
                                    let values = try patchContainer.decode([CodableContentSection?].self, forKey: .value)
                                    
                                    // Replace all the values
                                    for (index, value) in values.enumerated() {
                                        if primaryContentSectionsVariants.indices.contains(index) {
                                            primaryContentSectionsVariants[index].addPatch(.replace(value: value), toVariantWithTraits: traits)
                                        } else {
                                            primaryContentSectionsVariants[index] = VariantCollection(
                                                defaultValue: nil,
                                                variants: [.init(traits: traits, patch: [.replace(value: value)])]
                                            )
                                        }
                                    }
                                    let countDifference = primaryContentSectionsVariants.count - values.count
                                    if countDifference == 0 {
                                        // All values are already replaced
                                        continue
                                    } else if countDifference < 0 {
                                        // There are more variant values than default values. Those need to be added.
                                        for value in values.dropFirst(primaryContentSections.count) {
                                            primaryContentSectionsVariants.append(VariantCollection(
                                                defaultValue: nil,
                                                variants: [.init(traits: traits, patch: [.replace(value: value)])]
                                            ))
                                        }
                                    } else {
                                        // There are fewer variant values than default values. Those extra default values need to be removed.
                                        for index in countDifference ..< primaryContentSectionsVariants.count {
                                            primaryContentSectionsVariants[index].addPatch(.remove, toVariantWithTraits: traits)
                                        }
                                    }
                                }
                            case .add:
                                if try patchContainer.decodeNil(forKey: .value) {
                                    // Adding nothing is the same as doing nothing
                                    continue
                                } else {
                                    let values = try patchContainer.decode([CodableContentSection?].self, forKey: .value)
                                    
                                    for value in values {
                                        // Since 'primaryContentSectionsVariants' is an array of variant collections, adding values is the same as adding more variant collections
                                        // with a 'nil' default value and a replacement to the variant value
                                        primaryContentSectionsVariants.append(VariantCollection(
                                            defaultValue: nil,
                                            variants: [.init(traits: traits, patch: [.replace(value: value)])]
                                        ))
                                    }
                                }
                            case .remove:
                                for index in primaryContentSectionsVariants.indices {
                                    primaryContentSectionsVariants[index].addPatch(.remove, toVariantWithTraits: traits)
                                }
                            }
                        } else if let index = remainingPathComponents.first.flatMap(Int.init) {
                            // The patch applies to an individual TaskGroupRenderSection value but VariantCollection can only store [TaskGroupRenderSection] patches
                            guard remainingPathComponents.count == 1 else {
                                throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unsupported JSON patch for modification of individual property of an element in a list: \(operation.rawValue) at \(pointer).")
                            }
                            
                            guard primaryContentSectionsVariants.indices.contains(index) else {
                                throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "JSON patch index \(index) is out of bounds for collection with \(primaryContentSectionsVariants.count) elements at \(pointer).")
                            }
                            switch operation {
                            case .replace:
                                let value = try patchContainer.decode(CodableContentSection?.self, forKey: .value)
                                primaryContentSectionsVariants[index].addPatch(.replace(value: value), toVariantWithTraits: traits)
                            case .add:
                                let value = try patchContainer.decode(CodableContentSection?.self, forKey: .value)
                                primaryContentSectionsVariants[index].addPatch(.add(value: value), toVariantWithTraits: traits)
                            case .remove:
                                primaryContentSectionsVariants[index].addPatch(.remove, toVariantWithTraits: traits)
                            }
                        } else {
                            // There was a string patch component after an component for an array
                            throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unexpected non-index JSON patch for element of list: \(operation.rawValue) at \(pointer).")
                        }
                        
                        
                    // Decode the patches for the references.
                    case .references:
                        guard !remainingPathComponents.isEmpty else {
                            // The 'references' dictionary itself isn't a variant, only its values or their properties can vary
                            throw makeUnsupportedJSONPatchError()
                        }
                        let key = remainingPathComponents.removeFirst()
                        guard let found = references[key] else {
                            // The 'references' dictionary itself isn't a variant, we can't add, remove, or replace its elements
                            throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unexpected \(operation.rawValue) JSON patch for value that doesn't exist in dictionary: \(operation.rawValue) at \(pointer).")
                            
                        }
                        guard var topicReference = found as? TopicRenderReference else {
                            // TopicRenderReference is the only type of reference that has variant properties.
                            throw DecodingError.dataCorruptedError(forKey: .pointer, in: patchContainer, debugDescription: "Unsupported JSON patch for non-variant element: \(operation.rawValue) at \(pointer).")
                        }
                        guard !remainingPathComponents.isEmpty else {
                            // TopicRenderReference itself isn't a variant and none of its properties are collections of variants
                            throw makeUnsupportedJSONPatchError()
                        }
                        switch TopicRenderReference.CodingKeys(stringValue: remainingPathComponents.removeFirst()) {
                        case nil:
                            continue // This patch doesn't match any known RenderNode key. It may have been for an older format or for a custom "unknown" value which is non-varying. Skip it.
                            
                        // Raise a decoding error for any of the non-varying RenderNode properties
                        case .type,
                             .identifier,
                             .url,
                             .kind,
                             .required,
                             .role,
                             .conformance,
                             .estimatedTime,
                             .defaultImplementations,
                             .beta,
                             .deprecated,
                             .propertyListTitleStyle,
                             .propertyListRawKey,
                             .propertyListDisplayName,
                             .tags,
                             .images:
                            throw makeUnsupportedJSONPatchError()
                            
                        case .title:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &topicReference.titleVariants, for: traits)
                        case .abstract:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &topicReference.abstractVariants, for: traits)
                        case .fragments:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &topicReference.fragmentsVariants, for: traits)
                        case .navigatorTitle:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &topicReference.navigatorTitleVariants, for: traits)
                        }
                        
                        references[key] = topicReference
                    
                    // Decode the data for all RenderNode properties that has variants
                    case .metadata:
                        guard !remainingPathComponents.isEmpty else {
                            // The metadata itself isn't a variant. Patches can only apply to properties of the metadata.
                            throw makeUnsupportedJSONPatchError()
                        }
                        switch RenderMetadata.KnownCodingKeys(stringValue: remainingPathComponents.removeFirst()) {
                        case nil:
                            continue // This patch doesn't match any known RenderNode key. It may have been for an older format or for a custom "unknown" value which is non-varying. Skip it.
                            
                        // Raise a decoding error for any of the non-varying RenderMetadata properties
                        case .category,
                             .categoryPathComponent,
                             .estimatedTime,
                             .role,
                             .images,
                             .color,
                             .conformance,
                             .tags,
                             .customMetadata,
                             .hasNoExpandedDocumentation:
                            throw makeUnsupportedJSONPatchError()
                            
                        // Decode patches for all scalar metadata values
                        case .modules:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.modulesVariants, for: traits)
                        case .extendedModule:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.extendedModuleVariants, for: traits)
                        case .required:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.requiredVariants, for: traits)
                        case .roleHeading:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.roleHeadingVariants, for: traits)
                        case .title:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.titleVariants, for: traits)
                        case .externalID:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.externalIDVariants, for: traits)
                        case .symbolKind:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.symbolKindVariants, for: traits)
                        case .symbolAccessLevel:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.symbolAccessLevelVariants, for: traits)
                        case .sourceFileURI:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.sourceFileURIVariants, for: traits)
                        case .remoteSource:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.remoteSourceVariants, for: traits)
                        case .fragments:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.fragmentsVariants, for: traits)
                        case .navigatorTitle:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.navigatorTitleVariants, for: traits)
                        case .platforms:
                            try patchContainer.decodePatch(operation: operation, remainingPathComponents: remainingPathComponents, andAddTo: &metadata.platformsVariants, for: traits)
                        }
                    }
                }
            }
        }
    }
    
    private enum OverrideCodingKeys: String, CodingKey {
        case traits, patch
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(identifier, forKey: .identifier)
        try container.encode(sections.map(CodableRenderSection.init), forKey: .sections)
        
        try container.encode(metadata, forKey: .metadata)
        try container.encode(kind, forKey: .kind)
        try container.encodeVariantCollection(hierarchyVariants, forKey: .hierarchy, encoder: encoder)
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
        
        try container.encodeVariantCollectionIfNotEmpty(deprecationSummaryVariants, forKey: .deprecationSummary, encoder: encoder)
        
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
            let variantOverrides = encoder.userInfoVariantOverrides,
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
    mutating func encodeIfNotEmpty(_ value: some Encodable & Collection, forKey key: KeyedEncodingContainer.Key) throws {
        if !value.isEmpty {
            try encode(value, forKey: key)
        }
    }
    
    /// Encodes the given boolean if its value is true.
    mutating func encodeIfTrue(_ value: Bool, forKey key: Key) throws {
        if value {
            try encode(value, forKey: key)
        }
    }
}

// MARK: Decoding VariantPatchOperation

private extension VariantCollection {
    mutating func addPatch(_ patch: VariantPatchOperation<Value>, toVariantWithTraits traits: [RenderNode.Variant.Trait]) {
        if let existingIndex = variants.firstIndex(where: { $0.traits == traits }) {
            variants[existingIndex].patch.append(patch)
        } else {
            variants.append(.init(traits: traits, patch: [patch]))
        }
    }
}

private extension KeyedDecodingContainer<JSONPatchOperation.CodingKeys> {
    // Array
    
    func decodePatch<Value>(
        operation: PatchOperation,
        remainingPathComponents: [String],
        andAddTo variantCollection: inout VariantCollection<[Value]>,
        for traits: [RenderNode.Variant.Trait]
    ) throws {
        variantCollection.addPatch(
            try _decodeArrayPatch(
                mainValue: variantCollection.value(for: traits),
                operation: operation,
                pathComponents: remainingPathComponents
            ),
            toVariantWithTraits: traits
        )
    }
    
    // Scalar
    
    @_disfavoredOverload
    func decodePatch<Value>(
        operation: PatchOperation,
        remainingPathComponents: [String],
        andAddTo variantCollection: inout VariantCollection<Value>,
        for traits: [RenderNode.Variant.Trait]
    ) throws {
        variantCollection.addPatch(
            try _decodeScalarPatch(operation: operation, pathComponents: remainingPathComponents),
            toVariantWithTraits: traits
        )
    }
    
    // Optional array
    
    func decodePatch<Value>(
        operation: PatchOperation,
        remainingPathComponents: [String],
        andAddTo variantCollection: inout VariantCollection<[Value]?>,
        for traits: [RenderNode.Variant.Trait]
    ) throws {
        variantCollection.addPatch(
            try _decodeOptionalArrayPatch(
                mainValue: variantCollection.value(for: traits),
                operation: operation, 
                pathComponents: remainingPathComponents
            ),
            toVariantWithTraits: traits
        )
    }
    
    // MARK: Patch decoding details
    
    var _pointer: JSONPointer {
        get throws { // lazily compute for error messages
            try decode(JSONPointer.self, forKey: .pointer)
        }
    }
    
    func _decodeScalarPatch<Value>(
        operation: PatchOperation,
        pathComponents: [String],
        nilValue: (() -> Value)? = nil
    ) throws -> VariantPatchOperation<Value> {
        
        guard pathComponents.isEmpty else {
            // The modules themselves aren't variant values
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "Unsupported JSON patch for non-variant: \(operation.rawValue) at \(try _pointer).")
        }
        switch operation {
        case .replace:
            if try decodeNil(forKey: .value) {
                guard let value = nilValue?() else {
                    throw DecodingError.dataCorruptedError(forKey: .value, in: self, debugDescription: "Unexpected 'null' value for \(operation.rawValue) JSON patch at \(try _pointer).")
                }
                return .replace(value: value)
            }
            let value = try decode(Value.self, forKey: .value)
            return .replace(value: value)
        case .add:
            if try decodeNil(forKey: .value) {
                guard let value = nilValue?() else {
                    throw DecodingError.dataCorruptedError(forKey: .value, in: self, debugDescription: "Unexpected 'null' value for \(operation.rawValue) JSON patch at \(try _pointer).")
                }
                return .add(value: value)
            }
            let value = try decode(Value.self, forKey: .value)
            return .add(value: value)
        case .remove:
            return .remove
        }
    }
    
    func _decodeArrayPatch<Value>(
        mainValue: @autoclosure () -> [Value],
        operation: PatchOperation,
        pathComponents: [String]
    ) throws -> VariantPatchOperation<[Value]> {
        guard !pathComponents.isEmpty else {
            // The patch applies to the array of values, replace it as a scalar
            return try _decodeScalarPatch(operation: operation, pathComponents: pathComponents, nilValue: { [] })
        }
        
        // The patch applies to an individual value but VariantCollection can only store [Value] patches
        var remainingPathComponents = pathComponents
        
        guard let index = Int(remainingPathComponents.removeFirst()) else {
            // It's only possible to subscript an array using an integer index.
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "Unexpected non-index JSON patch for element of list: \(operation.rawValue) at \(try _pointer).")
        }
        
        guard remainingPathComponents.isEmpty else {
            // None of the variant collections hold values that are variant collections. Thus, in practice we don't support patches to individual properties of elements of any list.
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "Unsupported JSON patch for modification of individual property of an element in a list: \(operation.rawValue) at \(try _pointer).")
        }
        
        var modifiedValue = mainValue()
        guard modifiedValue.indices.contains(index) else {
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "JSON patch index \(index) is out of bounds for collection with \(modifiedValue.count) elements at \(try _pointer).")
        }
        switch operation {
        case .replace:
            let value = try decode(Value.self, forKey: .value)
            modifiedValue[index] = value
        case .add:
            let value = try decode(Value.self, forKey: .value)
            modifiedValue.insert(value, at: index)
        case .remove:
            modifiedValue.remove(at: index)
        }
        return .replace(value: modifiedValue)
    }
    
    
    func _decodeOptionalArrayPatch<Value>(
        mainValue: @autoclosure () -> [Value]?,
        operation: PatchOperation,
        pathComponents: [String],
        nilValue: (() -> [Value])? = nil
    ) throws -> VariantPatchOperation<[Value]?> {
        guard !pathComponents.isEmpty else {
            // The patch applies to the array of values, replace it as a scalar
            return try _decodeScalarPatch(operation: operation, pathComponents: pathComponents, nilValue: { [] })
        }
        
        // The patch applies to an individual value but VariantCollection can only store [Value] patches
        var remainingPathComponents = pathComponents
        
        guard let index = Int(remainingPathComponents.removeFirst()) else {
            // It's only possible to subscript an array using an integer index.
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "Unexpected non-index JSON patch for element of list: \(operation.rawValue) at \(try _pointer).")
        }
        
        guard remainingPathComponents.isEmpty else {
            // None of the variant collections hold values that are variant collections. Thus, in practice we don't support patches to individual properties of elements of any list.
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "Unsupported JSON patch for modification of individual property of an element in a list: \(operation.rawValue) at \(try _pointer).")
        }
        
        var modifiedValue = mainValue() ?? []
        guard modifiedValue.indices.contains(index) else {
            throw DecodingError.dataCorruptedError(forKey: .pointer, in: self, debugDescription: "JSON patch index \(index) is out of bounds for collection with \(modifiedValue.count) elements at \(try _pointer).")
        }
        switch operation {
        case .replace:
            let value = try decode(Value.self, forKey: .value)
            modifiedValue[index] = value
        case .add:
            let value = try decode(Value.self, forKey: .value)
            modifiedValue.insert(value, at: index)
        case .remove:
            modifiedValue.remove(at: index)
        }
        return .replace(value: modifiedValue)
    }
}
