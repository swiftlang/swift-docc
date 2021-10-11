/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A transformation that applies two transformations, one after the other.
public struct RenderNodeTransformationComposition: RenderNodeTransforming {
    /// The first transformation to apply.
    public var first: RenderNodeTransforming
    /// The second transformation to apply.
    public var second: RenderNodeTransforming
    
    /// Initializes a transformation that applies two transformations, one after the other.
    ///
    /// - Parameters:
    ///   - first: The first transformation to apply.
    ///   - second: The second transformation to apply.
    public init(first: RenderNodeTransforming, second: RenderNodeTransforming) {
        self.first = first
        self.second = second
    }
    
    /// Applies the two transformations, in sequence, to a given render node.
    ///
    /// The composed transformation passes the output from the first transformation as the input to the second transformation.
    ///
    ///     ┌─────────────────────────────┐
    ///     │  ┌────────┐     ┌────────┐  │
    ///   ──┼─▶│        │────▶│        │──┼─▶
    ///     │  │ First  │     │ Second │  │
    ///   ──┼─▶│        │────▶│        │──┼─▶
    ///     │  └────────┘     └────────┘  │
    ///     └─────────────────────────────┘
    ///
    /// - Parameters:
    ///   - renderNode: The node to transform.
    ///   - context: The context in which the composed transformation transforms the node.
    /// - Returns: The transformed node, and a possibly modified context that's passed through both transformers.
    public func transform(renderNode: RenderNode, context: RenderNodeTransformationContext)
        -> RenderNodeTransformationResult {
        return [first, second].reduce((renderNode: renderNode, context: context)) { result, transformation in
            transformation.transform(renderNode: result.renderNode, context: result.context)
        }
    }
}
