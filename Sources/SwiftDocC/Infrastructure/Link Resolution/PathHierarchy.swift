/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// An opaque identifier that uniquely identifies a resolved entry in the path hierarchy,
///
/// Resolved identifiers cannot be inspected and can only be created by the path hierarchy.
struct ResolvedIdentifier: Equatable, Hashable {
    // This is currently implemented with a UUID. That detail should remain hidden and may change at any time.
    private let storage = UUID()
}

/// A hierarchy of path components corresponding to the documentation hierarchy with disambiguation information at every level.
///
/// The main purpose of the path hierarchy is finding documentation entities based on relative paths from other documentation entities with good handling of link disambiguation.
/// This disambiguation aware hierarchy also makes it suitable for determining the least disambiguated paths for each documentation page.
///
/// The documentation hierarchy exist both in the path hierarchy and in the topic graph but for different purposes and in formats with different specialization. Neither is a replacement for the other.
///
/// ### Creation
///
/// Due to the rich relationships between symbols, a path hierarchy is created in two steps. First, the path hierarchy is initialized with all the symbols for all modules.
/// Next, non-symbols are added to the path hierarchy and on-page landmarks for both symbols and non-symbols are added where applicable.
/// It is not possible to add symbols to a path hierarchy after it has been initialized.
///
/// ### Usage
///
/// After a path hierarchy has been fully created — with both symbols and non-symbols — it can be used to find elements in the hierarchy and to determine the least disambiguated paths for all elements.
struct PathHierarchy {
    
    /// A map of module names to module nodes.
    private(set) var modules: [String: Node]
    /// The container of top-level articles in the documentation hierarchy.
    let articlesContainer: Node
    /// The container of tutorials in the documentation hierarchy.
    let tutorialContainer: Node
    /// The container of tutorial overview pages in the documentation hierarchy.
    let tutorialOverviewContainer: Node
    
    /// A map of known documentation nodes based on their unique identifiers.
    private(set) var lookup: [ResolvedIdentifier: Node]
    
    // MARK: Creating a path hierarchy
    
