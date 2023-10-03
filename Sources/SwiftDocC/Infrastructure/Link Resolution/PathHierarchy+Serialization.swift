/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

// MARK: PathHierarchy

extension PathHierarchy.FileRepresentation {
    // This mapping closure exist so that we don't encode ResolvedIdentifier values into the file. They're an implementation detail and they are a not stable across executions.
    
    /// Encode a path hierarchy into a file representation.
    ///
    /// The caller can use `mapCreatedIdentifiers` when encoding and decoding path hierarchies to associate auxiliary data with a node in the hierarchy.
    ///
    /// - Parameters:
    ///   - fileRepresentation: A path hierarchy to encode.
    ///   - mapCreatedIdentifiers: A closure that the caller can use to map indices to resolved identifiers.
    init(
        _ pathHierarchy: PathHierarchy,
        mapCreatedIdentifiers: (_ identifiers: [ResolvedIdentifier]) -> Void
    ) {
        let lookup = pathHierarchy.lookup
        
        // Map each identifier to a number which will be used as to reference other nodes in the file representation.
        var identifierMap = [ResolvedIdentifier: Int]()
        identifierMap.reserveCapacity(lookup.count)
        for (index, identifier) in zip(0..., lookup.keys) {
            identifierMap[identifier] = index
        }
        
        let nodes = [Node](unsafeUninitializedCapacity: lookup.count) { buffer, initializedCount in
            for node in lookup.values {
                buffer.initializeElement(
                    at: identifierMap[node.identifier]!,
                    to: Node(
                        name: node.name,
                        isDisfavoredInCollision: node.isDisfavoredInCollision,
                        children: node.children.values.flatMap({ tree in
                            var disambiguations = [Node.Disambiguation]()
                            for (kind, kindTree) in tree.storage {
                                for (hash, childNode) in kindTree where childNode.identifier != nil { // nodes without identifiers can't be found in the tree
                                    disambiguations.append(.init(kind: kind, hash: hash, nodeID: identifierMap[childNode.identifier]!))
                                }
                            }
                            return disambiguations
                        }),
                        symbolID: node.symbol?.identifier
                    )
                )
            }
            initializedCount = lookup.count
        }
        
        self.nodes = nodes
        self.modules = pathHierarchy.modules.mapValues({ identifierMap[$0.identifier]! })
        self.articlesContainer = identifierMap[pathHierarchy.articlesContainer.identifier]!
        self.tutorialContainer = identifierMap[pathHierarchy.tutorialContainer.identifier]!
        self.tutorialOverviewContainer = identifierMap[pathHierarchy.tutorialOverviewContainer.identifier]!
        
        mapCreatedIdentifiers(Array(lookup.keys))
    }
}

#if swift(<5.8)
// This makes 'initializeElement(at:to:)' available before Swift 5.8.
// Proposal: https://github.com/apple/swift-evolution/blob/main/proposals/0370-pointer-family-initialization-improvements.md
// Implementation: https://github.com/apple/swift/blob/main/stdlib/public/core/UnsafeBufferPointer.swift.gyb#L1031
private extension UnsafeMutableBufferPointer {
    func initializeElement(at index: UnsafeMutableBufferPointer<Element>.Index, to value: Element) {
        assert(startIndex <= index && index < endIndex)
        let p = baseAddress!.advanced(by: index)
        p.initialize(to: value)
    }
}
#endif

extension PathHierarchy {
    /// A file representation of a path hierarchy.
    ///
    /// The file representation can be decoded in later documentation builds to resolve external links to the content where the link resolver was originally created for.
    struct FileRepresentation: Codable {
        /// All the nodes in the hierarchy.
        ///
        /// Other places in the file hierarchy references nodes by their index in this list.
        var nodes: [Node]
        
        /// The module nodes in this hierarchy.
        var modules: [String: Int]
        /// The container for articles and reference documentation.
        var articlesContainer: Int
        /// The container of tutorials.
        var tutorialContainer: Int
        /// The container of tutorial overview pages.
        var tutorialOverviewContainer: Int
        
        /// A node in the
        struct Node: Codable {
            var name: String
            var isDisfavoredInCollision: Bool = false
            var children: [Disambiguation] = []
            var symbolID: SymbolGraph.Symbol.Identifier?
            
            struct Disambiguation: Codable {
                var kind: String?
                var hash: String?
                var nodeID: Int
            }
        }
    }
}

extension PathHierarchy.FileRepresentation.Node {
    enum CodingKeys: String, CodingKey {
        case name
        case isDisfavoredInCollision = "disfavored"
        case children
        case symbolID
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.isDisfavoredInCollision = try container.decodeIfPresent(Bool.self, forKey: .isDisfavoredInCollision) ?? false
        self.children = try container.decodeIfPresent([Disambiguation].self, forKey: .children) ?? []
        self.symbolID = try container.decodeIfPresent(SymbolGraph.Symbol.Identifier.self, forKey: .symbolID)
    }
    
    func encode(to encoder: Encoder) throws {
        var container: KeyedEncodingContainer = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.name, forKey: .name)
        if self.isDisfavoredInCollision {
            try container.encode(self.isDisfavoredInCollision, forKey: .isDisfavoredInCollision)
        }
        if !self.children.isEmpty {
            try container.encode(self.children, forKey: .children)
        }
        try container.encodeIfPresent(symbolID, forKey: .symbolID)
    }
}


// MARK: PathHierarchyBasedLinkResolver

public struct SerializableLinkResolutionInformation: Codable {
    // This type is public so that it can be an argument to a function in `ConvertOutputConsumer`
    
    // This format is not stable yet. Expect information to be significantly reorganized, added, and removed.
    
    var version: SemanticVersion
    var bundleID: String
    var pathHierarchy: PathHierarchy.FileRepresentation
    // Separate storage of node data because the path hierarchy doesn't know the resolved references for articles.
    var nonSymbolPaths: [Int: String]
}

extension PathHierarchyBasedLinkResolver {
    /// Create a file representation of the link resolver.
    ///
    /// The file representation can be decoded in later documentation builds to resolve external links to the content where the link resolver was originally created for.
    func prepareForSerialization(bundleID: String) throws -> SerializableLinkResolutionInformation {
        var nonSymbolPaths: [Int: String] = [:]
        let hierarchyFileRepresentation = PathHierarchy.FileRepresentation(pathHierarchy) { identifiers in
            nonSymbolPaths.reserveCapacity(identifiers.count)
            for (index, identifier) in zip(0..., identifiers) where pathHierarchy.lookup[identifier]?.symbol == nil {
                // Encode the resolved reference for all non-symbols.
                nonSymbolPaths[index] = resolvedReferenceMap[identifier]!.url.withoutHostAndPortAndScheme().absoluteString
            }
        }
        
        return SerializableLinkResolutionInformation(
            version: .init(major: 0, minor: 0, patch: 1), // This is still in development
            bundleID: bundleID,
            pathHierarchy: hierarchyFileRepresentation,
            nonSymbolPaths: nonSymbolPaths
        )
    }
}