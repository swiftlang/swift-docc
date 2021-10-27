/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A utility type to apply variant overrides to an encoded render node.
public struct RenderNodeVariantOverridesApplier {
    /// Creates a variant overrides applier.
    public init() {}
    
    /// Applies variant overrides of the given trait to the given encoded render node.
    /// - Parameters:
    ///   - renderNodeData: The render node on which to apply the variant override, encoded in JSON.
    ///   - traits: The traits associated with the patch to apply.
    /// - Returns: The render node with the patch applied, encoded in JSON.
    public func applyVariantOverrides(in renderNodeData: Data, for traits: [RenderNode.Variant.Trait]) throws -> Data {
        let variantOverrides = try JSONDecoder().decode(
            RenderNodeVariantsProxy.self,
            from: renderNodeData
        ).variantOverrides
        
        guard let patch = variantOverrides?.values.first(where: { $0.traits == traits })?.patch else {
            return renderNodeData
        }
        
        // Remove the `variantOverrides` property of the render node.
        let removeVariantOverridesPatch = JSONPatchOperation.remove(
            pointer: JSONPointer(pathComponents: ["variantOverrides"])
        )
        
        return try JSONPatchApplier().apply(patch + [removeVariantOverridesPatch], to: renderNodeData)
    }
    
    /// A proxy type for decoding only the variant overrides of a render node.
    private struct RenderNodeVariantsProxy: Codable {
        var variantOverrides: VariantOverrides?
    }
    
    /// An error that occured while applying overrides in a render node.
    public enum Error: DescribedError {
        /// An error indicating that the error node is corrupted or malformed.
        case corruptedRenderNode
        
        public var errorDescription: String {
            switch self {
            case .corruptedRenderNode:
                return "Corrupted or malformed render node value."
            }
        }
    }
}