    /// Initializes a path hierarchy with all the symbols from all modules that the given symbol graph loader provides.
    ///
    /// - Parameters:
    ///   - loader: The symbol graph loader that provides all symbols.
    ///   - bundleName: The name of the documentation bundle, used as a container for articles and tutorials.
    ///   - moduleKindDisplayName: The display name for the "module" kind of symbol.
    ///   - knownDisambiguatedPathComponents: A list of path components with known required disambiguations.
    init(
        symbolGraphLoader loader: SymbolGraphLoader,
        bundleName: String,
        moduleKindDisplayName: String = "Framework",
        knownDisambiguatedPathComponents: [String: [String]]? = nil
    ) {
        var roots: [String: Node] = [:]
        var allNodes: [String: [Node]] = [:]
        
        let symbolGraphs = loader.symbolGraphs
            .sorted(by: { lhs, _ in
                return !lhs.key.lastPathComponent.contains("@")
            })
        
        for (url, graph) in symbolGraphs {
            let moduleName = graph.module.name
            let moduleNode: Node
            
            if !loader.hasPrimaryURL(moduleName: moduleName) {
                guard let moduleName = SymbolGraphLoader.moduleNameFor(url),
                      let existingModuleNode = roots[moduleName]
                else { continue }
                moduleNode = existingModuleNode
            } else if let existingModuleNode = roots[moduleName] {
                moduleNode = existingModuleNode
            } else {
                let moduleIdentifierLanguage = graph.symbols.values.first?.identifier.interfaceLanguage ?? SourceLanguage.swift.id
                let moduleSymbol = SymbolGraph.Symbol(
                    identifier: .init(precise: moduleName, interfaceLanguage: moduleIdentifierLanguage),
                    names: SymbolGraph.Symbol.Names(title: moduleName, navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: [moduleName],
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .module, displayName: moduleKindDisplayName),
                    mixins: [:])
                let newModuleNode = Node(symbol: moduleSymbol)
                roots[moduleName] = newModuleNode
                moduleNode = newModuleNode
                allNodes[moduleName] = [moduleNode]
            }
            
            var nodes: [String: Node] = [:]
            nodes.reserveCapacity(graph.symbols.count)
            for (id, symbol) in graph.symbols {
                if let existingNode = allNodes[id]?.first(where: {
                    // If both identifiers are in the same language, they are the same symbol
                    $0.symbol!.identifier.interfaceLanguage == symbol.identifier.interfaceLanguage
                    // Otherwise, if both have the same name and kind their differences doesn't matter for link resolution purposes
                    || ($0.name == symbol.pathComponents.last && $0.symbol!.kind.identifier == symbol.kind.identifier)
                }) {
                    nodes[id] = existingNode
                } else {
                    let node = Node(symbol: symbol)
                    // Disfavor synthesized symbols when they collide with other symbol with the same path.
                    // FIXME: Get information about synthesized symbols from SymbolKit https://github.com/apple/swift-docc-symbolkit/issues/58
                    node.isDisfavoredInCollision = symbol.identifier.precise.contains("::SYNTHESIZED::")
                    nodes[id] = node
                    allNodes[id, default: []].append(node)
                }
            }
            
            var topLevelCandidates = nodes
            for relationship in graph.relationships where relationship.kind.formsHierarchy {
                guard let sourceNode = nodes[relationship.source] else {
                    continue
                }
                if let targetNode = nodes[relationship.target] {
                    targetNode.add(symbolChild: sourceNode)
                    topLevelCandidates.removeValue(forKey: relationship.source)
                } else if let targetNodes = allNodes[relationship.target] {
                    for targetNode in targetNodes {
                        targetNode.add(symbolChild: sourceNode)
                    }
                    topLevelCandidates.removeValue(forKey: relationship.source)
                } else {
                    // Symbols that are not added to the path hierarchy based on relationships will be added to the path hierarchy based on the symbol's path components.
                    // Using relationships over path components is preferred because it provides information needed to disambiguate path collisions.
                    //
                    // In full symbol graphs this is expected to be rare. In partial symbol graphs from the ConvertService it is expected that parent symbols and relationships
                    // will be missing. The ConvertService is expected to provide the necessary `knownDisambiguatedPathComponents` to disambiguate any collisions.
                    continue
                }
            }
            
            for relationship in graph.relationships where relationship.kind == .defaultImplementationOf {
                guard let sourceNode = nodes[relationship.source] else {
                    continue
                }
                // Default implementations collide with the protocol requirement that they implement.
                // Disfavor the default implementation to favor the protocol requirement (or other symbol with the same path).
                sourceNode.isDisfavoredInCollision = true
                
                guard sourceNode.parent == nil else {
                    // This node already has a direct member-of parent. No need to go via the default-implementation-of relationship to find its location in the hierarchy.
                    continue
                }
                
                let targetNodes = nodes[relationship.target].map { [$0] } ?? allNodes[relationship.target] ?? []
                guard !targetNodes.isEmpty else {
                    continue
                }
                
                for requirementTarget in targetNodes {
                    assert(
                        requirementTarget.parent != nil,
                        "The 'defaultImplementationOf' symbol should be a 'memberOf' a known protocol symbol but didn't have a parent relationship in the hierarchy."
                    )
                    requirementTarget.parent?.add(symbolChild: sourceNode)
                }
                topLevelCandidates.removeValue(forKey: relationship.source)
            }
            
            // The hierarchy doesn't contain any non-symbol nodes yet. It's OK to unwrap the `symbol` property.
            for topLevelNode in topLevelCandidates.values where topLevelNode.symbol!.pathComponents.count == 1 {
                moduleNode.add(symbolChild: topLevelNode)
            }
            
            for node in topLevelCandidates.values where node.symbol!.pathComponents.count > 1 {
                var parent = moduleNode
                var components = { (symbol: SymbolGraph.Symbol) -> [String] in
                    let original = symbol.pathComponents
                    if let disambiguated = knownDisambiguatedPathComponents?[node.symbol!.identifier.precise], disambiguated.count == original.count {
                        return disambiguated
                    } else {
                        return original
                    }
                }(node.symbol!)[...].dropLast()
                while !components.isEmpty, let child = try? parent.children[components.first!]?.find(nil, nil) {
                    parent = child
                    components = components.dropFirst()
                }
                for component in components {
                    assert(
                        parent.children[components.first!] == nil,
                        "Shouldn't create a new sparse node when symbol node already exist. This is an indication that a symbol is missing a relationship."
                    )
                    let component = PathParser.parse(pathComponent: component[...])
                    let nodeWithoutSymbol = Node(name: String(component.name))
                    nodeWithoutSymbol.isDisfavoredInCollision = true
                    parent.add(child: nodeWithoutSymbol, kind: component.kind.map(String.init), hash: component.hash.map(String.init))
                    parent = nodeWithoutSymbol
                }
                parent.add(symbolChild: node)
            }
        }
        
        assert(
            allNodes.allSatisfy({ $0.value[0].parent != nil || roots[$0.key] != nil }), """
            Every node should either have a parent node or be a root node. \
            This wasn't true for \(allNodes.filter({ $0.value[0].parent != nil || roots[$0.key] != nil }).map(\.key).sorted())
            """
        )
        
        assert(
            allNodes.values.allSatisfy({ nodesWithSameUSR in nodesWithSameUSR.allSatisfy({ node in
                Array(sequence(first: node, next: \.parent)).last!.symbol!.kind.identifier == .module })
            }), """
            Every node should reach a root node by following its parents up. \
            This wasn't true for \(allNodes.filter({ $0.value.allSatisfy({ Array(sequence(first: $0, next: \.parent)).last!.symbol!.kind.identifier == .module }) }).map(\.key).sorted())
            """
        )
        
        assert(
            allNodes.allSatisfy({ $0.value[0].parent != nil || roots[$0.key] != nil }),
            "Every node should either have a parent node or be a root node. This wasn't true for \(allNodes.filter({ $0.value[0].parent != nil || roots[$0.key] != nil }).map(\.key).sorted())"
        )
        allNodes.removeAll()
        
        // build the lookup list by traversing the hierarchy and adding identifiers to each node
        
        var lookup = [ResolvedIdentifier: Node]()
        func descend(_ node: Node) {
            assert(
                node.identifier == nil,
                "Already encountered \(node.name). This is an indication that a symbol is the source of more than one memberOf relationship."
            )
            if node.symbol != nil {
                node.identifier = ResolvedIdentifier()
                lookup[node.identifier] = node
            }
            for tree in node.children.values {
                for (_, subtree) in tree.storage {
                    for (_, childNode) in subtree {
                        assert(childNode.parent === node, {
                            func describe(_ node: Node?) -> String {
                                guard let node = node else { return "<nil>" }
                                guard let identifier = node.symbol?.identifier else { return node.name }
                                return "\(identifier.precise) (\(identifier.interfaceLanguage))"
                            }
                            return """
                            Every child node should point back to its parent so that the tree can be traversed both up and down without any dead-ends. \
                            This wasn't true for '\(describe(childNode))' which pointed to '\(describe(childNode.parent))' but should have pointed to '\(describe(node))'.
                            """ }()
                        )
                        // In release builds we close off any dead-ends in the tree as a precaution for what shouldn't happen.
                        childNode.parent = node
                        descend(childNode)
                    }
                }
            }
        }
        
        for module in roots.values {
            descend(module)
        }
        
        assert(
            lookup.allSatisfy({ $0.value.parent != nil || roots[$0.value.name] != nil }), """
            Every node should either have a parent node or be a root node. \
            This wasn't true for \(allNodes.filter({ $0.value[0].parent != nil || roots[$0.key] != nil }).map(\.key).sorted())
            """
        )
        
        func newNode(_ name: String) -> Node {
            let id = ResolvedIdentifier()
            let node = Node(name: name)
            node.identifier = id
            lookup[id] = node
            return node
        }
        self.articlesContainer = roots[bundleName] ?? newNode(bundleName)
        self.tutorialContainer = newNode(bundleName)
        self.tutorialOverviewContainer = newNode("tutorials")
        
        assert(
            lookup.allSatisfy({ $0.key == $0.value.identifier }),
            "Every node lookup should match a node with that identifier."
        )
        
        assert(
            lookup.values.allSatisfy({ $0.parent?.identifier == nil || lookup[$0.parent!.identifier] != nil }), """
            Every node's findable parent should exist in the lookup. \
            This wasn't true for \(lookup.values.filter({ $0.parent?.identifier == nil || lookup[$0.parent!.identifier] != nil }).map(\.symbol!.identifier.precise).sorted())
            """
        )
        
        self.modules = roots
        self.lookup = lookup
        
        assert(topLevelSymbols().allSatisfy({ lookup[$0] != nil }))
    }
    
