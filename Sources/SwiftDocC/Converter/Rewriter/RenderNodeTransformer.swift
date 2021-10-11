/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// An object that modifies a render node by applying transformations to it.
open class RenderNodeTransformer {
    /// The untransformed, decoded render node.
    open var renderNode: RenderNode

    /// The number of times each reference is referenced in the untransformed render node's content.
    var referencesCount: [String: Int] = [:]

    /// Creates a new transformer given the data of a render node.
    /// - Parameter renderNodeData: The render node, as data.
    /// - Throws: Throws an error if the given render node cannot be decoded.
    public init(renderNodeData: Data) throws {
        let decoder = JSONDecoder()
        decoder.userInfo[DecodingReferenceContext.codingUserInfoKey] = DecodingReferenceContext()
        let renderNode = try decoder.decode(RenderNode.self, from: renderNodeData)

        // Grab the references count from the decoding context, which each decoded section filled in while the decoder decoded the render node.
        let decodingContext = decoder.userInfo[DecodingReferenceContext.codingUserInfoKey] as? DecodingReferenceContext
        self.referencesCount = decodingContext?.referencesCount ?? [:]

        self.renderNode = renderNode
    }

    /// Applies the given transformation to the decoded render node and removes unreferenced references from it.
    ///
    /// - Parameter transformation: The transformation to apply.
    /// - Returns: The transformed render node.
    public func apply(transformation: RenderNodeTransforming) -> RenderNode {
        let context = RenderNodeTransformationContext(referencesCount: referencesCount)

        return transformation
            .then(RemoveUnusedReferencesTransformation())
            .transform(renderNode: renderNode, context: context).renderNode
    }
}

/// A context object for the decoder that keeps track of the number of times references are referenced.
class DecodingReferenceContext {
    fileprivate static let codingUserInfoKey = CodingUserInfoKey(rawValue: "referenceContext")!

    /// The number of times the decoded render node's content references each reference.
    var referencesCount: [String: Int] = [:]

    /// Registers the given references in the context, incrementing their reference counts.
    /// - Parameter references: The references to register.
    func registerReferences(_ references: [String]) {
        for reference in references {
            referencesCount[reference, default: 0] += 1
        }
    }
}

extension Decoder {
    /// Registers the given references into the decoder to track how many times references are being referenced in the decoded content.
    ///
    /// Transformers use this information to detect unused references. To ensure this information is available, the decoding implementations for render content that can contain
    /// references are required to call this method with the references that they decoded. If all your content is already ``RenderInlineContent``, this is already taken care
    /// of by that decoding implementation.
    ///
    /// - Parameter references: The topic references to register into the decoder.
    func registerReferences(_ references: [String]) {
        (userInfo[DecodingReferenceContext.codingUserInfoKey] as? DecodingReferenceContext)?
            .registerReferences(references)
    }
}
