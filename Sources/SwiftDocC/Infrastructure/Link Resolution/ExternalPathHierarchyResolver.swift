/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// A class that resolves links to an already built documentation archives.
final class ExternalPathHierarchyResolver {
    /// A hierarchy of path components used to resolve links in the documentation.
    private(set) var pathHierarchy: PathHierarchy!
    
    /// A map from the path hierarchies identifiers to resolved references.
    private var resolvedReferences = [ResolvedIdentifier: ResolvedTopicReference]()
    /// A map from symbol's unique identifiers to their resolved references.
    private var symbols: [String: ResolvedTopicReference]
    
    /// The content for each external entity.
    private var content: [ResolvedTopicReference: LinkDestinationSummary]
    
    /// Attempts to resolve an unresolved reference.
    ///
    /// - Parameters:
    ///   - unresolvedReference: The unresolved reference to resolve.
    ///   - isCurrentlyResolvingSymbolLink: Whether or not the documentation link is a symbol link.
    /// - Returns: The result of resolving the reference.
    func resolve(_ unresolvedReference: UnresolvedTopicReference, fromSymbolLink isCurrentlyResolvingSymbolLink: Bool) -> TopicReferenceResolutionResult {
        let originalReferenceString = Self.path(for: unresolvedReference)
        do {
            let foundID = try pathHierarchy.find(path: originalReferenceString, parent: nil, onlyFindSymbols: isCurrentlyResolvingSymbolLink)
            guard let foundReference = resolvedReferences[foundID] else {
                fatalError("Every identifier in the path hierarchy has a corresponding reference in the wrapping resolver. If it doesn't that's an indication that the file content that it was deserialized from was malformed.")
            }
            
            guard content[foundReference] != nil else {
                return .failure(unresolvedReference, .init("Resolved \(foundReference.url.withoutHostAndPortAndScheme().absoluteString.singleQuoted) but don't have any content to display for it."))
            }
            
            return .success(foundReference)
        } catch let error as PathHierarchy.Error {
            return .failure(unresolvedReference, error.makeTopicReferenceResolutionErrorInfo() { collidingNode in
                self.fullName(of: collidingNode) // If the link was ambiguous, determine the full name of each colliding node to be presented in the link diagnostic.
            })
        } catch {
            fatalError("Only PathHierarchy.Error errors are raised from the symbol link resolution code above.")
        }
    }
    
    private func fullName(of collidingNode: PathHierarchy.Node) -> String {
        guard let reference = resolvedReferences[collidingNode.identifier], let summary = content[reference] else {
            return collidingNode.name
        }
        if let symbolID = collidingNode.symbol?.identifier {
            if symbolID.interfaceLanguage == summary.language.id, let fragments = summary.declarationFragments {
                return fragments.plainTextDeclaration()
            }
            if let variant = summary.variants.first(where: { $0.traits.contains(.interfaceLanguage(symbolID.interfaceLanguage)) }),
               let fragments = variant.declarationFragments ?? summary.declarationFragments
            {
                return fragments.plainTextDeclaration()
            }
        }
        return summary.title
    }
    