    // MARK: Adding non-symbols
    
    /// Adds an article to the path hierarchy.
    /// - Parameter name: The path component name of the article (the file name without the file extension).
    /// - Returns: The new unique identifier that represent this article.
    mutating func addArticle(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: articlesContainer.identifier, name: name, kind: "article")
    }
    
    /// Adds a tutorial to the path hierarchy.
    /// - Parameter name: The path component name of the tutorial (the file name without the file extension).
    /// - Returns: The new unique identifier that represent this tutorial.
    mutating func addTutorial(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: tutorialContainer.identifier, name: name, kind: "tutorial")
    }
    
    /// Adds a tutorial overview page to the path hierarchy.
    /// - Parameter name: The path component name of the tutorial overview (the file name without the file extension).
    /// - Returns: The new unique identifier that represent this tutorial overview.
    mutating func addTutorialOverview(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: tutorialOverviewContainer.identifier, name: name, kind: "technology")
    }
    
    /// Adds a non-symbol child element to an existing element in the path hierarchy.
    /// - Parameters:
    ///   - parent: The unique identifier of the existing element to add the new child element to.
    ///   - name: The path component name of the new element.
    ///   - kind: The kind of the new element
    /// - Returns: The new unique identifier that represent this element.
    mutating func addNonSymbolChild(parent: ResolvedIdentifier, name: String, kind: String) -> ResolvedIdentifier {
        let parent = lookup[parent]!
        
        let newReference = ResolvedIdentifier()
        let newNode = Node(name: name)
        newNode.identifier = newReference
        self.lookup[newReference] = newNode
        parent.add(child: newNode, kind: kind, hash: nil)
        
        return newReference
    }
    
    /// Adds a non-symbol technology root.
    /// - Parameters:
    ///   - name: The path component name of the technology root.
    /// - Returns: The new unique identifier that represent the root.
    mutating func addTechnologyRoot(name: String) -> ResolvedIdentifier {
        let newReference = ResolvedIdentifier()
        let newNode = Node(name: name)
        newNode.identifier = newReference
        self.lookup[newReference] = newNode
        
        modules[name] = newNode
        
        return newReference
    }
}

