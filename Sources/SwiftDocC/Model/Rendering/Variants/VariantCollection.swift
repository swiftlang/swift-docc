/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A collection of variants for a render node value.
///
/// Variant collections encapsulate different values for the same piece of content. Each variant collection has a default value and optionally, trait-specific
/// (e.g., programming language–specific) values that client can choose to use based on their context.
///
/// For example, a collection can a hold programming language-agnostic documentation value as its ``defaultValue``, and hold Objective-C specific values
/// in its ``variants`` array. Clients that want to process the Objective-C version of a documentation page then use the override rather than the
/// default value, and fall back to the default value if no Objective-C-specific override is specified.
public struct VariantCollection<Value: Codable>: Codable {
    /// The default value of the variant.
    ///
    /// Clients should decide whether the `defaultValue` or a value in ``variants`` is appropriate in their context.
    public var defaultValue: Value
    
    /// Trait-specific overrides for the default value.
    ///
    /// Clients should decide whether the `defaultValue` or a value in ``variants`` is appropriate in their context.
    public var variants: [Variant<Value>]
    
    /// Creates a variant collection given a default value and an array of trait-specific overrides.
    ///
    /// - Parameters:
    ///   - defaultValue: The default value of the variant.
    ///   - variantOverrides: The trait-specific overrides for the value.
    public init(defaultValue: Value, variants: [Variant<Value>] = []) {
        self.defaultValue = defaultValue
        self.variants = variants
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.defaultValue = try container.decode(Value.self)
        
        // When decoding a render node, the variants overrides stored in the `RenderNode.variantOverrides` property.
        self.variants = []
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(defaultValue)
        addVariantsToEncoder(encoder)
    }
    
    /// Adds the variants of the collection to the given encoder.
    ///
    /// - Parameters:
    ///   - encoder: The encoder to add the variants to.
    ///   - pointer: The pointer that should be used for the variants. If `nil`, the encoder's current coding path will be used.
    ///   - isDefaultValueEncoded: Whether the default value for this topic collection has been encoded in the encoder's container. If it hasn't, this function
    ///   replaces the variants' 'replace' patch operations with 'add' operations, since the container has no value to replace.
    func addVariantsToEncoder(
        _ encoder: Encoder,
        pointer: JSONPointer? = nil,
        isDefaultValueEncoded: Bool = true
    ) {
        let overrides = variants.map { variant in
            VariantOverride(
                traits: variant.traits,
                patch: variant.patch.map { patchOperation in
                    var patchOperation = patchOperation
                    
                    // If the default value for this variant collection wasn't encoded in the JSON and the
                    // patch operation is a 'replace', change it to an 'add' since there's no value to replace.
                    if !isDefaultValueEncoded, case .replace(let value) = patchOperation {
                        patchOperation = .add(value: value)
                    }
                    
                    let jsonPointer = (
                        pointer ?? JSONPointer(from: encoder.codingPath)
                    ).prependingPathComponents(encoder.baseJSONPatchPath ?? [])
                    
                    return JSONPatchOperation(
                        variantPatchOperation: patchOperation,
                        pointer: jsonPointer
                    )
                }
            )
        }
        
        encoder.userInfoVariantOverrides?.add(contentsOf: overrides)
    }
    
    /// Returns a variant collection containing the results of calling the given transformation with each value of this variant collection.
    public func mapValues<TransformedValue>(
        _ transform: (Value) -> TransformedValue
    ) -> VariantCollection<TransformedValue> {
        VariantCollection<TransformedValue>(
            defaultValue: transform(defaultValue),
            variants: variants.map { variant in
                variant.mapPatch(transform)
            }
        )
    }
}
