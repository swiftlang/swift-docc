/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
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
/// After a path hierarchy has been fully created---with both symbols and non-symbols---it can be used to find elements in the hierarchy and to determine the least disambiguated paths for all elements.
struct PathHierarchy {
    /// The list of module nodes.
    private(set) var modules: [Node]
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
            .map { url, graph in
                // Only compute the source language for each symbol graph once.
                (url: url, graph: graph, language: graph.symbols.values.mapFirst(where: { SourceLanguage(id: $0.identifier.interfaceLanguage) }))
            }
            .sorted(by: { lhs, rhs in
                return !lhs.url.lastPathComponent.contains("@")
            })
                
        // To try to handle certain invalid symbol graph files gracefully, we track symbols that don't have a place in the hierarchy so that we can look for a place for those symbols.
        // Because this is a last resort, we only want to do this processing after all the symbol graphs have already been processed.
        var symbolNodesOutsideOfHierarchyByModule: [String: [Node]] = [:]

        for (url, graph, language) in symbolGraphs {
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
                let moduleIdentifierLanguage = language ?? .swift
                let moduleSymbol = SymbolGraph.Symbol(
                    identifier: .init(precise: moduleName, interfaceLanguage: moduleIdentifierLanguage.id),
                    names: SymbolGraph.Symbol.Names(title: moduleName, navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: [], // Other symbols don't include the module name in their path components.
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .module, displayName: moduleKindDisplayName),
                    mixins: [:])
                let newModuleNode = Node(symbol: moduleSymbol, name: moduleName)
                roots[moduleName] = newModuleNode
                moduleNode = newModuleNode
                allNodes[moduleName] = [moduleNode]
            }
            if let language {
                moduleNode.languages.insert(language)
            }

            var nodes: [String: Node] = [:]
            nodes.reserveCapacity(graph.symbols.count)
            for (id, symbol) in graph.symbols {
                if let possibleNodes = allNodes[id],
                   let existingNode = possibleNodes.first(where: {
                       // If both identifiers are in the same language, they are the same symbol.
                       $0.symbol!.identifier.interfaceLanguage == symbol.identifier.interfaceLanguage
                   }) ?? possibleNodes.first(where: {
                       // Otherwise, if both have the same path components and kind, their differences don't matter for link resolution purposes.
                       $0.symbol!.pathComponents == symbol.pathComponents && $0.symbol!.kind.identifier == symbol.kind.identifier
                   })
                {
                    nodes[id] = existingNode
                    if existingNode.counterpart?.languages.contains(language!) != true {
                        // Unless this symbol is already split into language counterparts, add the languages to this node.
                        existingNode.languages.insert(language!)
                    }
                } else {
                    assert(!symbol.pathComponents.isEmpty, "A symbol should have at least its own name in its path components.")

                    let node = Node(symbol: symbol, name: symbol.pathComponents.last!)
                    // Disfavor synthesized symbols when they collide with other symbol with the same path.
                    // FIXME: Get information about synthesized symbols from SymbolKit https://github.com/swiftlang/swift-docc-symbolkit/issues/58
                    if symbol.identifier.precise.contains("::SYNTHESIZED::") {
                        node.specialBehaviors.formUnion([.disfavorInLinkCollision, .excludeFromAutomaticCuration])
                    }
                    nodes[id] = node
                    
                    if let existing = allNodes[id] {
                        node.counterpart = existing.first
                        for other in existing {
                            other.counterpart = node
                        }
                    }
                    allNodes[id, default: []].append(node)
                }
            }

