/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A language specific representation of a render node value for building a navigator index.
protocol NavigatorIndexableRenderNodeRepresentation<Metadata> {
    associatedtype Metadata: NavigatorIndexableRenderMetadataRepresentation
    
    // Information that's the same for all language variants
    var identifier: ResolvedTopicReference { get }
    var references: [String: any RenderReference] { get }
    var kind: RenderNode.Kind { get }
    var sections: [any RenderSection] { get }
    
    // Information that's different for each language variant
    var metadata: Metadata { get }
    var topicSections: [TaskGroupRenderSection] { get }
    var defaultImplementationsSections: [TaskGroupRenderSection] { get }
}

/// A language specific representation of a render metadata value for building a navigator index.
protocol NavigatorIndexableRenderMetadataRepresentation {
    // Information that's the same for all language variants
    var role: String? { get }
    var images: [TopicImage] { get }
    
    // Information that's different for each language variant
    var title: String? { get }
    var navigatorTitle: [DeclarationRenderSection.Token]? { get }
    var fragments: [DeclarationRenderSection.Token]? { get }
    var externalID: String? { get }
    var roleHeading: String? { get }
    var symbolKind: String? { get }
    var platforms: [AvailabilityRenderItem]? { get }
}

extension NavigatorIndexableRenderNodeRepresentation {
    var icon: RenderReferenceIdentifier? {
        metadata.images.first { $0.type == .icon }?.identifier
    }
}

extension RenderNode: NavigatorIndexableRenderNodeRepresentation {}
extension RenderMetadata: NavigatorIndexableRenderMetadataRepresentation {}

struct RenderMetadataVariantView: NavigatorIndexableRenderMetadataRepresentation {
    var wrapped: RenderMetadata
    var traits: [RenderNode.Variant.Trait]
    
    // The same for all language variants
    var role: String? {
        wrapped.role
    }
    var images: [TopicImage] {
        wrapped.images
    }
    
    // Different for each language variant
    var title: String? {
        wrapped.titleVariants.value(for: traits)
    }
    var navigatorTitle: [DeclarationRenderSection.Token]? {
        wrapped.navigatorTitleVariants.value(for: traits)
    }
    var fragments: [DeclarationRenderSection.Token]? {
        wrapped.fragmentsVariants.value(for: traits)
    }
    var externalID: String? {
        wrapped.externalIDVariants.value(for: traits)
    }
    var roleHeading: String? {
        wrapped.roleHeadingVariants.value(for: traits)
    }
    var symbolKind: String? {
        wrapped.symbolKindVariants.value(for: traits)
    }
    var platforms: [AvailabilityRenderItem]? {
        wrapped.platformsVariants.value(for: traits)
    }
}

struct RenderNodeVariantView: NavigatorIndexableRenderNodeRepresentation {
    var wrapped: RenderNode
    var traits: [RenderNode.Variant.Trait]
    
    init(wrapped: RenderNode, traits: [RenderNode.Variant.Trait]) {
        self.wrapped = wrapped
        self.traits = traits
        let traitLanguages = traits.map {
            switch $0 {
            case .interfaceLanguage(let id):
                return SourceLanguage(id: id)
            }
        }
        self.identifier = wrapped.identifier.withSourceLanguages(Set(traitLanguages))
        self.metadata = RenderMetadataVariantView(wrapped: wrapped.metadata, traits: traits)
    }
    
    // Computed during initialization
    var identifier: ResolvedTopicReference
    var metadata: RenderMetadataVariantView
    
    // The same for all language variants
    var references: [String: any RenderReference] { wrapped.references }
    var kind: RenderNode.Kind { wrapped.kind }
    var sections: [any RenderSection] { wrapped.sections }
    
    // Different for each language variant
    var topicSections: [TaskGroupRenderSection] {
        wrapped.topicSectionsVariants.value(for: traits)
    }
    var defaultImplementationsSections: [TaskGroupRenderSection] {
        wrapped.defaultImplementationsSectionsVariants.value(for: traits)
    }
}

private let typesThatShouldNotUseNavigatorTitle: Set<NavigatorIndex.PageType> = [
    .framework, .class, .structure, .enumeration, .protocol, .typeAlias, .associatedType, .extension
]

extension NavigatorIndexableRenderNodeRepresentation {
    /// Returns a navigator title preferring the fragments inside the metadata, if applicable.
    func navigatorTitle() -> String? {
        let tokens: [DeclarationRenderSection.Token]?
        
        // FIXME: Use `metadata.navigatorTitle` for all Swift symbols (github.com/swiftlang/swift-docc/issues/176).
        if identifier.sourceLanguage == .swift || (metadata.navigatorTitle ?? []).isEmpty {
            let pageType = navigatorPageType()
            guard !typesThatShouldNotUseNavigatorTitle.contains(pageType) else {
                return metadata.title
            }
            tokens = metadata.fragments
        } else {
            tokens = metadata.navigatorTitle
        }
        
        return tokens?.map(\.text).joined() ?? metadata.title
    }
    
    /// Returns the type of page for the render node.
    func navigatorPageType() -> NavigatorIndex.PageType {
        // This is a workaround to support plist keys.
        switch metadata.roleHeading?.lowercased() {
            case "property list key":           return .propertyListKey
            case "property list key reference": return .propertyListKeyReference
            default: break
        }
        
        switch kind {
            case .article:  return metadata.role.map { .init(role: $0) }
                                ?? .article
            case .tutorial: return .tutorial
            case .section:  return .section
            case .overview: return .overview
            case .symbol:   return metadata.symbolKind.map { .init(symbolKind: $0) }
                                ?? metadata.role.map { .init(role: $0) }
                                ?? .symbol
        }
    }
}

extension NavigatorIndexableRenderNodeRepresentation {
    func navigatorChildren(for traits: [RenderNode.Variant.Trait]?) -> [RenderRelationshipsGroup] {
        switch kind {
        case .overview:
            var groups = [RenderRelationshipsGroup]()
            for case let section as VolumeRenderSection in sections {
                groups.append(contentsOf: section.chapters.map { chapter in
                    RenderRelationshipsGroup(
                        name: chapter.name,
                        abstract: nil,
                        references: chapter.tutorials.compactMap { self.references[$0.identifier] as? TopicRenderReference }
                    )
                })
            }
            return groups
        default:
            // Gather all topic references, transformed based on the traits, organizer by their identifier
            let references: [String: TopicRenderReference] = references.values.reduce(into: [:]) { acc, renderReference in
                guard var renderReference = renderReference as? TopicRenderReference else { return }
                // Transform the topic reference to hold the variant title
                if let traits {
                    renderReference.title = renderReference.titleVariants.applied(to: renderReference.title, for: traits)
                }
                acc[renderReference.identifier.identifier] = renderReference
            }
            
            func makeGroup(topicSection: TaskGroupRenderSection, isNestingReferences: Bool) -> RenderRelationshipsGroup {
                RenderRelationshipsGroup(
                    name: topicSection.title,
                    abstract: nil, // The navigator index only needs the title and the references.
                    references: topicSection.identifiers.map { references[$0]! },
                    referencesAreNested: isNestingReferences
                )
            }
            
            return topicSections.map {
                makeGroup(topicSection: $0, isNestingReferences: false)
            } + defaultImplementationsSections.map {
                makeGroup(topicSection: $0, isNestingReferences: true)
            }
        }
    }
}
