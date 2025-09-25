/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@_spi(ExternalLinks) @testable import SwiftDocC
import SymbolKit
import Markdown

// Most tests use a simpler test resolver that always returns the same value. For some of them there could be value in using this test resolver
// instead to verify a mix of successes and failures in the same test.

class TestMultiResultExternalReferenceResolver: ExternalDocumentationSource {
    var bundleID: DocumentationBundle.Identifier = "com.external.testbundle"
    
    // The minimal information that the test resolver needs to create a resolved reference and documentation node
    struct EntityInfo {
        var referencePath = "/externally/resolved/path"
        var fragment: String? = nil
        var title = "Externally Resolved Title"
        var abstract: any Markup = Document(parsing: "Externally Resolved Markup Content", options: [.parseBlockDirectives, .parseSymbolLinks])
        var kind = DocumentationNode.Kind.article
        var language = SourceLanguage.swift
        var declarationFragments: SymbolGraph.Symbol.DeclarationFragments? = nil
        var navigatorTitle: SymbolGraph.Symbol.DeclarationFragments? = nil
        var topicImages: [(TopicImage, alt: String)]? = nil
        var platforms: [AvailabilityRenderItem]? = nil
    }
    
    // When more tests use this we may find that there's a better way to describe this (for example by separating
    // the data for resolving references and for creating documentation nodes)
    var entitiesToReturn: [String: Result<EntityInfo, any Swift.Error>] = [:]
    
    var assetsToReturn: [String: DataAsset] = [:]
    
    var resolvedExternalPaths = [String]()
    
    // MARK: [Reference|Asset]Resolver conformances
    
    func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
        switch reference {
        case .resolved(let resolved):
            return resolved // Don't re-resolve the same reference
            
        case .unresolved(let unresolved):
            let path = unresolved.topicURL.url.path
            resolvedExternalPaths.append(path)
            
            let entity = entityInfo(path: path)
            return .success(
                ResolvedTopicReference(bundleID: bundleID, path: entity.referencePath, fragment: entity.fragment, sourceLanguage: entity.language)
            )
        }
    }
    
    func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
        guard reference.bundleID == bundleID else {
            fatalError("It is a programming mistake to retrieve an entity for a reference that the external resolver didn't resolve.")
        }
        return makeNode(for: entityInfo(path: reference.path), reference: reference)
    }
    
    // MARK: Private helper functions
    
    private func result(path: String) -> Result<EntityInfo, any Swift.Error> {
        guard let value = entitiesToReturn[path] else {
            fatalError("Missing test data to return for \(path). This is an error with the test.")
        }
        return value
    }
    
    private func entityInfo(path: String) -> EntityInfo {
        switch result(path: path) {
        case .success(let entity):
            return entity
        case .failure(_):
            fatalError("This test resolver should never ask for the entity for a reference that failed to resolve.")
        }
    }
    
    private func makeNode(for entityInfo: EntityInfo, reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
        LinkResolver.ExternalEntity(
            kind: entityInfo.kind,
            language: entityInfo.language,
            relativePresentationURL: reference.url.withoutHostAndPortAndScheme(),
            referenceURL: reference.url,
            title: entityInfo.title,
            availableLanguages: [entityInfo.language],
            platforms: entityInfo.platforms,
            subheadingDeclarationFragments: entityInfo.declarationFragments?.declarationFragments.map { .init(fragment: $0, identifier: nil) },
            navigatorTitle: entityInfo.navigatorTitle?.declarationFragments.map { .init(fragment: $0, identifier: nil) },
            topicImages: entityInfo.topicImages?.map(\.0),
            references: entityInfo.topicImages?.map { topicImage, altText in
                ImageReference(identifier: topicImage.identifier, altText: altText, imageAsset: assetsToReturn[topicImage.identifier.identifier] ?? .init())
            },
            variants: []
        )
    }
}
