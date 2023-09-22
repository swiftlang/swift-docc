/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

final class ExternalPathHierarchyResolver {
    
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy!
    
    /// Map between resolved identifiers and resolved topic references.
    private(set) var resolvedReferenceMap = [ResolvedIdentifier: ResolvedTopicReference]()
    
    private(set) var symbols: [String: ResolvedTopicReference]
    private(set) var entitySummaries: [ResolvedTopicReference: LinkDestinationSummary]
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    /// - Returns: The result of resolving the reference.
    func resolve(_ unresolvedReference: UnresolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool) -> TopicReferenceResolutionResult {
        do {
            let foundID = try pathHierarchy.find(path: Self.path(for: unresolvedReference), parent: nil, onlyFindSymbols: true)
            guard let foundReference = resolvedReferenceMap[foundID] else {
                fatalError("Every identifier in the path hierarchy has a corresponding reference in the wrapping resolver. If it doesn't that's an indication that the file content that it was deserialized from was malformed.")
            }
            
            // TODO: Check that content exist for reference
            
            return .success(foundReference)
        } catch let error as PathHierarchy.Error {
            var originalReferenceString = unresolvedReference.path
            if let fragment = unresolvedReference.topicURL.components.fragment {
                originalReferenceString += "#" + fragment
            }
            
            return .failure(unresolvedReference, error.asTopicReferenceResolutionErrorInfo(originalReference: originalReferenceString) { node in 
                // TODO: Read the display name from the entity summary data
                node.name
            })
        } catch {
            fatalError("Only PathHierarchy.Error errors are raised from the symbol link resolution code above.")
        }
    }
    
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }

    func entity(symbolID usr: String) -> ExternalEntity? {
        guard let reference = symbols[usr] else { return nil }
        return entity(reference)
    }
    
    func entity(_ reference: ResolvedTopicReference) -> ExternalEntity {
        guard let resolvedInformation = entitySummaries[reference] else {
            fatalError("The resolver should only be asked for entities that it resolved.")
        }
       
        let (kind, role) = DocumentationContentRenderer.renderKindAndRole(resolvedInformation.kind, semantic: nil)
        
        // TODO: Language variants
        let renderReference = TopicRenderReference(
            identifier: .init(reference.absoluteString),
            title: resolvedInformation.title,
            abstract: resolvedInformation.abstract ?? [],
            url: reference.absoluteString,
            kind: kind,
            required: false,
            role: resolvedInformation.kind.isSymbol ? role : nil,
            fragments: resolvedInformation.declarationFragments,
            navigatorTitle: nil,
            estimatedTime: nil,
            conformance: nil,
            isBeta: resolvedInformation.platforms?.contains(where: { $0.isBeta == true }) ?? false,
            isDeprecated: resolvedInformation.platforms?.contains(where: { $0.unconditionallyDeprecated == true }) ?? false,
            defaultImplementationCount: nil,
            titleStyle: resolvedInformation.kind.isSymbol ? .symbol : .title,
            name: resolvedInformation.title,
            ideTitle: nil,
            tags: nil,
            images: resolvedInformation.topicImages ?? []
        )
        let dependencies = RenderReferenceDependencies(
            topicReferences: [], // TODO: extract topic references
            linkReferences: (resolvedInformation.references ?? []).compactMap { $0 as? LinkReference },
            imageReferences: (resolvedInformation.references ?? []).compactMap { $0 as? ImageReference }
        )
        
        return .init(
            reference: reference,
            topicRenderReference: renderReference,
            renderReferenceDependencies: dependencies
        )
    }
    
    // MARK: Deserialization
    
    init(
        linkInformation fileRepresentation: SerializableLinkResolutionInformation,
        entityInformation linkDestinationSummaries: [LinkDestinationSummary]
    ) {
        var entities = [ResolvedTopicReference: LinkDestinationSummary]()
        var symbols = [String: ResolvedTopicReference]()
        entities.reserveCapacity(linkDestinationSummaries.count)
        symbols.reserveCapacity(linkDestinationSummaries.count)
        for entity in linkDestinationSummaries {
            let reference = ResolvedTopicReference(
                bundleIdentifier: entity.referenceURL.host!,
                path: entity.referenceURL.path,
                fragment: entity.referenceURL.fragment,
                sourceLanguage: entity.language
            )
            entities[reference] = entity
            if let usr = entity.usr {
                symbols[usr] = reference
            }
        }
        self.entitySummaries = entities
        self.symbols = symbols
        
        self.pathHierarchy = PathHierarchy(fileRepresentation.pathHierarchy) { identifiers in
            // Read the serialized paths
            self.resolvedReferenceMap.reserveCapacity(identifiers.count)
            for (index, nodeData) in fileRepresentation.nodeData {
                let identifier = identifiers[index]
                let url = URL(string: nodeData.path!)! // The file currently always encodes a file
                self.resolvedReferenceMap[identifier] = ResolvedTopicReference(bundleIdentifier: fileRepresentation.bundleID, path: url.path, fragment: url.fragment, sourceLanguage: .swift)
            }
        }
    }
    
    convenience init(dependencyArchive: URL) throws {
        // ???: Should it be the callers responsibility to pass both these URLs?
        let linkHierarchyFile = dependencyArchive.appendingPathComponent("link-hierarchy.json")
        let entityURL = dependencyArchive.appendingPathComponent("linkable-entities.json")
        
        self.init(
            linkInformation: try JSONDecoder().decode(SerializableLinkResolutionInformation.self, from: Data(contentsOf: linkHierarchyFile)),
            entityInformation: try JSONDecoder().decode([LinkDestinationSummary].self, from: Data(contentsOf: entityURL))
        )
    }
}

// MARK: ExternalEntity

extension ExternalPathHierarchyResolver {
    struct ExternalEntity {
        var reference: ResolvedTopicReference
        var topicRenderReference: TopicRenderReference
        var renderReferenceDependencies: RenderReferenceDependencies
        var sourceLanguages: Set<SourceLanguage> = []
        
        func topicContent() -> RenderReferenceStore.TopicContent {
            return .init(
                renderReference: topicRenderReference,
                canonicalPath: nil,
                taskGroups: nil,
                source: nil,
                isDocumentationExtensionContent: false,
                renderReferenceDependencies: renderReferenceDependencies
            )
        }
    }
}
