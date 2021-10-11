/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A transformation that removes unused references from a render node.
public struct RemoveUnusedReferencesTransformation: RenderNodeTransforming {
    /// Initializes a new transformer.
    public init() {}
    
    /// Removes references that are unreferenced in a given context from the given render node.
    ///
    /// A reference is considered "unreferenced" if the reference count for that reference in the transformation context is zero.
    ///
    /// - Parameters:
    ///   - renderNode: The render node from which to remove unreferenced references.
    ///   - context: The context that the transformer uses to determine which references are unreferenced.
    /// - Returns: The transformed render node and the unmodified context.
    public func transform(renderNode: RenderNode, context: RenderNodeTransformationContext) -> RenderNodeTransformationResult {
        var renderNode = renderNode
        let topicReferencesToRemove = context.referencesCount.filter { _, value in value <= 0 }.map { key, _ in key }
        renderNode.references = renderNode.references.filter { key, _ in !topicReferencesToRemove.contains(key) }
        return (renderNode, context)
    }
}
