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
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    var symbolKind: SymbolGraph.Symbol.KindIdentifier? {
        externalEntity.symbolKind
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
    
    /// A value that indicates whether this symbol is built for a beta platform
    ///
    /// This value is `false` if the referenced page is not a symbol.
    var isBeta: Bool {
        externalEntity.topicRenderReference.isBeta
    }
}

/// A language specific representation of an external render node value for building a navigator index.
struct NavigatorExternalRenderNode: NavigatorIndexableRenderNodeRepresentation {
    var identifier: ResolvedTopicReference
    var kind: RenderNode.Kind
    var metadata: ExternalRenderNodeMetadataRepresentation
    
    // Values that don't affect how the node is rendered in the sidebar.
    // These are needed to conform to the navigator indexable protocol.
    var references: [String : any RenderReference] = [:]
    var sections: [any RenderSection] = []
    var topicSections: [TaskGroupRenderSection] = []
    var defaultImplementationsSections: [TaskGroupRenderSection] = []
    
    init(renderNode: ExternalRenderNode, trait: RenderNode.Variant.Trait? = nil) {
        // Compute the source language of the node based on the trait to know which variant to apply.
        let traitLanguage = if case .interfaceLanguage(let id) = trait {
            SourceLanguage(id: id)
        } else {
            renderNode.identifier.sourceLanguage
        }
        let traits = trait.map { [$0] } ?? []

        self.identifier = renderNode.identifier.withSourceLanguages(Set(arrayLiteral: traitLanguage))
        self.kind = renderNode.kind
        
        self.metadata = ExternalRenderNodeMetadataRepresentation(
            title: renderNode.titleVariants.value(for: traits),
            navigatorTitle: renderNode.navigatorTitleVariants.value(for: traits),
            externalID: renderNode.externalIdentifier.identifier,
            role: renderNode.role,
            symbolKind: renderNode.symbolKind?.renderingIdentifier,
            images: renderNode.images,
            isBeta: renderNode.isBeta
        )
    }
}

/// A language specific representation of a render metadata value for building an external navigator index.
struct ExternalRenderNodeMetadataRepresentation: NavigatorIndexableRenderMetadataRepresentation {
    var title: String?
    var navigatorTitle: [DeclarationRenderSection.Token]?
    var externalID: String?
    var role: String?
    var symbolKind: String?
    var images: [TopicImage]
    var isBeta: Bool

    // Values that we have insufficient information to derive.
    // These are needed to conform to the navigator indexable metadata protocol.
    //
    // The fragments that we get as part of the external link are the full declaration fragments.
    // These are too verbose for the navigator, so instead of using them, we rely on the title, navigator title and symbol kind instead.
    //
    // The role heading is used to identify Property Lists.
    // The value being missing is used for computing the final navigator title.
    //
    // The platforms are used for generating the availability index,
    // but doesn't affect how the node is rendered in the sidebar.
    var fragments: [DeclarationRenderSection.Token]? = nil
    var roleHeading: String? = nil
    var platforms: [AvailabilityRenderItem]? = nil
}
