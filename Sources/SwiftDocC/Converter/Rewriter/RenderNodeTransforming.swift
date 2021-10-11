/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A type that modifies a render node.
public protocol RenderNodeTransforming {
    /// A pair that consists of a render node and a transformation context.
    typealias RenderNodeTransformationResult = (renderNode: RenderNode, context: RenderNodeTransformationContext)

    /// Applies the transformation to the given render node.
    ///
    /// - Parameters:
    ///   - renderNode: The render node to transform.
    ///   - context: The context in which you apply this transformation.
    /// - Returns: The transformed render node and a (possible modified) context.
    func transform(renderNode: RenderNode, context: RenderNodeTransformationContext) -> RenderNodeTransformationResult
}

extension RenderNodeTransforming {
    /// Combines this transformation with another transformation.
    ///
    /// - Parameter otherTransformation: The other transformation to apply after the receiver.
    /// - Returns: A new transformation that applies the two transformations, one after another.
    public func then(_ otherTransformation: RenderNodeTransforming) -> RenderNodeTransformationComposition {
        return RenderNodeTransformationComposition(first: self, second: otherTransformation)
    }
}

/// A type that modifies a render node.
@available(*, deprecated, message: "Please use RenderNodeTransforming instead.")
public typealias RenderNodeTransformation = RenderNodeTransforming
