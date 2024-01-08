/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import Markdown

// Most tests use a simpler test resolver that always returns the same value. For some of them there could be value in using this test resolver
// instead to verify a mix of successes and failures in the same test.

class TestMultiResultExternalReferenceResolver: ExternalReferenceResolver, FallbackReferenceResolver, FallbackAssetResolver, _ExternalAssetResolver {
    var bundleIdentifier = "com.external.testbundle"
    
    // The minimal information that the test resolver needs to create a resolved reference and documentation node
    struct EntityInfo {
        var referencePath = "/externally/resolved/path"
        var fragment: String? = nil
        var title = "Externally Resolved Title"
        var abstract: Markup = Document(parsing: "Externally Resolved Markup Content", options: [.parseBlockDirectives, .parseSymbolLinks])
        var kind = DocumentationNode.Kind.article
        var language = SourceLanguage.swift
        var declarationFragments: SymbolGraph.Symbol.DeclarationFragments? = nil
        var topicImages: [(TopicImage, alt: String)]? = nil
    }
    
    // When more tests use this we may find that there's a better way to describe this (for example by separating
    // the data for resolving references and for creating documentation nodes)
    var entitiesToReturn: [String: Result<EntityInfo, Swift.Error>] = [:]
    
    var assetsToReturn: [String: DataAsset] = [:]
    
    enum Error: Swift.Error {
        case testErrorRaisedForWrongBundleIdentifier
    }
    
    var resolvedExternalPaths = [String]()
    
    // MARK: [Reference|Asset]Resolver conformances
    
    func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
        switch reference {
        case .resolved(let resolved):
            return resolved // Don't re-resolve the same reference
            
        case .unresolved(let unresolved):
            let path = unresolved.topicURL.url.path
            resolvedExternalPaths.append(path)
            
            let entity = entityInfo(path: path)
            return .success(
                ResolvedTopicReference(bundleIdentifier: bundleIdentifier,path: entity.referencePath,fragment: entity.fragment,sourceLanguage: entity.language)
            )
        }
    }
    
    func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
        guard reference.bundleIdentifier == bundleIdentifier else {
            throw Error.testErrorRaisedForWrongBundleIdentifier
        }
        return makeNode(for: entityInfo(path: reference.path), reference: reference)
    }
    
    let testBaseURL: String = "https://example.com/example"
    func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
        let entity = entityInfo(path: reference.path)
        
        let fragment = entity.fragment.map {"#\($0)"} ?? ""
        return URL(string: "\(testBaseURL)\(reference.path)\(fragment)")!
    }
    
    func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) throws -> DocumentationNode? {
        hasResolvedReference(reference) ? try entity(with: reference) : nil
    }
    
    func urlForResolvedReferenceIfPreviouslyResolved(_ reference: ResolvedTopicReference) -> URL? {
        hasResolvedReference(reference) ? urlForResolvedReference(reference) : nil
    }
    
    func hasResolvedReference(_ reference: ResolvedTopicReference) -> Bool {
        return resolvedExternalPaths.contains(reference.path)
    }
    
    func resolve(assetNamed assetName: String, bundleIdentifier: String) -> DataAsset? {
        return assetsToReturn[assetName]
    }
    
    func _resolveExternalAsset(named assetName: String, bundleIdentifier: String) -> DataAsset? {
        return assetsToReturn[assetName]
    }
    
    // MARK: Private helper functions
    
    private func result(path: String) -> Result<EntityInfo, Swift.Error> {
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
    
    private func makeNode(for entityInfo: EntityInfo, reference: ResolvedTopicReference) -> DocumentationNode {
        let semantic: Semantic?
        if let declaration = entityInfo.declarationFragments {
            semantic = Symbol(
                kindVariants: .init(swiftVariant: OutOfProcessReferenceResolver.symbolKind(forNodeKind: entityInfo.kind)),
                titleVariants: .init(swiftVariant: entityInfo.title),
                subHeadingVariants: .init(swiftVariant: declaration.declarationFragments),
                navigatorVariants: .init(swiftVariant: nil),
                roleHeadingVariants: .init(swiftVariant: ""), // This information isn't used anywhere.
                platformNameVariants: .init(swiftVariant: nil),
                moduleReference: reference, // This information isn't used anywhere.
                externalIDVariants: .init(swiftVariant: nil),
                accessLevelVariants: .init(swiftVariant: nil),
                availabilityVariants: .init(swiftVariant: nil),
                deprecatedSummaryVariants: .init(swiftVariant: nil),
                mixinsVariants: .init(swiftVariant: nil),
                abstractSectionVariants: .init(swiftVariant: nil),
                discussionVariants: .init(swiftVariant: nil),
                topicsVariants: .init(swiftVariant: nil),
                seeAlsoVariants: .init(swiftVariant: nil),
                returnsSectionVariants: .init(swiftVariant: nil),
                parametersSectionVariants: .init(swiftVariant: nil),
                dictionaryKeysSectionVariants: .init(swiftVariant: nil),
                httpEndpointSectionVariants: .init(swiftVariant: nil),
                httpBodySectionVariants: .init(swiftVariant: nil),
                httpParametersSectionVariants: .init(swiftVariant: nil),
                httpResponsesSectionVariants: .init(swiftVariant: nil),
                redirectsVariants: .init(swiftVariant: nil)
            )
        } else {
            semantic = nil
        }
        
        var node = DocumentationNode(
            reference: reference,
            kind: entityInfo.kind,
            sourceLanguage: entityInfo.language,
            name: .conceptual(title: entityInfo.title),
            markup: entityInfo.abstract,
            semantic: semantic
        )
        
        // This is a workaround for how external content is processed. See details in OutOfProcessReferenceResolver.addImagesAndCacheMediaReferences(to:from:)
        
        if let topicImages = entityInfo.topicImages {
            let metadata = node.metadata ?? Metadata._make(originalMarkup: BlockDirective(name: "Metadata", children: []))
            
            metadata.pageImages = topicImages.map { topicImage, alt in
                let purpose: PageImage.Purpose
                switch topicImage.type {
                case .card: purpose = .card
                case .icon: purpose = .icon
                }
                return PageImage._make(
                    purpose: purpose,
                    source: ResourceReference(bundleIdentifier: reference.bundleIdentifier, path: topicImage.identifier.identifier),
                    alt: alt
                )
            }
            
            node.metadata = metadata
        }
          
        return node
    }
}