    private static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }

    /// Returns the external entity for a symbol's unique identifier or `nil` if that symbol isn't known in this external context.
    func symbolReferenceAndEntity(symbolID usr: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
        guard let reference = symbols[usr] else { return nil }
        return (reference, entity(reference))
    }
    
    /// Returns the external entity for a reference that was successfully resolved by this external resolver.
    ///
    /// - Precondition: The `reference` was previously resolved by this resolver.
    func entity(_ reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
        guard let resolvedInformation = content[reference] else {
            fatalError("The resolver should only be asked for entities that it resolved.")
        }
        
        let topicReferences: [ResolvedTopicReference] = (resolvedInformation.references ?? []).compactMap {
            guard let renderReference = $0 as? TopicRenderReference,
                  let url = URL(string: renderReference.identifier.identifier),
                  let bundleID = url.host
            else {
                return nil
            }
            return ResolvedTopicReference(bundleID: .init(rawValue: bundleID), path: url.path, fragment: url.fragment, sourceLanguage: .swift)
        }
        let dependencies = RenderReferenceDependencies(
            topicReferences: topicReferences,
            linkReferences: (resolvedInformation.references ?? []).compactMap { $0 as? LinkReference },
            imageReferences: (resolvedInformation.references ?? []).compactMap { $0 as? ImageReference }
        )
        
        return .init(
            topicRenderReference: resolvedInformation.topicRenderReference(),
            renderReferenceDependencies: dependencies,
            sourceLanguages: resolvedInformation.availableLanguages,
            symbolKind: DocumentationNode.symbolKind(for: resolvedInformation.kind)
        )
    }
    
    // MARK: Deserialization
    
    init(
        linkInformation fileRepresentation: SerializableLinkResolutionInformation,
        entityInformation linkDestinationSummaries: [LinkDestinationSummary]
    ) {
        // First, read the linkable entities and build up maps of USR -> Reference and Reference -> Content.
        var entities = [ResolvedTopicReference: LinkDestinationSummary]()
        var symbols = [String: ResolvedTopicReference]()
        entities.reserveCapacity(linkDestinationSummaries.count)
        symbols.reserveCapacity(linkDestinationSummaries.count)
        for entity in linkDestinationSummaries {
            let reference = ResolvedTopicReference(
                bundleID: .init(rawValue: entity.referenceURL.host!),
                path: entity.referenceURL.path,
                fragment: entity.referenceURL.fragment,
                sourceLanguage: entity.language
            )
            entities[reference] = entity
            if let usr = entity.usr {
                symbols[usr] = reference
            }
        }
        self.content = entities
        self.symbols = symbols
        
        // Second, decode the path hierarchy
        self.pathHierarchy = PathHierarchy(fileRepresentation.pathHierarchy) { identifiers in
            // Third, iterate over the newly created path hierarchy's identifiers and build up the map from Identifier -> Reference.
            self.resolvedReferences.reserveCapacity(identifiers.count)
            for (index, path) in fileRepresentation.nonSymbolPaths {
                guard let url = URL(string: path) else { 
                    assertionFailure("Failed to create URL from \"\(path)\". This is an indication of an encoding issue.")
                    // In release builds, skip pages that failed to decode. It's possible that they're never linked to and that they won't cause any issue in the build.
                    continue
                }
                let identifier = identifiers[index]
                self.resolvedReferences[identifier] = ResolvedTopicReference(bundleID: fileRepresentation.bundleID, path: url.path, fragment: url.fragment, sourceLanguage: .swift)
            }
        }
        // Finally, the Identifier -> Symbol mapping can be constructed by iterating over the nodes and looking up the reference for each USR.
        for (identifier, node) in self.pathHierarchy.lookup {
            // The hierarchy contains both symbols and non-symbols so skip anything that isn't a symbol.
            guard let usr = node.symbol?.identifier.precise else { continue }
            self.resolvedReferences[identifier] = symbols[usr]
        }
    }
    
    convenience init(dependencyArchive: URL, dataProvider: any DataProvider) throws {
        // ???: Should it be the callers responsibility to pass both these URLs?
        let linkHierarchyFile = dependencyArchive.appendingPathComponent("link-hierarchy.json")
        let entityURL = dependencyArchive.appendingPathComponent("linkable-entities.json")
        
        self.init(
            linkInformation: try JSONDecoder().decode(SerializableLinkResolutionInformation.self, from: dataProvider.contents(of: linkHierarchyFile)),
            entityInformation: try JSONDecoder().decode([LinkDestinationSummary].self, from: dataProvider.contents(of: entityURL))
        )
    }
}

private extension Sequence<DeclarationRenderSection.Token> {
    func plainTextDeclaration() -> String {
        return self.map(\.text).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
    }
}

// MARK: ExternalEntity

extension LinkDestinationSummary {
    /// A value that indicates whether this symbol is under development and likely to change.
    private var isBeta: Bool {
        guard let platforms, !platforms.isEmpty else {
            return false
        }
        
        return platforms.allSatisfy { $0.isBeta == true }
    }
    
    /// Create a topic render render reference for this link summary and its content variants.
    func topicRenderReference() -> TopicRenderReference {
        let (kind, role) = DocumentationContentRenderer.renderKindAndRole(kind, semantic: nil)
        
        var titleVariants = VariantCollection(defaultValue: title)
        var abstractVariants = VariantCollection(defaultValue: abstract ?? [])
        var fragmentVariants = VariantCollection(defaultValue: declarationFragments)
        
        for variant in variants {
            let traits = variant.traits
            if let title = variant.title {
                titleVariants.variants.append(.init(traits: traits, patch: [.replace(value: title)]))
            }
            if let abstract = variant.abstract {
                abstractVariants.variants.append(.init(traits: traits, patch: [.replace(value: abstract ?? [])]))
            }
            if let fragment = variant.declarationFragments {
                fragmentVariants.variants.append(.init(traits: traits, patch: [.replace(value: fragment)]))
            }
        }
        
        return TopicRenderReference(
            identifier: .init(referenceURL.absoluteString),
            titleVariants: titleVariants,
            abstractVariants: abstractVariants,
            url: relativePresentationURL.absoluteString,
            kind: kind,
            required: false,
            role: role,
            fragmentsVariants: fragmentVariants,
            navigatorTitleVariants: .init(defaultValue: nil),
            estimatedTime: nil,
            conformance: nil,
            isBeta: isBeta,
            isDeprecated: platforms?.contains(where: { $0.unconditionallyDeprecated == true }) ?? false,
            defaultImplementationCount: nil,
            propertyListKeyNames: nil,
            tags: nil,
            images: topicImages ?? []
        )
    }
}
