/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A rendering-friendly representation of a external node.
package struct ExternalRenderNode {
    /// Underlying external entity backing this external node.
    private var externalEntity: LinkResolver.ExternalEntity

    /// The bundle identifier for this external node.
    private var bundleIdentifier: DocumentationBundle.Identifier

    init(externalEntity: LinkResolver.ExternalEntity, bundleIdentifier: DocumentationBundle.Identifier) {
        self.externalEntity = externalEntity
        self.bundleIdentifier = bundleIdentifier
    }
    
    /// The identifier of the external render node.
    package var identifier: ResolvedTopicReference {
        ResolvedTopicReference(
            bundleID: bundleIdentifier,
            path: externalEntity.topicRenderReference.url,
            sourceLanguages: externalEntity.sourceLanguages
        )
    }

    /// The kind of this documentation node.
    var kind: RenderNode.Kind {
        externalEntity.topicRenderReference.kind
    }
    
    /// The symbol kind of this documentation node.
    var symbolKind: SymbolGraph.Symbol.KindIdentifier? {
        // Symbol kind information is not available for external entities
        return nil
    }
    
    /// The additional "role" assigned to the symbol, if any
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    var role: String? {
        externalEntity.topicRenderReference.role
    }
    
    /// The variants of the title.
    var titleVariants: VariantCollection<String> {
        externalEntity.topicRenderReference.titleVariants
    }
    
    /// The variants of the abbreviated declaration of the symbol to display in navigation.
    var navigatorTitleVariants: VariantCollection<[DeclarationRenderSection.Token]?> {
        externalEntity.topicRenderReference.navigatorTitleVariants
    }
    
    /// The variants of the abbreviated declaration of the symbol to display in links.
    var fragmentsVariants: VariantCollection<[DeclarationRenderSection.Token]?> {
        externalEntity.topicRenderReference.fragmentsVariants
    }
    
    /// Author provided images that represent this page.
    var images: [TopicImage] {
        externalEntity.topicRenderReference.images
    }

    /// The identifier of the external reference.
    var externalIdentifier: RenderReferenceIdentifier {
        externalEntity.topicRenderReference.identifier
    }

    /// List of variants of the same external node for various languages.
    var variants: [RenderNode.Variant]? {
        externalEntity.sourceLanguages.map {
            RenderNode.Variant(traits: [.interfaceLanguage($0.id)], paths: [externalEntity.topicRenderReference.url])
        }
    }
}