// MARK: Node

extension PathHierarchy {
    /// A node in the path hierarchy.
    final class Node {
        /// The unique identifier for this node.
        fileprivate(set) var identifier: ResolvedIdentifier!
        
        // Everything else is file-private or private.
        
        /// The name of this path component in the hierarchy.
        private(set) var name: String
        
        /// The descendants of this node in the hierarchy.
        /// Each name maps to a disambiguation tree that handles
        private(set) var children: [String: DisambiguationContainer]
        
        fileprivate(set) unowned var parent: Node?
        /// The symbol, if a node has one.
        private(set) var symbol: SymbolGraph.Symbol?
        
        /// If the path hierarchy should disfavor this node in a link collision.
        ///
        /// By default, nodes are not disfavored.
        ///
        /// If a favored node collides with a disfavored node the link will resolve to the favored node without
        /// requiring any disambiguation. Referencing the disfavored node requires disambiguation.
        var isDisfavoredInCollision: Bool
        
        /// Initializes a symbol node.
        fileprivate init(symbol: SymbolGraph.Symbol!) {
            self.symbol = symbol
            self.name = symbol.pathComponents.last!
            self.children = [:]
            self.isDisfavoredInCollision = false
        }
        
        /// Initializes a non-symbol node with a given name.
        fileprivate init(name: String) {
            self.symbol = nil
            self.name = name
            self.children = [:]
            self.isDisfavoredInCollision = false
        }
        
        /// Adds a descendant to this node, providing disambiguation information from the node's symbol.
        fileprivate func add(symbolChild: Node) {
            precondition(symbolChild.symbol != nil)
            add(
                child: symbolChild,
                kind: symbolChild.symbol!.kind.identifier.identifier,
                hash: symbolChild.symbol!.identifier.precise.stableHashString
            )
        }
        
        /// Adds a descendant of this node.
        fileprivate func add(child: Node, kind: String?, hash: String?) {
            guard child.parent !== self else { 
                assert(
                    (try? children[child.name]?.find(kind, hash)) === child,
                    "If the new child node already has this node as its parent it should already exist among this node's children."
                )
                return
            }
            // If the name was passed explicitly, then the node could have spaces in its name
            child.parent = self
            children[child.name, default: .init()].add(kind ?? "_", hash ?? "_", child)
            
            assert(child.parent === self, "Potentially merging nodes shouldn't break the child node's reference to its parent.")
        }
        
