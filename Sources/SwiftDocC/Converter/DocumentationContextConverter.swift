/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A converter from documentation nodes to render nodes.
///
/// As this type makes use of a `RenderContext` to look up commonly used pieces of content,
/// use this type when you are converting nodes in bulk.
///
/// If you are converting nodes ad-hoc use ``DocumentationNodeConverter`` instead.
public class DocumentationContextConverter {
    /// The context the converter uses to resolve references it finds in the documentation node's content.
    let context: DocumentationContext
    
    /// The bundle that contains the content from which the documentation node originated.
    let bundle: DocumentationBundle
    
    /// A context that contains common pre-rendered pieces of content.
    let renderContext: RenderContext
    
    /// Whether the documentation converter should include source file
    /// location metadata in any render nodes representing symbols it creates.
    ///
    /// Before setting this value to `true` please confirm that your use case doesn't include
    /// public distribution of any created render nodes as there are filesystem privacy and security
    /// concerns with distributing this data.
    let shouldEmitSymbolSourceFileURIs: Bool
    
    /// Whether the documentation converter should include access level information for symbols.
    let shouldEmitSymbolAccessLevels: Bool
    
    /// The remote source control repository where the documented module's source is hosted.
    let sourceRepository: SourceRepository?
    
    /// Creates a new node converter for the given bundle and context.
    ///
    /// The converter uses bundle and context to resolve references to other documentation and describe the documentation hierarchy.
    ///
    /// - Parameters:
    ///   - bundle: The bundle that contains the content from which the documentation node originated.
    ///   - context: The context that the converter uses to to resolve references it finds in the documentation node's content.
    ///   - renderContext: A context that contains common pre-rendered pieces of content.
    ///   - emitSymbolSourceFileURIs: Whether the documentation converter should include
    ///     source file location metadata in any render nodes representing symbols it creates.
    ///
    ///     Before passing `true` please confirm that your use case doesn't include public
    ///     distribution of any created render nodes as there are filesystem privacy and security
    ///     concerns with distributing this data.
    ///   - sourceRepository: The source repository where the documentation's sources are hosted.
    public init(
        bundle: DocumentationBundle,
        context: DocumentationContext,
        renderContext: RenderContext,
        emitSymbolSourceFileURIs: Bool = false,
        emitSymbolAccessLevels: Bool = false,
        sourceRepository: SourceRepository? = nil
    ) {
        self.bundle = bundle
        self.context = context
        self.renderContext = renderContext
        self.shouldEmitSymbolSourceFileURIs = emitSymbolSourceFileURIs
        self.shouldEmitSymbolAccessLevels = emitSymbolAccessLevels
        self.sourceRepository = sourceRepository
    }
    
    /// Converts a documentation node to a render node.
    ///
    /// Convert a documentation node into a render node to get a self-contained, persist-able representation of a given topic's data, so you can write it to disk, send it over a network, or otherwise process it.
    /// - Parameters:
    ///   - node: The documentation node to convert.
    ///   - source: The source file for the documentation node.
    /// - Returns: The render node representation of the documentation node.
    public func renderNode(for node: DocumentationNode, at source: URL?) throws -> RenderNode? {
        guard !node.isVirtual else {
            return nil
        }

        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: node.reference,
            source: source,
            renderContext: renderContext,
            emitSymbolSourceFileURIs: shouldEmitSymbolSourceFileURIs,
            emitSymbolAccessLevels: shouldEmitSymbolAccessLevels,
            sourceRepository: sourceRepository
        )
        return translator.visit(node.semantic) as? RenderNode
    }
}
