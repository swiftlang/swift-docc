/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A converter from documentation nodes to render nodes.
public struct DocumentationNodeConverter {
    /// The context the converter uses to resolve references it finds in the documentation node's content.
    let context: DocumentationContext
    
    /// The catalog that contains the content from which the documentation node originated.
    let catalog: DocumentationCatalog
    
    /// Creates a new node converter for the given catalog and context.
    ///
    /// The converter uses catalog and context to resolve references to other documentation and describe the documentation hierarchy.
    ///
    /// - Parameters:
    ///   - catalog: The catalog that contains the content from which the documentation node originated.
    ///   - context: The context that the converter uses to to resolve references it finds in the documentation node's content.
    public init(catalog: DocumentationCatalog, context: DocumentationContext) {
        self.catalog = catalog
        self.context = context
    }
    
    @available(*, deprecated, renamed: "init(catalog:context:)")
    public init(bundle: DocumentationCatalog, context: DocumentationContext) {
        self = .init(catalog: bundle, context: context)
    }
    
    /// Converts a documentation node to a render node.
    ///
    /// - Parameters:
    ///   - node: The documentation node to convert.
    ///   - source: The source file from which the documentation node's content originated.
    ///   - catalog: The catalog that contains the content from which the documentation node originated.
    /// - Returns: The render node representation of the documentation node.
    @available(*, deprecated, message: "Please use convert(_:at:) instead.")
    public func convert(_ node: DocumentationNode, at source: URL?, from bundle: DocumentationCatalog) throws -> RenderNode {
        var translator = RenderNodeTranslator(context: context, catalog: bundle, identifier: node.reference, source: source)
        return translator.visit(node.semantic) as! RenderNode
    }
    
    /// Converts a documentation node to a render node.
    ///
    /// Convert a documentation node into a render node to get a self-contained, persistable representation of a given topic's data, so you can write it to disk, send it over a network, or otherwise process it.
    /// - Parameters:
    ///   - node: The documentation node to convert.
    ///   - source: The source file for the documentation node.
    /// - Returns: The render node representation of the documentation node.
    public func convert(_ node: DocumentationNode, at source: URL?) throws -> RenderNode {
        var translator = RenderNodeTranslator(context: context, catalog: catalog, identifier: node.reference, source: source)
        return translator.visit(node.semantic) as! RenderNode
    }
}

/// A converter that coverts documentation nodes to render nodes.
@available(*, deprecated, message: "Please use DocumentationNodeConverter instead.")
public typealias Converter = DocumentationNodeConverter