        /// Combines this node with another node.
        fileprivate func merge(with other: Node) {
            assert(self.parent?.symbol?.identifier.precise == other.parent?.symbol?.identifier.precise)
            self.children = self.children.merging(other.children, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in self.children {
                for subtree in tree.storage.values {
                    for node in subtree.values {
                        node.parent = self
                    }
                }
            }
        }
    }
}

// MARK: Traversing

extension PathHierarchy {
    /// Returns the list of top level symbols
    func topLevelSymbols() -> [ResolvedIdentifier] {
        var result: Set<ResolvedIdentifier> = []
        // Roots represent modules and only have direct symbol descendants.
        for root in modules.values {
            for (_, tree) in root.children {
                for subtree in tree.storage.values {
                    for node in subtree.values where node.symbol != nil {
                        result.insert(node.identifier)
                    }
                }
            }
        }
        return Array(result) + modules.values.map { $0.identifier }
    }
}

// MARK: Removing nodes

extension PathHierarchy {
    // When unregistering a documentation bundle from a context, entries for that bundle should no longer be findable.
    // The below implementation marks nodes as "not findable" while leaving them in the hierarchy so that they can be
    // traversed.
    // This would be problematic if it happened repeatedly but in practice the path hierarchy will only be in this state
    // after unregistering a data provider until a new data provider is registered.
    
    /// Removes a node from the path hierarchy so that it can no longer be found.
    /// - Parameter id: The unique identifier for the node.
    mutating func removeNodeWithID(_ id: ResolvedIdentifier) {
        // Remove the node from the lookup and unset its identifier
        lookup.removeValue(forKey: id)!.identifier = nil
    }
}

// MARK: Disambiguation container

extension PathHierarchy {
    /// A fixed-depth tree that stores disambiguation information and finds values based on partial disambiguation.
    struct DisambiguationContainer {
        // Each disambiguation tree is fixed at two levels and stores a limited number of values.
        // In practice, almost all trees store either 1, 2, or 3 elements with 1 being the most common.
        // It's very rare to have more than 10 values and 20+ values is extremely rare.
        //
        // Given this expected amount of data, a nested dictionary implementation performs well.
        private(set) var storage: [String: [String: PathHierarchy.Node]] = [:]
    }
}

extension PathHierarchy.DisambiguationContainer {
    /// Add a new value to the tree for a given pair of kind and hash disambiguations.
    /// - Parameters:
    ///   - kind: The kind disambiguation for this value.
    ///   - hash: The hash disambiguation for this value.
    ///   - value: The new value
    /// - Returns: If a value already exist with the same pair of kind and hash disambiguations.
    mutating func add(_ kind: String, _ hash: String, _ value: PathHierarchy.Node) {
        if let existing = storage[kind]?[hash] {
            existing.merge(with: value)
        } else if storage.count == 1, let existing = storage["_"]?["_"] {
            // It is possible for articles and other non-symbols to collide with unfindable symbol placeholder nodes.
            // When this happens, remove the placeholder node and move its children to the real (non-symbol) node.
            value.merge(with: existing)
            storage = [kind: [hash: value]]
        } else {
            storage[kind, default: [:]][hash] = value
        }
    }
    
    /// Combines the data from this tree with another tree to form a new, merged disambiguation tree.
    func merge(with other: Self) -> Self {
        return .init(storage: self.storage.merging(other.storage, uniquingKeysWith: { lhs, rhs in
            lhs.merging(rhs, uniquingKeysWith: {
                lhsValue, rhsValue in
                assert(lhsValue.symbol!.identifier.precise == rhsValue.symbol!.identifier.precise)
                return lhsValue
            })
        }))
    }
}

private extension SymbolGraph.Relationship.Kind {
    /// Whether or not this relationship kind forms a hierarchical relationship between the source and the target.
    var formsHierarchy: Bool {
        switch self {
        case .memberOf, .optionalMemberOf, .requirementOf, .optionalRequirementOf, .extensionTo, .declaredIn:
            return true
        default:
            return false
        }
    }
}
