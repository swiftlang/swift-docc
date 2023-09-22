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
    // This mapping closure exist so that we don't encode ResolvedIdentifier values into the file.
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
                        symbol: node.symbol?.withMinimalDataForSerialization()
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

extension SymbolGraph.Symbol {
    func withMinimalDataForSerialization() -> SymbolGraph.Symbol {
        return SymbolGraph.Symbol(
            identifier: identifier,
            names: Names(title: names.title, navigator: nil, subHeading: nil, prose: nil),
            pathComponents: [],
            docComment: nil,
            accessLevel: accessLevel,
            kind: kind,
            mixins: declarationFragments.map {
                [DeclarationFragments.mixinKey: DeclarationFragments(declarationFragments: $0)]
            } ?? [:]
        )
    }
}

extension PathHierarchy {
    struct FileRepresentation: Codable {
        var nodes: [Node]
        
        var modules: [String: Int]
        var articlesContainer: Int
        var tutorialContainer: Int
        var tutorialOverviewContainer: Int
        
        struct Node: Codable {
            var name: String
            var isDisfavoredInCollision: Bool = false
            var children: [Disambiguation] = []
            var symbol: SymbolGraph.Symbol? // TODO: This repeats a lot of information from the link summary.
            
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
        case symbol
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.name = try container.decode(String.self, forKey: .name)
        self.isDisfavoredInCollision = try container.decodeIfPresent(Bool.self, forKey: .isDisfavoredInCollision) ?? false
        self.children = try container.decodeIfPresent([Disambiguation].self, forKey: .children) ?? []
        self.symbol = try container.decodeIfPresent(SymbolGraph.Symbol.self, forKey: .symbol)
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
        try container.encodeIfPresent(symbol, forKey: .symbol)
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
    var nodeData: [Int: NodeData]
    
    struct NodeData: Codable {
        // ???: What information do we need to save here
        var path: String?
    }
}

extension PathHierarchy.FileRepresentation.Node.Disambiguation {

}

extension PathHierarchyBasedLinkResolver {
    func prepareForSerialization(bundleID: String) throws -> SerializableLinkResolutionInformation {
        var nodeData: [Int: SerializableLinkResolutionInformation.NodeData] = [:]
        let hierarchyFileRepresentation = PathHierarchy.FileRepresentation(pathHierarchy) { identifiers in
            nodeData.reserveCapacity(identifiers.count)
            for (index, identifier) in zip(0..., identifiers) { // where pathHierarchy.lookup[identifier]?.symbol == nil {
                // TODO: It should be possible to recompute the symbol paths in the decoded info.
                nodeData[index] = .init(
                    path: resolvedReferenceMap[identifier]!.url.withoutHostAndPortAndScheme().absoluteString
                )
            }
        }
        
        return SerializableLinkResolutionInformation(
            version: .init(major: 0, minor: 0, patch: 1), // This is still in development
            bundleID: bundleID,
            pathHierarchy: hierarchyFileRepresentation,
            nodeData: nodeData
        )
    }
}
