/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
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
    
    /// Initializes a path hierarchy with the all the symbols from all modules that a the given symbol graph loader provides.
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
                let node = Node(symbol: symbol)
                nodes[id] = node
                allNodes[id, default: []].append(node)
            }
            
            var topLevelCandidates = nodes
            for relationship in graph.relationships where [.memberOf, .requirementOf, .optionalRequirementOf].contains(relationship.kind) {
                guard let sourceNode = nodes[relationship.source] else {
                    continue
                }
                if let targetNode = nodes[relationship.target] {
                    if targetNode.add(symbolChild: sourceNode) {
                        nodes[relationship.source] = nil
                    }
                    topLevelCandidates.removeValue(forKey: relationship.source)
                } else if let targetNodes = allNodes[relationship.target] {
                    for targetNode in targetNodes {
                        if targetNode.add(symbolChild: sourceNode) {
                            nodes[relationship.source] = nil
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
            
            // The hierarchy doesn't contain any non-symbol nodes yet. It's OK to unwrap the `symbol` property.
            for topLevelNode in topLevelCandidates.values where topLevelNode.symbol!.pathComponents.count == 1 {
                _ = moduleNode.add(symbolChild: topLevelNode)
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
                    let component = Self.parse(pathComponent: component[...])
                    let nodeWithoutSymbol = Node(name: component.name)
                    _ = parent.add(child: nodeWithoutSymbol, kind: component.kind, hash: component.hash)
                    parent = nodeWithoutSymbol
                }
                _ = parent.add(symbolChild: node)
            }
        }
        
        allNodes.removeAll()
        
        // build the lookup list by traversing the hierarchy and adding identifiers to each node
        
        var lookup = [ResolvedIdentifier: Node]()
        func descend(_ node: Node) {
            assert(node.identifier == nil)
            if node.symbol != nil {
                node.identifier = ResolvedIdentifier()
                lookup[node.identifier] = node
            }
            for tree in node.children.values {
                for (_, subtree) in tree.storage {
                    for (_, node) in subtree {
                        descend(node)
                    }
                }
            }
        }
        
        for module in roots.values {
            descend(module)
        }
        
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
        
        assert(lookup.allSatisfy({ $0.key == $0.value.identifier}))
        
        self.modules = roots
        self.lookup = lookup
        
        assert(topLevelSymbols().allSatisfy({ lookup[$0] != nil}))
    }
    
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
        _ = parent.add(child: newNode, kind: kind, hash: nil)
        
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
    
    // MARK: Finding elements in the hierarchy
    
    /// Attempts to find an element in the path hierarchy for a given path relative to another element.
    ///
    /// - Parameters:
    ///   - rawPath: The documentation link path string.
    ///   - parent: An optional identifier for the node in the hierarchy to search relative to.
    ///   - onlyFindSymbols: Whether or not only symbol matches should be found.
    /// - Returns: Returns the unique identifier for the found match or raises an error if no match can be found.
    /// - Throws: Raises a ``PathHierarchy/Error`` if no match can be found.
    func find(path rawPath: String, parent: ResolvedIdentifier? = nil, onlyFindSymbols: Bool) throws -> ResolvedIdentifier {
        let node = try findNode(path: rawPath, parent: parent, onlyFindSymbols: onlyFindSymbols)
        if node.identifier == nil {
            throw Error.unfindableMatch
        }
        if onlyFindSymbols, node.symbol == nil {
            throw Error.nonSymbolMatchForSymbolLink
        }
        return node.identifier
    }
    
    private func findNode(path rawPath: String, parent: ResolvedIdentifier?, onlyFindSymbols: Bool) throws -> Node {
        // The search for a documentation element can be though of as 3 steps:
        // First, parse the path into structured path components.
        let (path, isAbsolute) = Self.parse(path: rawPath)
        guard !path.isEmpty else {
            throw Error.notFound(availableChildren: [])
        }
        
        // Second, find the node to start the search relative to.
        // This may consume or or more path components. See implementation for details.
        var remaining = path[...]
        var node = try findRoot(parentID: parent, remaining: &remaining, isAbsolute: isAbsolute, onlyFindSymbols: onlyFindSymbols)
        
        // Third, search for the match relative to the start node.
        if remaining.isEmpty {
            // If all path components were consumed, then the start of the search is the match.
            return node
        }
        
        // Search for the remaining components from the node
        while true {
            let (children, pathComponent) = try findChildTree(node: &node, remaining: remaining)
            
            do {
                guard let child = try children.find(pathComponent.kind, pathComponent.hash) else {
                    // The search has ended with a node that doesn't have a child matching the next path component.
                    throw Error.partialResult(
                        partialResult: node,
                        remainingSubpath: remaining.map(\.full).joined(separator: "/"),
                        availableChildren: node.children.keys.sorted(by: availableChildNameIsBefore)
                    )
                }
                node = child
                remaining = remaining.dropFirst()
                if remaining.isEmpty {
                    // If all path components are consumed, then the match is found.
                    return child
                }
            } catch DisambiguationTree.Error.lookupCollision(let collisions) {
                func wrappedCollisionError() -> Error {
                    Error.lookupCollision(partialResult: node, collisions: collisions)
                }
                
                // See if the collision can be resolved by looking ahead on level deeper.
                guard let nextPathComponent = remaining.dropFirst().first else {
                    // This was the last path component so there's nothing to look ahead.
                    //
                    // It's possible for a symbol that exist on multiple languages to collide with itself.
                    // Check if the collision can be resolved by finding a unique symbol or an otherwise preferred match.
                    var uniqueCollisions: [String: Node] = [:]
                    for (node, _) in collisions {
                        guard let symbol = node.symbol else {
                            // Non-symbol collisions should have already been resolved
                            throw wrappedCollisionError()
                        }
                        
                        let id = symbol.identifier.precise
                        if symbol.identifier.interfaceLanguage == "swift" || !uniqueCollisions.keys.contains(id) {
                            uniqueCollisions[id] = node
                        }
                        
                        guard uniqueCollisions.count < 2 else {
                            // Encountered more than one unique symbol
                            throw wrappedCollisionError()
                        }
                    }
                    // A wrapped error would have been raised while iterating over the collection.
                    return uniqueCollisions.first!.value
                }
                // Try resolving the rest of the path for each collision ...
                let possibleMatches = collisions.compactMap {
                    return try? $0.node.children[nextPathComponent.name]?.find(nextPathComponent.kind, nextPathComponent.hash)
                }
                // If only one collision matches, return that match.
                if possibleMatches.count == 1 {
                    return possibleMatches.first!
                }
                // If all matches are the same symbol, return the Swift version of that symbol
                if !possibleMatches.isEmpty, possibleMatches.dropFirst().allSatisfy({ $0.symbol?.identifier.precise == possibleMatches.first!.symbol?.identifier.precise }) {
                    return possibleMatches.first(where: { $0.symbol?.identifier.interfaceLanguage == "swift" }) ?? possibleMatches.first!
                }
                // Couldn't resolve the collision by look ahead.
                throw Error.lookupCollision(
                    partialResult: node,
                    collisions: collisions.map { ($0.node, $0.disambiguation) }
                )
            }
        }
    }
    
    /// Finds the child disambiguation tree for a given node that match the remaining path components.
    /// - Parameters:
    ///   - node: The current node.
    ///   - remaining: The remaining path components.
    /// - Returns: The child disambiguation tree and path component.
    private func findChildTree(node: inout Node, remaining: ArraySlice<PathComponent>) throws -> (DisambiguationTree, PathComponent) {
        var pathComponent = remaining.first!
        if let match = node.children[pathComponent.name] {
            return (match, pathComponent)
        } else if let match = node.children[pathComponent.full] {
            // The path component parsing may treat dash separated words as disambiguation information.
            // If the parsed name didn't match, also try the original.
            pathComponent.kind = nil
            pathComponent.hash = nil
            return (match, pathComponent)
        } else {
            if node.name == pathComponent.name || node.name == pathComponent.full, let parent = node.parent {
                // When multiple path components in a row have the same name it's possible that the search started at a node that's
                // too deep in the hierarchy that won't find the final result.
                // Check if a match would be found in the parent before raising an error.
                if let match = parent.children[pathComponent.name] {
                    node = parent
                    return (match, pathComponent)
                } else if let match = parent.children[pathComponent.full] {
                    node = parent
                    // The path component parsing may treat dash separated words as disambiguation information.
                    // If the parsed name didn't match, also try the original.
                    pathComponent.kind = nil
                    pathComponent.hash = nil
                    return (match, pathComponent)
                }
            }
        }
        // The search has ended with a node that doesn't have a child matching the next path component.
        throw Error.partialResult(
            partialResult: node,
            remainingSubpath: remaining.map(\.full).joined(separator: "/"),
            availableChildren: node.children.keys.sorted(by: availableChildNameIsBefore)
        )
    }
    
    /// Attempt to find the node to start the relative search relative to.
    ///
    /// - Parameters:
    ///   - parentID: An optional ID of the node to start the search relative to.
    ///   - remaining: The parsed path components.
    ///   - isAbsolute: If the parsed path represent an absolute documentation link.
    ///   - onlyFindSymbols: If symbol results are required.
    /// - Returns: The node to start the relative search relative to.
    private func findRoot(parentID: ResolvedIdentifier?, remaining: inout ArraySlice<PathComponent>, isAbsolute: Bool, onlyFindSymbols: Bool) throws -> Node {
        // If the first path component is "tutorials" or "documentation" then that
        let isKnownTutorialPath = remaining.first!.full == NodeURLGenerator.Path.tutorialsFolderName
        let isKnownDocumentationPath = remaining.first!.full == NodeURLGenerator.Path.documentationFolderName
        if isKnownDocumentationPath || isKnownTutorialPath {
            // Drop that component since it isn't represented in the path hierarchy.
            remaining.removeFirst()
        }
        guard let component = remaining.first else {
            throw Error.notFound(availableChildren: [])
        }
        
        if !onlyFindSymbols {
            // If non-symbol matches are possible there is a fixed order to try resolving the link:
            // Articles match before tutorials which match before the tutorial overview page which match before symbols.
            lookForArticleRoot: if !isKnownTutorialPath {
                if articlesContainer.name == component.name || articlesContainer.name == component.full {
                    if let next = remaining.dropFirst().first {
                        if !articlesContainer.children.keys.contains(next.name) && !articlesContainer.children.keys.contains(next.full) {
                            break lookForArticleRoot
                        }
                    }
                    remaining = remaining.dropFirst()
                    return articlesContainer
                } else if articlesContainer.children.keys.contains(component.name) || articlesContainer.children.keys.contains(component.full)  {
                    return articlesContainer
                }
            }
            if !isKnownDocumentationPath {
                if tutorialContainer.name == component.name || tutorialContainer.name == component.full {
                    remaining = remaining.dropFirst()
                    return tutorialContainer
                } else if tutorialContainer.children.keys.contains(component.name) || tutorialContainer.children.keys.contains(component.full)  {
                    return tutorialContainer
                }
                // The parent for tutorial overviews / technologies is "tutorials" which has already been removed above, so no need to check against that name.
                else if tutorialOverviewContainer.children.keys.contains(component.name) || tutorialOverviewContainer.children.keys.contains(component.full)  {
                    return tutorialOverviewContainer
                }
            }
            if !isKnownTutorialPath && isAbsolute {
                // If this is an absolute non-tutorial link, then the first component will be a module name.
                if let matched = modules[component.name] ?? modules[component.full] {
                    remaining = remaining.dropFirst()
                    return matched
                }
            }
        }
        
        func matches(node: Node, component: PathComponent) -> Bool {
            if let symbol = node.symbol {
                return node.name == component.name
                && (component.kind == nil || component.kind == symbol.kind.identifier.identifier)
                && (component.hash == nil || component.hash == symbol.identifier.precise.stableHashString)
            } else {
                return node.name == component.full
            }
        }
        
        if let parentID = parentID {
            // If a parent ID was provided, start at that node and continue up the hierarchy until that node has a child that matches the first path components name.
            var parentNode = lookup[parentID]!
            let firstComponent = remaining.first!
            if matches(node: parentNode, component: firstComponent) {
                remaining = remaining.dropFirst()
                return parentNode
            }
            while !parentNode.children.keys.contains(firstComponent.name) && !parentNode.children.keys.contains(firstComponent.full) {
                guard let parent = parentNode.parent else {
                    if matches(node: parentNode, component: firstComponent){
                        remaining = remaining.dropFirst()
                        return parentNode
                    }
                    if let matched = modules[component.name] ?? modules[component.full] {
                        remaining = remaining.dropFirst()
                        return matched
                    }
                    // No node up the hierarchy from the provided parent has a child that matches the first path component.
                    // Go back to the provided parent node for diagnostic information about its available children.
                    parentNode = lookup[parentID]!
                    throw Error.partialResult(partialResult: parentNode, remainingSubpath: remaining.map({ $0.full }).joined(separator: "/"), availableChildren: parentNode.children.keys.sorted(by: availableChildNameIsBefore))
                }
                parentNode = parent
            }
            return parentNode
        }
        
        // If no parent ID was provided, check if the first path component is a module name.
        if let matched = modules[component.name] ?? modules[component.full] {
            remaining = remaining.dropFirst()
            return matched
        }
        
        // No place to start the search from could be found.
        // It would be a nice future improvement to allow skipping the module and find top level symbols directly.
        let topLevelNames = Set(modules.keys + [articlesContainer.name, tutorialContainer.name]).sorted(by: availableChildNameIsBefore)
        throw Error.notFound(availableChildren: topLevelNames)
    }
}

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
        fileprivate private(set) var children: [String: DisambiguationTree]
        
        private(set) unowned var parent: Node?
        /// The symbol, if a node has one.
        private(set) var symbol: SymbolGraph.Symbol?
        
        /// Initializes a symbol node.
        fileprivate init(symbol: SymbolGraph.Symbol!) {
            self.symbol = symbol
            self.name = symbol.pathComponents.last!
            self.children = [:]
        }
        
        /// Initializes a non-symbol node with a given name.
        fileprivate init(name: String) {
            self.symbol = nil
            self.name = name
            self.children = [:]
        }
        
        /// Adds a descendant to this node, providing disambiguation information from the node's symbol.
        fileprivate func add(symbolChild: Node) -> Bool {
            precondition(symbolChild.symbol != nil)
            return add(
                child: symbolChild,
                kind: symbolChild.symbol!.kind.identifier.identifier,
                hash: symbolChild.symbol!.identifier.precise.stableHashString
            )
        }
        
        /// Adds a descendant of this node.
        fileprivate func add(child: Node, kind: String?, hash: String?) -> Bool {
            child.parent = self
            return children[child.name, default: .init()].add(kind ?? "_", hash ?? "_", child)
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
// MARK: Parsing documentation links

/// All known symbol kind identifiers.
///
/// This is used to identify parsed path components as kind information.
private let knownSymbolKinds = Set(SymbolGraph.Symbol.KindIdentifier.allCases.map { $0.identifier })
/// All known source language identifiers.
///
/// This is used to skip language prefixes from kind disambiguation information.
private let knownLanguagePrefixes = SourceLanguage.knownLanguages.flatMap { [$0.id] + $0.idAliases }.map { $0 + "." }

extension PathHierarchy {
    /// The parsed information for a documentation URI path component.
    struct PathComponent {
        /// The full original path component
        let full: String
        /// The parsed entity name
        let name: String
        /// The parsed entity kind, if any.
        var kind: String?
        /// The parsed entity hash, if any.
        var hash: String?
    }
    
    /// Parsed a documentation link path (and optional fragment) string into structured path component values.
    /// - Parameter path: The documentation link string, containing a path and an optional fragment.
    /// - Returns: A pair of the parsed path components and a flag that indicate if the documentation link is absolute or not.
    static func parse(path: String) -> (components: [PathComponent], isAbsolute: Bool) {
        guard !path.isEmpty else { return ([], true) }
        var components = path.split(separator: "/", omittingEmptySubsequences: true)
        let isAbsolute = path.first == "/"
            || String(components.first ?? "") == NodeURLGenerator.Path.documentationFolderName
            || String(components.first ?? "") == NodeURLGenerator.Path.tutorialsFolderName
       
        if let hashIndex = components.last?.firstIndex(of: "#") {
            let last = components.removeLast()
            components.append(last[..<hashIndex])
            
            let fragment = String(last[hashIndex...].dropFirst())
            return (components.map(Self.parse(pathComponent:)) + [PathComponent(full: fragment, name: fragment, kind: nil, hash: nil)], isAbsolute)
        }
        
        return (components.map(Self.parse(pathComponent:)), isAbsolute)
    }
    
    /// Parses a single path component string into a structured format.
    private static func parse(pathComponent original: Substring) -> PathComponent {
        let full = String(original)
        guard let dashIndex = original.lastIndex(of: "-") else {
            return PathComponent(full: full, name: full, kind: nil, hash: nil)
        }
        
        let hash = String(original[dashIndex...].dropFirst())
        let name = String(original[..<dashIndex])
        
        func isValidHash(_ hash: String) -> Bool {
            var index: UInt8 = 0
            for char in hash.utf8 {
                guard index <= 5, (48...57).contains(char) || (97...122).contains(char) else { return false }
                index += 1
            }
            return true
        }
        
        if knownSymbolKinds.contains(hash) {
            // The parsed hash value is a symbol kind
            return PathComponent(full: full, name: name, kind: hash, hash: nil)
        }
        if let languagePrefix = knownLanguagePrefixes.first(where: { hash.starts(with: $0) }) {
            // The hash is actually a symbol kind with a language prefix
            return PathComponent(full: full, name: name, kind: String(hash.dropFirst(languagePrefix.count)), hash: nil)
        }
        if !isValidHash(hash) {
            // The parsed hash is neither a symbol not a valid hash. It's probably a hyphen-separated name.
            return PathComponent(full: full, name: full, kind: nil, hash: nil)
        }
        
        if let dashIndex = name.lastIndex(of: "-") {
            let kind = String(name[dashIndex...].dropFirst())
            let name = String(name[..<dashIndex])
            if let languagePrefix = knownLanguagePrefixes.first(where: { kind.starts(with: $0) }) {
                return PathComponent(full: full, name: name, kind: String(kind.dropFirst(languagePrefix.count)), hash: hash)
            } else {
                return PathComponent(full: full, name: name, kind: kind, hash: hash)
            }
        }
        return PathComponent(full: full, name: name, kind: nil, hash: hash)
    }
}

// MARK: Determining disambiguated paths

private let nonAllowedPathCharacters = CharacterSet.urlPathAllowed.inverted

private func symbolFileName(_ symbolName: String) -> String {
    return symbolName.components(separatedBy: nonAllowedPathCharacters).joined(separator: "_")
}

extension PathHierarchy {
    /// Determines the least disambiguated paths for all symbols in the path hierarchy.
    ///
    /// - Parameters:
    ///   - includeDisambiguationForUnambiguousChildren: Whether or not descendants unique to a single collision should maintain the containers disambiguation.
    ///   - includeLanguage: Whether or not kind disambiguation information should include the source language.
    /// - Returns: A map of unique identifier strings to disambiguated file paths
    func caseInsensitiveDisambiguatedPaths(
        includeDisambiguationForUnambiguousChildren: Bool = false,
        includeLanguage: Bool = false
    ) -> [String: String] {
        func descend(_ node: Node, accumulatedPath: String) -> [(String, (String, Bool))] {
            var results: [(String, (String, Bool))] = []
            let caseInsensitiveChildren = [String: DisambiguationTree](node.children.map { (symbolFileName($0.key.lowercased()), $0.value) }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in caseInsensitiveChildren {
                let disambiguatedChildren = tree.disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: includeLanguage)
                let uniqueNodesWithChildren = Set(disambiguatedChildren.filter { $0.disambiguation.value() != nil && !$0.value.children.isEmpty }.map { $0.value.symbol?.identifier.precise })
                for (node, disambiguation) in disambiguatedChildren {
                    var path: String
                    if node.identifier == nil && disambiguatedChildren.count == 1 {
                        // When descending through placeholder nodes, we trust that the known disambiguation
                        // that they were created with is necessary.
                        var knownDisambiguation = ""
                        let (kind, subtree) = tree.storage.first!
                        if kind != "_" {
                            knownDisambiguation += "-\(kind)"
                        }
                        let hash = subtree.keys.first!
                        if hash != "_" {
                            knownDisambiguation += "-\(hash)"
                        }
                        path = accumulatedPath + "/" + symbolFileName(node.name) + knownDisambiguation
                    } else {
                        path = accumulatedPath + "/" + symbolFileName(node.name)
                    }
                    if let symbol = node.symbol {
                        results.append(
                            (symbol.identifier.precise, (path + disambiguation.makeSuffix(), symbol.identifier.interfaceLanguage == "swift"))
                        )
                    }
                    if includeDisambiguationForUnambiguousChildren || uniqueNodesWithChildren.count > 1 {
                        path += disambiguation.makeSuffix()
                    }
                    results += descend(node, accumulatedPath: path)
                }
            }
            return results
        }
        
        var gathered: [(String, (String, Bool))] = []
        
        for (moduleName, node) in modules {
            let path = "/" + moduleName
            gathered.append(
                (moduleName, (path, node.symbol == nil || node.symbol!.identifier.interfaceLanguage == "swift"))
            )
            gathered += descend(node, accumulatedPath: path)
        }
        
        // If a symbol node exist in multiple languages, prioritize the Swift variant.
        let result = [String: (String, Bool)](gathered, uniquingKeysWith: { lhs, rhs in lhs.1 ? lhs : rhs }).mapValues({ $0.0 })
        
        assert(
            Set(result.values).count == result.keys.count,
            {
                let collisionDescriptions = result
                    .reduce(into: [String: [String]](), { $0[$1.value, default: []].append($1.key) })
                    .filter({ $0.value.count > 1 })
                    .map { "\($0.key)\n\($0.value.map({ "  " + $0 }).joined(separator: "\n"))" }
                return """
                Disambiguated paths contain \(collisionDescriptions.count) collision(s):
                \(collisionDescriptions.joined(separator: "\n"))
                """
            }()
        )
        
        return result
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

// MARK: Error messages

extension PathHierarchy {
    /// An error finding an entry in the path hierarchy.
    enum Error: Swift.Error {
        /// No element was found at the beginning of the path.
        ///
        /// Includes information about:
        /// - A list of the names for the top level elements.
        case notFound(availableChildren: [String])
        
        /// Matched node does not correspond to a documentation page.
        ///
        /// For partial symbol graph files, sometimes sparse nodes that don't correspond to known documentation need to be created to form a hierarchy. These nodes are not findable.
        case unfindableMatch
        
        /// A symbol link found a non-symbol match.
        case nonSymbolMatchForSymbolLink
        
        /// No child element is found partway through the path.
        ///
        /// Includes information about:
        /// - The partial result for as much of the path that could be found.
        /// - The remaining portion of the path.
        /// - A list of the names for the children of the partial result.
        case partialResult(partialResult: Node, remainingSubpath: String, availableChildren: [String])
        
        /// Multiple matches are found partway through the path.
        ///
        /// Includes information about:
        /// - The partial result for as much of the path that could be found unambiguously.
        /// - A list of possible matches paired with the disambiguation suffixes needed to distinguish them.
        case lookupCollision(partialResult: Node, collisions: [(node: Node, disambiguation: String)])
    }
}
    
/// A comparison/sort function for the list of names for the children of the partial result in a diagnostic.
private func availableChildNameIsBefore(_ lhs: String, _ rhs: String) -> Bool {
    return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
}

extension PathHierarchy.Error {
    /// Formats the error into an error message suitable for presentation
    func errorMessage(context: DocumentationContext) -> String {
        switch self {
        case .partialResult(let partialResult, let remaining, let available):
            return "Reference at \(partialResult.pathWithoutDisambiguation().singleQuoted) can't resolve \(remaining.singleQuoted). Available children: \(available.joined(separator: ", "))."
            
        case .notFound, .unfindableMatch:
            return "No local documentation matches this reference."
            
        case .nonSymbolMatchForSymbolLink:
            return "Symbol links can only resolve symbols."
            
        case .lookupCollision(let partialResult, let collisions):
            let collisionDescription = collisions.map { "Append '-\($0.disambiguation)' to refer to \($0.node.fullNameOfValue(context: context).singleQuoted)" }.sorted()
            return "Reference is ambiguous after \(partialResult.pathWithoutDisambiguation().singleQuoted): \(collisionDescription.joined(separator: ". "))."
        }
    }
}

private extension PathHierarchy.Node {
    /// Creates a path string without any disambiguation.
    ///
    /// > Note: This value is only intended for error messages and other presentation.
    func pathWithoutDisambiguation() -> String {
        var components = [name]
        var node = self
        while let parent = node.parent {
            components.insert(parent.name, at: 0)
            node = parent
        }
        return "/" + components.joined(separator: "/")
    }
    
    /// Determines the full name of a node's value using information from the documentation context.
    ///
    /// > Note: This value is only intended for error messages and other presentation.
    func fullNameOfValue(context: DocumentationContext) -> String {
        guard let identifier = identifier else { return name }
        if let symbol = symbol {
            if let fragments = symbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self]?.declarationFragments {
                return fragments.map(\.spelling).joined().split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
            }
            return context.symbolIndex[symbol.identifier.precise]!.name.description
        }
        // This only gets called for PathHierarchy error messages, so hierarchyBasedLinkResolver is never nil.
        let reference = context.hierarchyBasedLinkResolver!.resolvedReferenceMap[identifier]!
        if reference.fragment != nil {
            return context.nodeAnchorSections[reference]!.title
        } else {
            return context.documentationCache[reference]!.name.description
        }
    }
}

// MARK: Dump

/// A node in a tree structure that can be printed into a visual representation for debugging.
private struct DumpableNode {
    var name: String
    var children: [DumpableNode]
}

private extension PathHierarchy.Node {
    /// Maps the path hierarchy subtree into a representation that can be printed into a visual form for debugging.
    func dumpableNode() -> DumpableNode {
        // Each node is printed as 3-layer hierarchy with the child names, their kind disambiguation, and their hash disambiguation.
        return DumpableNode(
            name: symbol.map { "{ \($0.identifier.precise) : \($0.identifier.interfaceLanguage).\($0.kind.identifier.identifier) }" } ?? "[ \(name) ]",
            children: children.sorted(by: \.key).map { (key, disambiguationTree) -> DumpableNode in
                DumpableNode(
                    name: key,
                    children: disambiguationTree.storage.sorted(by: \.key).map { (kind, kindTree) -> DumpableNode in
                        DumpableNode(
                            name: kind,
                            children: kindTree.sorted(by: \.key).map { (usr, node) -> DumpableNode in
                                DumpableNode(
                                    name: usr,
                                    children: [node.dumpableNode()]
                                )
                            }
                        )
                    }
                )
            }
        )
    }
}

extension PathHierarchy {
    /// Creates a visual representation or the path hierarchy for debugging.
    func dump() -> String {
        var children = modules.sorted(by: \.key).map { $0.value.dumpableNode() }
        if articlesContainer.symbol == nil {
            children.append(articlesContainer.dumpableNode()) // The article parent can be the same node as the module
        }
        children.append(contentsOf: [tutorialContainer.dumpableNode(), tutorialOverviewContainer.dumpableNode()])
        
        let root = DumpableNode(name: ".", children: children)
        return Self.dump(root)
    }
    
    fileprivate static func dump(_ node: DumpableNode, decorator: String = "") -> String {
        var result = ""
        result.append("\(decorator) \(node.name)\n")
        
        let children = node.children
        for (index, child) in children.enumerated() {
            var decorator = decorator
            if decorator.hasSuffix("├") {
                decorator = decorator.dropLast() + "│"
            }
            if decorator.hasSuffix("╰") {
                decorator = decorator.dropLast() + " "
            }
            let newDecorator = decorator + " " + (index == children.count-1 ? "╰" : "├")
            result.append(dump(child, decorator: newDecorator))
        }
        return result
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

// MARK: Disambiguation tree

/// A fixed-depth tree that stores disambiguation information and finds values based on partial disambiguation.
private struct DisambiguationTree {
    // Each disambiguation tree is fixed at two levels and stores a limited number of values.
    // In practice, almost all trees store either 1, 2, or 3 elements with 1 being the most common.
    // It's very rare to have more than 10 values and 20+ values is extremely rare.
    //
    // Given this expected amount of data, a nested dictionary implementation performs well.
    private(set) var storage: [String: [String: PathHierarchy.Node]] = [:]
    
    /// Add a new value to the tree for a given pair of kind and hash disambiguations.
    /// - Parameters:
    ///   - kind: The kind disambiguation for this value.
    ///   - hash: The hash disambiguation for this value.
    ///   - value: The new value
    /// - Returns: If a value already exist with the same pair of kind and hash disambiguations.
    @discardableResult
    mutating func add(_ kind: String, _ hash: String, _ value: PathHierarchy.Node) -> Bool {
        if let existing = storage[kind]?[hash] {
            existing.merge(with: value)
            return true
        } else if storage.count == 1, let existing = storage["_"]?["_"] {
            // It is possible for articles and other non-symbols to collide with unfindable symbol placeholder nodes.
            // When this happens, remove the placeholder node and move its children to the real (non-symbol) node.
            value.merge(with: existing)
            storage = [kind: [hash: value]]
            return true
        } else {
            storage[kind, default: [:]][hash] = value
            return false
        }
    }
    
    /// Combines the data from this tree with another tree to form a new, merged disambiguation tree.
    func merge(with other: DisambiguationTree) -> DisambiguationTree {
        return DisambiguationTree(storage: self.storage.merging(other.storage, uniquingKeysWith: { lhs, rhs in
            lhs.merging(rhs, uniquingKeysWith: {
                lhsValue, rhsValue in
                assert(lhsValue.symbol!.identifier.precise == rhsValue.symbol!.identifier.precise)
                return lhsValue
            })
        }))
    }
    
    /// Errors finding values in the disambiguation tree
    enum Error: Swift.Error {
        /// Multiple matches found.
        ///
        /// Includes a list of values paired with their missing disambiguation suffixes.
        case lookupCollision([(node: PathHierarchy.Node, disambiguation: String)])
    }
    
    /// Attempts to find a value in the disambiguation tree based on partial disambiguation information.
    ///
    /// There are 3 possible results:
    ///  - No match is found; indicated by a `nil` return value.
    ///  - Exactly one match is found; indicated by a non-nil return value.
    ///  - More than one match is found; indicated by a raised error listing the matches and their missing disambiguation.
    func find(_ kind: String?, _ hash: String?) throws -> PathHierarchy.Node? {
        if let kind = kind {
            // Need to match the provided kind
            guard let subtree = storage[kind] else { return nil }
            if let hash = hash {
                return subtree[hash]
            } else if subtree.count == 1 {
                return subtree.values.first
            } else {
                // Subtree contains more than one match.
                throw Error.lookupCollision(subtree.map { ($0.value, $0.key) })
            }
        } else if storage.count == 1, let subtree = storage.values.first {
            // Tree only contains one kind subtree
            if let hash = hash {
                return subtree[hash]
            } else if subtree.count == 1 {
                return subtree.values.first
            } else {
                // Subtree contains more than one match.
                throw Error.lookupCollision(subtree.map { ($0.value, $0.key) })
            }
        } else if let hash = hash {
            // Need to match the provided hash
            let kinds = storage.filter { $0.value.keys.contains(hash) }
            if kinds.isEmpty {
                return nil
            } else if kinds.count == 1 {
                return kinds.first!.value[hash]
            } else {
                // Subtree contains more than one match
                throw Error.lookupCollision(kinds.map { ($0.value[hash]!, $0.key) })
            }
        }
        // Disambiguate by a mix of kinds and USRs
        throw Error.lookupCollision(self.disambiguatedValues().map { ($0.value, $0.disambiguation.value()) })
    }
    
    /// Returns all values paired with their disambiguation suffixes.
    ///
    /// - Parameter includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    func disambiguatedValues(includeLanguage: Bool = false) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        if storage.count == 1 {
            let tree = storage.values.first!
            if tree.count == 1 {
                return [(tree.values.first!, .none)]
            }
        }
        
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        for (kind, kindTree) in storage {
            if kindTree.count == 1 {
                // No other match has this kind
                if includeLanguage, let symbol = kindTree.first!.value.symbol {
                    collisions.append((value: kindTree.first!.value, disambiguation: .kind("\(SourceLanguage(id: symbol.identifier.interfaceLanguage).linkDisambiguationID).\(kind)")))
                } else {
                    collisions.append((value: kindTree.first!.value, disambiguation: .kind(kind)))
                }
                continue
            }
            for (usr, value) in kindTree {
                collisions.append((value: value, disambiguation: .hash(usr)))
            }
        }
        return collisions
    }
    
    /// Returns all values paired with their disambiguation suffixes without needing to disambiguate between two different versions of the same symbol.
    ///
    /// - Parameter includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    func disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: Bool) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        typealias DisambiguationPair = (String, String)
        
        var uniqueSymbolIDs = [String: [DisambiguationPair]]()
        var nonSymbols = [DisambiguationPair]()
        for (kind, kindTree) in storage {
            for (hash, value) in kindTree {
                guard let symbol = value.symbol else {
                    nonSymbols.append((kind, hash))
                    continue
                }
                if symbol.identifier.interfaceLanguage == "swift" {
                    uniqueSymbolIDs[symbol.identifier.precise, default: []].insert((kind, hash), at: 0)
                } else {
                    uniqueSymbolIDs[symbol.identifier.precise, default: []].append((kind, hash))
                }
            }
        }
        
        var duplicateSymbols = [String: ArraySlice<DisambiguationPair>]()
        
        var new = DisambiguationTree()
        for (kind, hash) in nonSymbols {
            new.add(kind, hash, storage[kind]![hash]!)
        }
        for (id, symbolDisambiguations) in uniqueSymbolIDs {
            let (kind, hash) = symbolDisambiguations[0]
            new.add(kind, hash, storage[kind]![hash]!)
            
            if symbolDisambiguations.count > 1 {
                duplicateSymbols[id] = symbolDisambiguations.dropFirst()
            }
        }
     
        var disambiguated = new.disambiguatedValues(includeLanguage: includeLanguage)
        guard !duplicateSymbols.isEmpty else {
            return disambiguated
        }
        
        for (id, disambiguations) in duplicateSymbols {
            let primaryDisambiguation = disambiguated.first(where: { $0.value.symbol?.identifier.precise == id })!.disambiguation
            for (kind, hash) in disambiguations {
                disambiguated.append((storage[kind]![hash]!, primaryDisambiguation.updated(kind: kind, hash: hash)))
            }
        }
        
        return disambiguated
    }
    
    /// The computed disambiguation for a given path hierarchy node.
    enum Disambiguation {
        /// No disambiguation is needed.
        case none
        /// This node is disambiguated by its kind.
        case kind(String)
        /// This node is disambiguated by its hash.
        case hash(String)
       
        /// Returns the kind or hash value that disambiguates this node.
        func value() -> String! {
            switch self {
            case .none:
                return nil
            case .kind(let value), .hash(let value):
                return value
            }
        }
        /// Makes a new disambiguation suffix string.
        func makeSuffix() -> String {
            switch self {
            case .none:
                return ""
            case .kind(let value), .hash(let value):
                return "-"+value
            }
        }
        
        /// Creates a new disambiguation with a new kind or hash value.
        func updated(kind: String, hash: String) -> Self {
            switch self {
            case .none:
                return .none
            case .kind:
                return .kind(kind)
            case .hash:
                return .hash(hash)
            }
        }
    }
}
