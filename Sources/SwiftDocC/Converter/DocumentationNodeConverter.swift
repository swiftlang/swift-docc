/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A converter from documentation nodes to render nodes.
public struct DocumentationNodeConverter {
    /// The context the converter uses to resolve references it finds in the documentation node's content.
    let context: DocumentationContext
    
    /// The input files that contains the content from which the documentation node originated.
    let inputs: DocumentationContext.Inputs
    
    /// Creates a new node converter for the given bundle and context.
    ///
    /// The converter uses bundle and context to resolve references to other documentation and describe the documentation hierarchy.
    ///
    /// - Parameters:
    ///   - inputs: The input files that contains the content from which the documentation node originated.
    ///   - context: The context that the converter uses to to resolve references it finds in the documentation node's content.
    public init(inputs: DocumentationContext.Inputs, context: DocumentationContext) {
        self.inputs = inputs
        self.context = context
    }
    
    @available(*, deprecated, renamed: "init(inputs:context:)", message: "Use 'init(inputs:context:)' instead. This deprecated API will be removed after 6.3 is released")
    public init(bundle: DocumentationBundle, context: DocumentationContext) {
        self.init(inputs: bundle, context: context)
    }
    
    /// Converts a documentation node to a render node.
    ///
    /// Convert a documentation node into a render node to get a self-contained, persistable representation of a given topic's data, so you can write it to disk, send it over a network, or otherwise process it.
    /// - Parameters:
    ///   - node: The documentation node to convert.
    /// - Returns: The render node representation of the documentation node.
    public func convert(_ node: DocumentationNode) -> RenderNode {
        var translator = RenderNodeTranslator(context: context, inputs: inputs, identifier: node.reference)
        return translator.visit(node.semantic) as! RenderNode
    }
}