            // If there are multiple symbol graphs (for example for different source languages or platforms) then the nodes may have already been added to the hierarchy.
            var topLevelCandidates = nodes.filter { _, node in node.parent == nil }
            for relationship in graph.relationships where relationship.kind.formsHierarchy {
                guard let sourceNode = nodes[relationship.source], let expectedContainerName = sourceNode.symbol?.pathComponents.dropLast().last else {
                    continue
                }
                // The relationship only specify the target symbol's USR but if the target symbol has different representations in different source languages the relationship
                // alone doesn't specify which language representation the source symbol belongs to. We could check the source and target symbol's interface language but that
                // would require that we redundantly create multiple nodes for the same symbol in many common cases and then merge them. To avoid doing that, we instead check
                // the source symbol's path components to find the correct target symbol by matching its name.
                if let targetNode = nodes[relationship.target], targetNode.name == expectedContainerName {
                    if sourceNode.parent == nil {
                        targetNode.add(symbolChild: sourceNode)
                    } else if sourceNode.parent !== targetNode && sourceNode.counterpart?.parent !== targetNode {
                        // If the source node already exist in a different location in the hierarchy we need to split it into separate nodes for each language representation.
                        // This ensures that each node has a single parent, so that the hierarchy can be unambiguously walked upwards to expand the "scope" of a search.
                        let clonedSourceNode = sourceNode.deepClone(
                            separating: language!,
                            keeping: sourceNode.languages.subtracting([language!]),
                            symbolsByUSR: graph.symbols,
                            didCloneNode: { newNode, newSymbol in
                                nodes[newSymbol.identifier.precise] = newNode
                                allNodes[newSymbol.identifier.precise, default: []].append(newNode)
                            }
                        )
                        targetNode.add(symbolChild: clonedSourceNode)
                    }
                    topLevelCandidates.removeValue(forKey: relationship.source)
                } else if var targetNodes = allNodes[relationship.target] {
                    // If the source was added in an extension symbol graph file, then its target won't be found in the same symbol graph file (in `nodes`).
                    
                    // We may have encountered multiple language representations of the target symbol. Try to find the best matching representation of the target to add the source to.
                    // Remove any targets that don't match the source symbol's path components (see comment above for more details) and languages (see comments below).
                    targetNodes.removeAll(where: { $0.name != expectedContainerName || $0.languages.isDisjoint(with: sourceNode.languages) })
                    guard !targetNodes.isEmpty else {
                        // If none of the symbol graphs contain a matching node it's likely a bug in the tool that generated the symbol graph.
                        // If this happens we leave the source node in `topLevelCandidates` to try and let a later fallback code path recover from the symbol graph issue.
                        continue
                    }
                    
                    // Prefer the symbol that matches the relationship's language.
                    if let targetNode = targetNodes.first(where: { $0.symbol!.identifier.interfaceLanguage == language?.id }) {
                        targetNode.add(symbolChild: sourceNode)
                    } else {
                        // It's not clear which target to add the source to, so we add it to all of them.
                        // This will likely hit a _debug_ assertion (later in this initializer) about inconsistent traversal through the hierarchy,
                        // but in release builds DocC will "repair" the inconsistent hierarchy.
                        for targetNode in targetNodes where !sourceNode.languages.isDisjoint(with: targetNode.languages) {
                            targetNode.add(symbolChild: sourceNode)
                        }
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
                sourceNode.specialBehaviors = [.disfavorInLinkCollision, .excludeFromAutomaticCuration]
                
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
            
            assertAllNodes(in: topLevelCandidates.values.filter { $0.symbol!.pathComponents.count > 1 }, satisfy: { $0.parent == nil },
                           "Top-level candidates shouldn't already exist in the hierarchy.")
            
            for node in topLevelCandidates.values where node.symbol!.pathComponents.count > 1 && node.parent == nil {
                symbolNodesOutsideOfHierarchyByModule[moduleNode.symbol!.identifier.precise, default: []].append(node)
            }
        }
        
        for (moduleID, nodes) in symbolNodesOutsideOfHierarchyByModule {
            let moduleNode = roots[moduleID]!
            for node in nodes where node.parent == nil {
                var parent = moduleNode
                var components = { (symbol: SymbolGraph.Symbol) -> [String] in
                    let original = symbol.pathComponents
                    // The `ConvertService` may pass a lookup of "known disambiguated path components" per symbol that the path hierarchy
                    // wouldn't be able to compute itself because the "partial" symbol graph doesn't contain all the symbols to accurately
                    // determine the minimal required disambiguation per path.
                    if let disambiguated = knownDisambiguatedPathComponents?[node.symbol!.identifier.precise], disambiguated.count == original.count {
                        return disambiguated
                    } else {
                        return original
                    }
                }(node.symbol!)[...].dropLast()
                while !components.isEmpty, let child = parent.children[components.first!]?.singleMatch() {
                    parent = child
                    components = components.dropFirst()
                }
                for component in components {
                    // FIXME:
                    // This code path is both expected (when `knownDisambiguatedPathComponents` is non-nil) and unexpected (when the symbol graph is missing data or contains extra relationships).
                    // It would be good to restructure this code to better distinguish what's supported behavior and what's a best-effort attempt at gracefully handle invalid symbol graphs.
                    if let existing = parent.children[component] {
                        // This code tries to repair incomplete symbol graph files by guessing that the symbol with the most overlapping languages is the intended container.
                        // Valid symbol graph files we should never end up here.
                        var bestLanguageMatch: (node: Node, count: Int)?
                        for element in existing.storage {
                            let numberOfMatchingLanguages = node.languages.intersection(element.node.languages).count
                            if (bestLanguageMatch?.count ?? .min) < numberOfMatchingLanguages {
                                bestLanguageMatch = (node: element.node, count: numberOfMatchingLanguages)
                            }
                        }
                        if let bestLanguageMatch {
                            // If there's a real symbol that matches this node's languages, use that node instead of creating a placeholder node
                            parent = bestLanguageMatch.node
                            continue
                        }
                    }
                    
                    assert(
                        parent.children[component] == nil,
                        "Shouldn't create a new sparse node when symbol node already exist. This is an indication that a symbol is missing a relationship."
                    )
                    
                    guard knownDisambiguatedPathComponents != nil else {
                        // If the path hierarchy wasn't passed any "known disambiguated path components" then the sparse/placeholder nodes won't contain any disambiguation.
                        let nodeWithoutSymbol = Node(name: component)
                        nodeWithoutSymbol.specialBehaviors = [.disfavorInLinkCollision, .excludeFromAutomaticCuration]
                        parent.add(child: nodeWithoutSymbol, kind: nil, hash: nil)
                        parent = nodeWithoutSymbol
                        continue
                    }
                    // If the path hierarchy was passed a lookup of "known disambiguation" path components", then it's possible that each path component could contain disambiguation that needs to be parsed.
                    let component = PathParser.parse(pathComponent: component[...])
                    let nodeWithoutSymbol = Node(name: String(component.name))
                    nodeWithoutSymbol.specialBehaviors = [.disfavorInLinkCollision, .excludeFromAutomaticCuration]
                    // Create a spare/placeholder node with the parsed disambiguation for this path component.
                    switch component.disambiguation {
                    case .kindAndHash(kind: let kind, hash: let hash):
                        parent.add(child: nodeWithoutSymbol, kind: kind.map(String.init), hash: hash.map(String.init))
                    case .typeSignature(let parameterTypes, let returnTypes):
                        parent.add(child: nodeWithoutSymbol, kind: nil, hash: nil, parameterTypes: parameterTypes?.map(String.init), returnTypes: returnTypes?.map(String.init))
                    case nil:
                        parent.add(child: nodeWithoutSymbol, kind: nil, hash: nil)
                    }
                    parent = nodeWithoutSymbol
                }
                parent.add(symbolChild: node)
            }
        }

        // Overload group don't exist in the individual symbol graphs.
        // Since overload groups don't change the _structure_ of the path hierarchy, we can add them after after all symbols for all platforms have already been added.
        for unifiedGraph in loader.unifiedGraphs.values {
            // Create nodes for all the overload groups
            let overloadGroupNodes: [String: Node] = unifiedGraph.overloadGroupSymbols.reduce(into: [:]) { acc, uniqueID in
                assert(allNodes[uniqueID] == nil,
                       "Overload group ID \(uniqueID) already has a symbol node in the hierarchy: \(allNodes[uniqueID]!.map(\.name).sorted().joined(separator: ","))")
                guard let unifiedSymbol = unifiedGraph.symbols[uniqueID] else { return }
                guard let symbol = unifiedSymbol.defaultSymbol else {
                    fatalError("Overload group \(uniqueID) doesn't have a default symbol.")
                }
                acc[uniqueID] = Node(symbol: symbol, name: symbol.pathComponents.last!)
            }

            for relationship in unifiedGraph.relationshipsByLanguage.flatMap(\.value) where relationship.kind == .overloadOf {
                guard let groupNode = overloadGroupNodes[relationship.target], let overloadedSymbolNodes = allNodes[relationship.source] else {
                    continue
                }
                
                // The overload group symbol is cloned from a real symbol and has the same type signature as the clone. This prevents either symbol from using
                // parameter type or return type disambiguation. Exclude the overload group from this, so that the real symbol can use it.
                groupNode.specialBehaviors.insert(.excludeFromAdvancedLinkDisambiguation)

                for overloadedSymbolNode in overloadedSymbolNodes {
                    // We want to disfavor the individual overload symbols in favor of resolving links to their overload group symbol.
                    overloadedSymbolNode.specialBehaviors.formUnion([.disfavorInLinkCollision, .excludeFromAutomaticCuration])

                    guard let parent = overloadedSymbolNode.parent else { continue }

                    assert(groupNode.parent == nil || groupNode.parent === parent, """
                    Unexpectedly grouped symbols with different locations in the symbol hierarchy:
                    Group ID: \(groupNode.symbol!.identifier.precise)
                    Locations: \(Set(overloadedSymbolNodes.map { $0.symbol!.pathComponents.joined(separator: "/") }.sorted()))
                    """)
                    parent.add(symbolChild: groupNode)
                }
                assert(groupNode.parent != nil, "Unexpectedly found no location in the hierarchy for overload group \(relationship.source)")
            }
        }

        assertAllNodes(in: allNodes, satisfy: { $0.parent != nil || roots[$0.symbol!.identifier.precise] != nil },
                       "Every node should either have a parent node or be a root node.")
        
        assertAllNodes(in: allNodes, satisfy: { Array(sequence(first: $0, next: \.parent)).last!.symbol!.kind.identifier == .module },
                       "Every node should reach a root node by following its parents up.")
        
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
            for container in node.children.values {
                for element in container.storage {
                    assert(element.node.parent === node, {
                        func describe(_ node: Node?) -> String {
                            guard let node else { return "<nil>" }
                            guard let symbol = node.symbol else { return node.name }
                            let id = symbol.identifier
                            return "\(id.precise) (\(id.interfaceLanguage).\(symbol.kind.identifier.identifier)) [\(symbol.pathComponents.joined(separator: "/"))]"
                        }
                        return """
                            Every child node should point back to its parent so that the tree can be traversed both up and down without any dead-ends. \
                            This wasn't true for '\(describe(element.node))' which pointed to '\(describe(element.node.parent))' but should have pointed to '\(describe(node))'.
                            """ }()
                    )
                    // In release builds we close off any dead-ends in the tree as a precaution for what shouldn't happen.
                    element.node.parent = node
                    descend(element.node)
                }
            }
        }
        
        for module in roots.values {
            descend(module)
        }
        
        assertAllNodes(in: lookup.values, satisfy: { $0.parent != nil || roots[$0.name] != nil },
                       "Every node should either have a parent node or be a root node.")
        
        assertAllNodes(in: lookup.values, satisfy: { $0.counterpart == nil || lookup[$0.counterpart!.identifier] != nil },
                       "Every counterpart node should exist in the hierarchy.")
        
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
        
        assertAllNodes(in: lookup.values, satisfy: { $0.parent?.identifier == nil || lookup[$0.parent!.identifier] != nil },
                       "Every node's findable parent should exist in the lookup.")
        
        self.modules = Array(roots.values)
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
        return addNonSymbolChild(parent: tutorialOverviewContainer.identifier, name: name, kind: "tutorial-toc")
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
        
        modules.append(newNode)
        
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
        fileprivate(set) var symbol: SymbolGraph.Symbol?
        /// The languages where this node's symbol is represented.
        fileprivate(set) var languages: Set<SourceLanguage> = []
        /// The other language representation of this symbol.
        ///
        /// > Note: Swift currently only supports one other language representation (either Objective-C or C++ but not both).
        fileprivate(set) unowned var counterpart: Node?
        
        /// A set of non-standard behaviors that apply to this node.
        fileprivate(set) var specialBehaviors: SpecialBehaviors
        
        /// Options that specify non-standard behaviors of a node.
        struct SpecialBehaviors: OptionSet {
            let rawValue: Int
            
            /// This node is disfavored in the the case of a link collision.
            ///
            /// If a favored node collides with a disfavored node the link will resolve to the favored node without requiring any disambiguation.
            /// Referencing the disfavored node requires disambiguation unless it's the only match for that link.
            static let disfavorInLinkCollision = Self(rawValue: 1 << 0)
            
            /// This node is excluded from automatic curation.
            static let excludeFromAutomaticCuration = Self(rawValue: 1 << 1)
            
            /// This node is excluded from advanced link disambiguation, for example type-signature disambiguation.
            static let excludeFromAdvancedLinkDisambiguation = Self(rawValue: 1 << 2)
        }
        
        /// A Boolean value indicating whether this node is disfavored in link collisions.
        var isDisfavoredInLinkCollisions: Bool {
            specialBehaviors.contains(.disfavorInLinkCollision)
        }
        /// A Boolean value indicating whether this node is excluded from automatic curation.
        var isExcludedFromAutomaticCuration: Bool {
            specialBehaviors.contains(.excludeFromAutomaticCuration)
        }
        /// A Boolean value indicating whether this node is excluded from advanced link disambiguation, for example type-signature disambiguation.
        var isExcludedFromAdvancedLinkDisambiguation: Bool {
            specialBehaviors.contains(.excludeFromAdvancedLinkDisambiguation)
        }
        
        /// Initializes a symbol node.
        fileprivate init(symbol: SymbolGraph.Symbol!, name: String) {
            self.symbol = symbol
            self.name = name
            self.children = [:]
            self.specialBehaviors = []
            self.languages = [SourceLanguage(id: symbol.identifier.interfaceLanguage)]
        }
        
        /// Initializes a non-symbol node with a given name.
        fileprivate init(name: String) {
            self.symbol = nil
            self.name = name
            self.children = [:]
            self.specialBehaviors = []
        }
        
        fileprivate func deepClone(
            separating separatedLanguage: SourceLanguage,
            keeping otherLanguages: Set<SourceLanguage>,
            symbolsByUSR: borrowing [String: SymbolGraph.Symbol],
            didCloneNode: (Node, SymbolGraph.Symbol) -> Void
        ) -> Node {
            assert(!otherLanguages.contains(separatedLanguage), "The caller should have already removed '\(separatedLanguage.id)' from '\(languages.sorted().map(\.id).joined(separator: ", "))'")
            
            let clone: Node
            if let currentSymbol = symbol {
                // If a representation of the symbol exist in the current local symbol graph, prefer that for more correct disambiguation information.
                let symbol = symbolsByUSR[currentSymbol.identifier.precise] ?? currentSymbol
                clone = Node(symbol: symbol, name: name)
                didCloneNode(clone, symbol)
            } else {
                assertionFailure("Unexpectedly cloned a non-symbol node '\(name)' into separate language representations ('\(separatedLanguage.id)' vs '\(otherLanguages.sorted().map(\.id).joined(separator: ", "))').")
                clone = Node(name: name)
            }
            // Update languages and counterparts
            clone.languages = [separatedLanguage]
            languages.remove(separatedLanguage)
            assert(!languages.isEmpty, """
                Unexpectedly cloned '\(symbol?.identifier.precise ?? "non-symbol named \(name)")' for '\(separatedLanguage.id)' when it was already the only language it was available for.
                """)
            
            clone.counterpart = self
            self.counterpart = clone
            
            // Assign all the children to either the original, the clone, or both.
            let originalChildren = children
            children.removeAll(keepingCapacity: true)
            
            func addOrMove(_ node: Node, to containerNode: Node) {
                if node.symbol != nil {
                    containerNode.add(symbolChild: node)
                } else {
                    containerNode.add(child: node, kind: nil, hash: nil)
                }
                assert(!containerNode.languages.isDisjoint(with: node.languages), """
                    Unexpectedly added a node to a container without any overlapping languages.
                    Child node languages:  \(node.languages.sorted().map(\.id).joined(separator: ", "))
                    Parent node languages: \(node.languages.sorted().map(\.id).joined(separator: ", "))
                    """)
            }
            
            for elements in originalChildren.values {
                for element in elements.storage {
                    let node = element.node
                    node.parent = nil // Remove the association with the original container. This node will be added to either the original (again) or to the clone.
                    let nodeLanguages = node.languages
                    
                    switch (nodeLanguages.contains(separatedLanguage), !nodeLanguages.isDisjoint(with: languages)) {
                        case (true, false):
                            // This node only exist for the separated language, so it only belongs in the clone. No recursive copying needed.
                            addOrMove(node, to: clone)
                            
                        case (false, true):
                            // This node doesn't exist for the separated language, so it only belongs in the original. No recursive copying needed.
                            addOrMove(node, to: self)
                            
                        case (true, true):
                            // This node needs to have deep copies for both the original and the clone.
                            let innerClone = node.deepClone(separating: separatedLanguage, keeping: otherLanguages, symbolsByUSR: symbolsByUSR, didCloneNode: didCloneNode)
                            addOrMove(node, to: self)
                            addOrMove(innerClone, to: clone)
                            
                        case (false, false):
                            assertionFailure("Node \(node.name) (\(node.languages.sorted().map(\.id).joined(separator: ","))) doesn't belong in either '\(separatedLanguage.id)' or '\(otherLanguages.sorted().map(\.id).joined(separator: ", "))'.")
                            continue
                    }
                }
            }
            
            return clone
        }

        /// Adds a descendant to this node, providing disambiguation information from the node's symbol.
        fileprivate func add(symbolChild: Node) {
            precondition(symbolChild.symbol != nil)
            let symbol = symbolChild.symbol!
            
            let functionSignatureTypeNames = PathHierarchy.functionSignatureTypeNames(for: symbol)
            add(
                child: symbolChild,
                kind: symbol.kind.identifier.identifier,
                hash: symbol.identifier.precise.stableHashString,
                parameterTypes: functionSignatureTypeNames?.parameterTypeNames,
                returnTypes: functionSignatureTypeNames?.returnTypeNames
            )
        }
        
        /// Adds a descendant of this node.
        fileprivate func add(child: Node, kind: String?, hash: String?, parameterTypes: [String]? = nil, returnTypes: [String]? = nil) {
            guard child.parent !== self else { 
                assert(
                    children.keys.contains(child.name) &&
                    (try? children[child.name]?.find(.kindAndHash(kind: kind?[...], hash: hash?[...]))) === child,
                    "If the new child node already has this node as its parent it should already exist among this node's children."
                )
                return
            }

            assert(child.parent == nil, "Nodes that already have a parent should not be added to a different parent.")
            // If the name was passed explicitly, then the node could have spaces in its name
            child.parent = self
            children[child.name, default: .init()].add(child, kind: kind, hash: hash, parameterTypes: parameterTypes, returnTypes: returnTypes)
            
            assert(child.parent === self, "Potentially merging nodes shouldn't break the child node's reference to its parent.")
        }
        
        /// Combines this node with another node.
        func merge(with other: Node) {
            assert(self.parent?.symbol?.identifier.precise == other.parent?.symbol?.identifier.precise)
            self.children = self.children.merging(other.children, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in self.children {
                for element in tree.storage {
                    element.node.parent = self
                }
            }
            
            if let otherSymbol = other.symbol {
                languages.insert(SourceLanguage(id: otherSymbol.identifier.interfaceLanguage))
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
        for root in modules {
            for (_, tree) in root.children {
                for element in tree.storage where element.node.symbol != nil {
                    result.insert(element.node.identifier)
                }
            }
        }
        return Array(result) + modules.map { $0.identifier }
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
    /// A container that stores values and their disambiguation information and find values based on partial disambiguation.
    struct DisambiguationContainer {
        // Each disambiguation container stores its elements in a flat list, which is very short in practice.
        //
        // Almost all containers store either 1, 2, or 3 elements with 1 being the most common case.
        // It's very rare to have more than 10 values and 20+ values is extremely rare.
        //
        // Given this expected amount of data, linear searches through an array performs well.
        //
        // Even though the container only stores one element per unique hash and kind pair, using a `Set` wouldn't
        // help since any colliding elements need to be merged.
        private(set) var storage = ContiguousArray<Element>()
    }
}

extension PathHierarchy.DisambiguationContainer {
    struct Element {
        let node: PathHierarchy.Node
        let kind: String?
        let hash: String?
        let parameterTypes: [String]?
        let returnTypes: [String]?
        
        func matches(kind: String?, hash: String?) -> Bool {
            // The 'hash' is more unique than the 'kind', so compare the 'hash' first.
            self.hash == hash && self.kind == kind
        }
        /// Placeholder values, also called "unfindable elements" or "sparse nodes", are created when constructing a path hierarchy for a "partial" symbol graph file.
        ///
        /// When the `ConvertService` builds documentation for a single symbol with multiple path components, the path hierarchy fills in placeholder nodes
        /// for the other path components. This ensures that the nodes in the hierarchy are connected and that there's the same number of nodes—with the same
        /// names—between the module node and the non-placeholder node as there would be in the full symbol graph.
        ///
        /// The placeholder nodes can be traversed up and down while resolving a link—to reach a non-placeholder node—but the link will be considered "not found"
        /// if it ends at a placeholder node.
        var isPlaceholderValue: Bool {
            // Only symbols have 'hash' disambiguation, so check the 'kind' first.
            kind == nil && hash == nil
        }
    }

    /// Add a new value and its disambiguation information to the container.
    /// - Parameters:
    ///   - value: The new value.
    ///   - kind: The kind disambiguation for this value, if any.
    ///   - hash: The hash disambiguation for this value, if any.
    ///   - parameterTypes: The type names of the parameter disambiguation for this value, if any.
    ///   - returnTypes: The type names of the return value disambiguation for this value, if any.
    mutating func add(_ value: PathHierarchy.Node, kind: String?, hash: String?, parameterTypes: [String]?, returnTypes: [String]?) {
        // When adding new elements to the container, it's sufficient to check if the hash and kind match.
        if let existing = storage.first(where: { $0.matches(kind: kind, hash: hash) }) {
            // If the container already has a version of this node, merge the new value with the existing value.
            existing.node.merge(with: value)
        } else if storage.count == 1, storage.first!.isPlaceholderValue {
            // It is possible for articles and other non-symbols to collide with "unfindable" symbol placeholder nodes.
            // When this happens, remove the placeholder node and move its children to the real (non-symbol) node.
            let existing = storage.removeFirst()
            value.merge(with: existing.node)
            storage = [Element(node: value, kind: kind, hash: hash, parameterTypes: parameterTypes, returnTypes: returnTypes)]
        } else {
            storage.append(Element(node: value, kind: kind, hash: hash, parameterTypes: parameterTypes, returnTypes: returnTypes))
        }
    }
    
    /// Combines the data from this tree with another tree to form a new, merged disambiguation tree.
    func merge(with other: Self) -> Self {
        var newStorage = storage
        for element in other.storage {
            if let existingIndex = storage.firstIndex(where: { $0.matches(kind: element.kind, hash: element.hash )}) {
                let existing = storage[existingIndex]
                // If the same element exist in both containers, keep it unless the "other" element is the Swift counterpart of this symbol.
                if existing.node.counterpart === element.node,
                   element.node.symbol?.identifier.interfaceLanguage == "swift"
                {
                    // The "other" element is the Swift counterpart. Replace the existing element with it.
                    newStorage[existingIndex] = element
                }
            } else {
                newStorage.append(element)
            }
        }
        return .init(storage: newStorage)
    }
}

// MARK: Deserialization

extension PathHierarchy {
    // This is defined in the main PathHierarchy.swift file to access fileprivate properties and PathHierarchy.Node API without making it internally visible.
    
    // This mapping closure exist so that we don't encode ResolvedIdentifier values into the file. They're an implementation detail and they are a not stable across executions.
    
    /// Decode a path hierarchy from its file representation.
    ///
    /// The caller can use `mapCreatedIdentifiers` when encoding and decoding path hierarchies to associate auxiliary data with a node in the hierarchy.
    ///
    /// - Parameters:
    ///   - fileRepresentation: A file representation to decode.
    ///   - mapCreatedIdentifiers: A closure that the caller can use to map indices to resolved identifiers.
    init(
        _ fileRepresentation: FileRepresentation,
        mapCreatedIdentifiers: (_ identifiers: [ResolvedIdentifier]) -> Void
    ) {
        // Generate new identifiers. While building the path hierarchy, the node numbers map to identifiers via index lookup in this array.
        var identifiers = [ResolvedIdentifier]()
        identifiers.reserveCapacity(fileRepresentation.nodes.count)
        for _ in fileRepresentation.nodes.indices {
            identifiers.append(ResolvedIdentifier())
        }
        
        var lookup = [ResolvedIdentifier: Node]()
        lookup.reserveCapacity(fileRepresentation.nodes.count)
        // Iterate once to create all the nodes
        for (index, fileNode) in zip(0..., fileRepresentation.nodes) {
            let node: Node
            if let symbolID = fileNode.symbolID {
                // Symbols decoded from a file representation only need an accurate ID. The rest of the information is never read and can be left empty.
                let symbol = SymbolGraph.Symbol(
                    identifier: symbolID,
                    names: .init(title: "", navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: [],
                    docComment: nil,
                    accessLevel: .public,
                    // To make the file format smaller we don't store the symbol kind identifiers with each node. Instead, the kind identifier is stored
                    // as disambiguation and is filled in while building up the hierarchy below.
                    kind: SymbolGraph.Symbol.Kind(rawIdentifier: "", displayName: ""),
                    mixins: [:]
                )
                node = Node(symbol: symbol, name: fileNode.name)
            } else {
                node = Node(name: fileNode.name)
            }
            node.specialBehaviors = .init(rawValue: fileNode.rawSpecialBehavior)
            node.identifier = identifiers[index]
            lookup[node.identifier] = node
        }
        // Iterate again to construct the tree
        for (index, fileNode) in fileRepresentation.nodes.indexed() {
            let node = lookup[identifiers[index]]!
            for child in fileNode.children {
                let childNode = lookup[identifiers[child.nodeID]]!
                // Even if this is a symbol node, explicitly pass the kind and hash disambiguation.
                node.add(
                    child: childNode,
                    kind: child.kind,
                    hash: child.hash,
                    parameterTypes: child.parameterTypes,
                    returnTypes: child.returnTypes
                )
                if let kind = child.kind {
                    // Since the symbol was created with an empty symbol kind, fill in its kind identifier here.
                    childNode.symbol?.kind.identifier = .init(identifier: kind)
                }
            }
        }
        
        self.lookup = lookup
        let modules = fileRepresentation.modules.map({ lookup[identifiers[$0]]! })
        // Fill in the symbol kind of all modules. This is needed since the modules were created with empty symbol kinds and since no other symbol has a 
        // module as its child, so the modules didn't get their symbol kind set when building up the hierarchy above.
        for node in modules {
            node.symbol?.kind.identifier = .module
        }
        self.modules = modules
        self.articlesContainer = lookup[identifiers[fileRepresentation.articlesContainer]]!
        self.tutorialContainer = lookup[identifiers[fileRepresentation.tutorialContainer]]!
        self.tutorialOverviewContainer = lookup[identifiers[fileRepresentation.tutorialOverviewContainer]]!
        
        mapCreatedIdentifiers(identifiers)
    }
}

// MARK: Hierarchical symbol relationships

private extension SymbolGraph.Relationship.Kind {
    /// Whether or not this relationship kind forms a hierarchical relationship between the source and the target.
    var formsHierarchy: Bool {
        switch self {
        case .memberOf, .optionalMemberOf, .requirementOf, .optionalRequirementOf, .extensionTo, .inContextOf, .declaredIn:
            return true
        default:
            return false
        }
    }
}

// MARK: Link completion

// This extension can't be defined in another file because it uses file-private API.
extension LinkCompletionTools {
    /// Creates a new path hierarchy node for link completion purposes.
    ///
    /// Use these nodes to compute disambiguation and match against parsed link components.
    ///
    /// - Important: The nodes and identifier are only intended for link completion purposes. _Don't_ add them to the path hierarchy or try and resolve links for them.
    static func _makeNodeAndIdentifier(name: String) -> (PathHierarchy.Node, ResolvedIdentifier) {
        let node = PathHierarchy.Node(name: name)
        let id   = ResolvedIdentifier()
        
        node.identifier = id
        return (node, id)
    }
}

// MARK: Assertion

private func assertAllNodes(
    in collection: @autoclosure () -> some Sequence<PathHierarchy.Node>,
    satisfy condition: (PathHierarchy.Node) -> Bool,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
) {
    assert(
        collection().allSatisfy(condition),
        "\(message()) This wasn't true for \(collection().filter { !condition($0) }.map(\.symbol!.identifier.precise).sorted())",
        file: file,
        line: line
    )
}

private func assertAllNodes(
    in collectionsByStringKey: @autoclosure () -> [String: some Collection<PathHierarchy.Node>],
    satisfy condition: (PathHierarchy.Node) -> Bool,
    _ message: @autoclosure () -> String,
    file: StaticString = #file,
    line: UInt = #line
) {
    assert(
        collectionsByStringKey().values.allSatisfy { $0.allSatisfy(condition) },
        "\(message()) This wasn't true for \(collectionsByStringKey().filter { $0.value.contains(where: { !condition($0)}) }.map(\.key).sorted())",
        file: file,
        line: line
    )
}
