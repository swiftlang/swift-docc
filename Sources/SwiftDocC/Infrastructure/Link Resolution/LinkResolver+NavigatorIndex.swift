/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Common

/// A rendering-friendly representation of a external node.
package struct ExternalRenderNode {
    private var entity: LinkResolver.ExternalEntity
    private var topicRenderReference:  TopicRenderReference
    
    /// The bundle identifier for this external node.
    private var bundleIdentifier: DocumentationBundle.Identifier

    // This type is designed to misrepresent external content as local content to fit in with the navigator.
    // This spreads the issue to more code rather than fixing it, which adds technical debt and can be fragile.
    //
    // At the time of writing this comment, this type and the issues it comes with has spread to 6 files (+ 3 test files).
    // Luckily, none of that code is public API so we can modify or even remove it without compatibility restrictions.
    init(externalEntity: LinkResolver.ExternalEntity, bundleIdentifier: DocumentationBundle.Identifier) {
        self.entity = externalEntity
        self.bundleIdentifier = bundleIdentifier
        self.topicRenderReference = externalEntity.makeTopicRenderReference()
    }
    
    /// The identifier of the external render node.
    package var identifier: ResolvedTopicReference {
        ResolvedTopicReference(
            bundleID: bundleIdentifier,
            path: entity.referenceURL.path,
            fragment: entity.referenceURL.fragment,
            sourceLanguages: entity.availableLanguages
        )
    }

    /// The kind of this documentation node.
    var kind: RenderNode.Kind {
        topicRenderReference.kind
    }
    
    /// The symbol kind of this documentation node.
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    var symbolKind: SymbolGraph.Symbol.KindIdentifier? {
        DocumentationNode.symbolKind(for: entity.kind)
    }
    
    /// The additional "role" assigned to the symbol, if any
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    var role: String? {
        topicRenderReference.role
    }
    
    /// The variants of the title.
    var titleVariants: VariantCollection<String> {
        topicRenderReference.titleVariants
    }
    
    /// The variants of the abbreviated declaration of the symbol to display in navigation.
    var navigatorTitleVariants: VariantCollection<[DeclarationRenderSection.Token]?> {
        topicRenderReference.navigatorTitleVariants
    }
    
    /// The variants of the abbreviated declaration of the symbol to display in links and fall-back to in navigation.
    ///
    /// This value is `nil` if the referenced page is not a symbol.
    var fragmentsVariants: VariantCollection<[DeclarationRenderSection.Token]?> {
        topicRenderReference.fragmentsVariants
    }
    
    /// Author provided images that represent this page.
    var images: [TopicImage] {
        entity.topicImages ?? []
    }

    /// The identifier of the external reference.
    var externalIdentifier: RenderReferenceIdentifier {
        topicRenderReference.identifier
    }

    /// List of variants of the same external node for various languages.
    var variants: [RenderNode.Variant]? {
        entity.availableLanguages.map {
            RenderNode.Variant(traits: [.interfaceLanguage($0.id)], paths: [topicRenderReference.url])
        }
    }
    
    /// A value that indicates whether this symbol is built for a beta platform
    ///
    /// This value is `false` if the referenced page is not a symbol.
    var isBeta: Bool {
        topicRenderReference.isBeta
    }
}

/// A language specific representation of an external render node value for building a navigator index.
struct NavigatorExternalRenderNode: NavigatorIndexableRenderNodeRepresentation {
    private var _identifier: ResolvedTopicReference
    var identifier: ResolvedTopicReference {
        _identifier
    }
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

        self._identifier = renderNode.identifier.withSourceLanguages([traitLanguage])
        self.kind = renderNode.kind
        
        self.metadata = ExternalRenderNodeMetadataRepresentation(
            title: renderNode.titleVariants.value(for: traits),
            navigatorTitle: renderNode.navigatorTitleVariants.value(for: traits),
            externalID: renderNode.externalIdentifier.identifier,
            role: renderNode.role,
            symbolKind: renderNode.symbolKind?.renderingIdentifier,
            images: renderNode.images,
            isBeta: renderNode.isBeta,
            fragments: renderNode.fragmentsVariants.value(for: traits)
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
    var fragments: [DeclarationRenderSection.Token]?

    // Values that we have insufficient information to derive.
    // These are needed to conform to the navigator indexable metadata protocol.
    //
    // The role heading is used to identify Property Lists.
    // The value being missing is used for computing the final navigator title.
    //
    // The platforms are used for generating the availability index,
    // but doesn't affect how the node is rendered in the sidebar.
    var roleHeading: String? = nil
    var platforms: [AvailabilityRenderItem]? = nil
}
