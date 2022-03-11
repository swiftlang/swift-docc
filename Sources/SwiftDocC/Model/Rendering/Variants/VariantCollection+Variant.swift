/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

public extension VariantCollection {
    /// A variant for a render node value.
    struct Variant<Value: Codable> {
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
        
        /// Returns a new variant collection containing the traits of this variant collection with the values transformed by the given closure.
        public func mapPatch<TransformedValue>(
            _ transform: (Value) -> TransformedValue
        ) -> VariantCollection<TransformedValue>.Variant<TransformedValue> {
            VariantCollection<TransformedValue>.Variant<TransformedValue>(
                traits: traits,
                patch: patch.map { patchOperation in patchOperation.map(transform) }
            )
        }
    }
}
