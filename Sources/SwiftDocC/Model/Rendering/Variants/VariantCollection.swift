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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(defaultValue)
        
        let overrides = variants.map { variant in
            VariantOverride(
                traits: variant.traits,
                patch: variant.patch.map { patch in
                    JSONPatchOperation(variantPatch: patch, pointer: JSONPointer(from: encoder.codingPath))
                }
            )
        }
        
        encoder.userInfoVariantOverrides?.add(contentsOf: overrides)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.defaultValue = try container.decode(Value.self)
        
        // When decoding a render node, the variants overrides stored in the `RenderNode.variantOverrides` property.
        self.variants = []
    }
}

public extension VariantCollection {
    /// A variant for a render node value.
    struct Variant<Value: Codable>: Codable {
        /// The traits associated with the override.
        public var traits: [RenderNode.Variant.Trait]
        
        /// The patch to apply as part of the override.
        public var patch: [VariantPatchOperation<Value>]
        
        /// Creates an override value for the given traits.
        ///
        /// - Parameters:
        ///   - traits: The traits associated with this override value.
        ///   - patch: The patch to apply as part of the override.
        public init(traits: [RenderNode.Variant.Trait], patch: [VariantPatchOperation<Value>]) {
            self.traits = traits
            self.patch = patch
        }
    }

}
