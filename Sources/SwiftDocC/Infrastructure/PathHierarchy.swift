/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

private let knownSymbolKinds = SymbolGraph.Symbol.KindIdentifier.allCases.map { $0.identifier }
private let knownLanguagePrefixes = SourceLanguage.knownLanguages.flatMap { [$0.id] + $0.idAliases }.map { $0 + "." }

struct ResolvedIdentifier: Equatable, Hashable {
    private let storage = UUID()
}

// !!!: This file is a draft implementation of a symbol path disambiguation tree.
// It's functionally correct (see tests) but I want to integrate it, to see how the API needs to be adjusted, before cleaning it up, documenting it, and optimizing it.

// TODO: Clean up the draft implementation (inline TODOs and more)
// TODO: Optimize performance (inline TODOs and more)
// TODO: Document (both API and some important implementation aspects)

struct PathHierarchy {
    
    init(symbolGraphLoader loader: SymbolGraphLoader, bundleName: String, knownDisambiguatedPathComponents: [String: [String]]? = nil) {
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
                let moduleSymbol = SymbolGraph.Symbol(
                    identifier: .init(precise: moduleName, interfaceLanguage: SourceLanguage.swift.id), // TODO: Customizable module language
                    names: SymbolGraph.Symbol.Names(title: moduleName, navigator: nil, subHeading: nil, prose: nil),
                    pathComponents: [moduleName],
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: .module, displayName: "Framework"), // TODO: Customizable module display name
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
                topLevelCandidates.removeValue(forKey: relationship.source)
                if let targetNode = nodes[relationship.target] {
                    if targetNode.add(child: sourceNode) {
                        nodes[relationship.source] = nil
                    }
                } else if let targetNodes = allNodes[relationship.target] {
                    for targetNode in targetNodes {
                        if targetNode.add(child: sourceNode) {
                            nodes[relationship.source] = nil
                        }
                    }
                } else {
                    // Symbols that are not added to the path hierarchy based on relationships will be added to the path hierarchy based on the symbol's path components.
                    // Using relationships over path components is preferred because it provides information needed to disambiguate path collisions.
                    //
                    // In full symbol graphs this is expected to be rare. In partial symbol graphs from the ConvertService it is expected that parent symbols and relationships
                    // will be missing. The ConvertService is expected to provide the necessary `knownDisambiguatedPathComponents` to disambiguate any collisions.
                    continue
                }
            }
            for relationship in graph.relationships where [.defaultImplementationOf].contains(relationship.kind) {
                guard let sourceNode = nodes[relationship.source], sourceNode.parent == nil else {
                    continue
                }
                topLevelCandidates.removeValue(forKey: relationship.source)
                guard let targetParent = nodes[relationship.target]?.parent else {
                    continue
                }
                if targetParent.add(child: sourceNode) {
                    nodes[relationship.source] = nil
                }
            }
            
            for topLevelNode in topLevelCandidates.values where topLevelNode.symbol.pathComponents.count == 1 {
                _ = moduleNode.add(child: topLevelNode)
            }
            
            for node in topLevelCandidates.values where node.symbol.pathComponents.count > 1 {
                var parent = moduleNode
                var components = { (symbol: SymbolGraph.Symbol) -> [String] in
                    let original = symbol.pathComponents
                    if let disambiguated = knownDisambiguatedPathComponents?[node.symbol.identifier.precise], disambiguated.count == original.count {
                        return disambiguated
                    } else {
                        return original
                    }
                }(node.symbol)[...].dropLast()
                while !components.isEmpty, let child = try? parent.children[components.first!]?.find(nil, nil) {
                    parent = child
                    components = components.dropFirst()
                }
                for component in components {
                    let component = Self.parse(pathComponent: component[...])
                    let nodeWithoutSymbol = Node(name: component.name)
                    _ = parent.add(child: nodeWithoutSymbol, kind: component.kind ?? "<missing>", hash: component.hash ?? "<missing>")
                    parent = nodeWithoutSymbol
                }
                _ = parent.add(child: node)
            }
        }
        
        allNodes.removeAll()
        
        // build the lookup list
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
        self.articlesParent = roots[bundleName] ?? newNode(bundleName)
        self.tutorialParent = newNode(bundleName)
        self.tutorialOverviewParent = newNode("tutorials")
        
        assert(lookup.allSatisfy({ $0.key == $0.value.identifier}))
        
        self.roots = roots
        self.lookup = lookup
        
        assert(topLevelSymbols().allSatisfy({ lookup[$0] != nil}))
    }
    
    private(set) var roots: [String: Node]
    let articlesParent: Node
    let tutorialParent: Node
    let tutorialOverviewParent: Node
    
    private(set) var lookup: [ResolvedIdentifier: Node]
    
    mutating func addArticle(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: articlesParent.identifier, name: name, type: "article")
    }
    
    mutating func addTutorial(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: tutorialParent.identifier, name: name, type: "tutorial")
    }
    
    mutating func addTechnology(name: String) -> ResolvedIdentifier {
        return addNonSymbolChild(parent: tutorialOverviewParent.identifier, name: name, type: "technology")
    }
    
    mutating func addNonSymbolChild(parent: ResolvedIdentifier, name: String, type: String) -> ResolvedIdentifier {
        let parent = lookup[parent]!
        
        let newReference = ResolvedIdentifier()
        let newNode = Node(name: name)
        newNode.identifier = newReference
        self.lookup[newReference] = newNode
        _ = parent.add(child: newNode, kind: type, hash: "<missing>")
        
        return newReference
    }
    
    mutating func addTopLevelNonSymbol(name: String, type: String) -> ResolvedIdentifier {
        let newReference = ResolvedIdentifier()
        let newNode = Node(name: name)
        newNode.identifier = newReference
        self.lookup[newReference] = newNode

        roots[name] = newNode
        
        return newReference
    }
    
    func caseInsensitiveDisambiguatedPaths() -> [String: String] {
        func descend(_ node: Node, accumulatedPath: String) -> [(String, (String, Bool))] {
            var results: [(String, (String, Bool))] = []
            let caseInsensitiveChildren = [String: DisambiguationTree](node.children.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in caseInsensitiveChildren {
                let disambiguatedChildren = tree.disambiguatedValues()
                let uniqueNodesWithChildren = Set(disambiguatedChildren.filter { !$0.disambiguation.isEmpty && !$0.value.children.isEmpty }.map { $0.value.symbol.identifier.precise })
                for (node, disambiguation) in disambiguatedChildren {
                    var path: String
                    if node.symbol == nil && disambiguatedChildren.count == 1 {
                        var knownDisambiguation = ""
                        let (kind, subtree) = tree.storage.first!
                        if kind != "<missing>" {
                            knownDisambiguation += "-\(kind)"
                        }
                        let hash = subtree.keys.first!
                        if hash != "<missing>" {
                            knownDisambiguation += "-\(hash)"
                        }
                        path = accumulatedPath + "/" + node.name + knownDisambiguation
                    } else {
                        path = accumulatedPath + "/" + node.name
                    }
                    if let symbol = node.symbol {
                        results.append(
                            (symbol.identifier.precise, (path + disambiguation, symbol.identifier.interfaceLanguage == "swift"))
                        )
                    }
                    if uniqueNodesWithChildren.count > 1 {
                        path += disambiguation
                    }
                    results += descend(node, accumulatedPath: path)
                }
            }
            return results
        }
        
        var gathered: [(String, (String, Bool))] = []
        
        for (moduleName, node) in roots {
            let path = "/" + moduleName
            gathered.append(
                (moduleName, (path, node.symbol == nil || node.symbol.identifier.interfaceLanguage == "swift"))
            )
            gathered += descend(node, accumulatedPath: path)
        }
        
        return [String: (String, Bool)](gathered, uniquingKeysWith: { lhs, rhs in lhs.1 ? lhs : rhs }).mapValues({ $0.0 })
    }
    
    final class Node {
        fileprivate private(set) var children: [String: DisambiguationTree]
        
        private(set) unowned var parent: Node?
        private(set) var name: String
        private(set) var symbol: SymbolGraph.Symbol!
        fileprivate(set) var identifier: ResolvedIdentifier!
        
        fileprivate init(symbol: SymbolGraph.Symbol!) {
            self.symbol = symbol
            self.name = symbol.pathComponents.last!
            self.children = [:]
        }
        
        fileprivate init(name: String) {
            self.symbol = nil
            self.name = name
            self.children = [:]
        }
        
        fileprivate func add(child: Node) -> Bool {
            return add(
                child: child,
                kind: child.symbol.kind.identifier.identifier,
                hash: child.symbol.identifier.precise.stableHashString
            )
        }
        
        fileprivate func add(child: Node, kind: String, hash: String) -> Bool {
            child.parent = self
            return children[child.name, default: .init()].add(kind, hash, child)
        }
        
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
    
    enum Error: Swift.Error {
        case notFound(availableChildren: [String])
        case partialResult(partialResult: Node, remainingSubpath: String, availableChildren: [String])
        case lookupCollision(partialResult: Node, collisions: [(node: Node, disambiguation: String)])
    }
    
    private func findRoot(parentID: ResolvedIdentifier?, remaining: inout ArraySlice<PathComponent>, isAbsolute: Bool, prioritizeSymbols: Bool) throws -> Node {
        let isKnownTutorialPath = remaining.first!.full == "tutorials"
        let isKnownDocumentationPath = remaining.first!.full == "documentation"
        if isKnownDocumentationPath || isKnownTutorialPath {
            remaining.removeFirst()
        }
        guard let component = remaining.first else {
            throw Error.notFound(availableChildren: [])
        }
        
        if !prioritizeSymbols {
            lookForArticleRoot: if !isKnownTutorialPath {
                if articlesParent.name == component.name || articlesParent.name == component.full {
                    if let next = remaining.dropFirst().first {
                        if !articlesParent.children.keys.contains(next.name) && !articlesParent.children.keys.contains(next.full) {
                            break lookForArticleRoot
                        }
                    }
                    remaining = remaining.dropFirst()
                    return articlesParent
                } else if articlesParent.children.keys.contains(component.name) || articlesParent.children.keys.contains(component.full)  {
                    return articlesParent
                }
            }
            if !isKnownDocumentationPath {
                if tutorialParent.name == component.name || tutorialParent.name == component.full {
                    remaining = remaining.dropFirst()
                    return tutorialParent
                } else if tutorialParent.children.keys.contains(component.name) || tutorialParent.children.keys.contains(component.full)  {
                    return tutorialParent
                }
                // The parent for tutorial overviews / technologies is "tutorials" which has already been removed above, so no need to check against that name.
                else if tutorialOverviewParent.children.keys.contains(component.name) || tutorialOverviewParent.children.keys.contains(component.full)  {
                    return tutorialOverviewParent
                }
            }
            if !isKnownTutorialPath && isAbsolute {
                if let matched = roots[component.name] ?? roots[component.full] {
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
                    if let matched = roots[component.name] ?? roots[component.full] {
                        remaining = remaining.dropFirst()
                        return matched
                    }
                    throw Error.notFound(availableChildren: parentNode.children.keys.sorted())
                }
                parentNode = parent
            }
            return parentNode
        }
        
        if let matched = roots[component.name] ?? roots[component.full] {
            remaining = remaining.dropFirst()
            return matched
        }
        
        // ???: Allow relative symbol links to skip the module?
        let topLevelNames = Set(roots.keys + [articlesParent.name, tutorialParent.name]).sorted()
        throw Error.notFound(availableChildren: topLevelNames)
    }
    
    func find(path rawPath: String, parent: ResolvedIdentifier? = nil, prioritizeSymbols: Bool) throws -> ResolvedIdentifier {
        let node = try findNode(path: rawPath, parent: parent, prioritizeSymbols: prioritizeSymbols)
        if node.identifier == nil {
            throw Error.notFound(availableChildren: []) // TODO: Dedicated error for finding a node without a value
        }
        if prioritizeSymbols, node.symbol == nil {
            throw Error.notFound(availableChildren: []) // TODO: Dedicated error for finding a non-symbol from a symbol link
        }
        return node.identifier
    }
    
    private func findNode(path rawPath: String, parent: ResolvedIdentifier?, prioritizeSymbols: Bool) throws -> Node {
        let (path, isAbsolute) = Self.parse(path: rawPath)
        guard !path.isEmpty else {
            throw Error.notFound(availableChildren: [])
        }
        
        var remaining = path[...]
        var node = try findRoot(parentID: parent, remaining: &remaining, isAbsolute: isAbsolute, prioritizeSymbols: prioritizeSymbols)
        if remaining.isEmpty {
            return node
        }
        // Search for the remaining components from the node
        while true {
            var pathComponent = remaining.first!
            let children: DisambiguationTree
            if let match = node.children[pathComponent.name] {
                children = match
            } else if let match = node.children[pathComponent.full] {
                children = match
                pathComponent.kind = nil
                pathComponent.hash = nil
            } else {
                throw Error.partialResult(
                    partialResult: node,
                    remainingSubpath: remaining.map(\.full).joined(separator: "/"),
                    availableChildren: node.children.keys.sorted()
                )
            }
            
            do {
                guard let child = try children.find(pathComponent.kind, pathComponent.hash) else {
                    throw Error.partialResult(
                        partialResult: node,
                        remainingSubpath: remaining.map(\.full).joined(separator: "/"),
                        availableChildren: node.children.keys.sorted()
                    )
                }
                node = child
                remaining = remaining.dropFirst()
                if remaining.isEmpty {
                    return child
                }
            } catch DisambiguationTree.Error.lookupCollision(let collisions) {
                guard let nextPathComponent = remaining.dropFirst().first else {
                    // Wrap the original collision
                    throw Error.lookupCollision(
                        partialResult: node,
                        collisions: collisions.map { ($0.node, $0.disambiguation) }
                    )
                }
                // Check if the collision can be disambiguated by the children
                let possibleMatches = collisions.compactMap {
                    return try? $0.node.children[nextPathComponent.name]?.find(nextPathComponent.kind, nextPathComponent.hash)
                }
                if possibleMatches.count == 1 {
                    return possibleMatches.first!
                }
                // If all matches are the same symbol, return the Swift version of that symbol
                if possibleMatches.dropFirst().allSatisfy({ $0.symbol.identifier.precise == possibleMatches.first!.symbol.identifier.precise }) {
                    return possibleMatches.first(where: { $0.symbol.identifier.interfaceLanguage == "swift" }) ?? possibleMatches.first!
                }
                // Wrap the original collision
                throw Error.lookupCollision(
                    partialResult: node,
                    collisions: collisions.map { ($0.node, $0.disambiguation) }
                )
            }
        }
    }
    
    struct PathComponent {
        let full: String
        let name: String
        var kind: String?
        var hash: String?
    }
    
    static func parse(path: String) -> ([PathComponent], Bool) {
        guard !path.isEmpty else { return ([], true) }
        var components = path.split(separator: "/", omittingEmptySubsequences: true)
        let isAbsolute = path.first == "/" || components.first == "documentation" || components.first == "tutorials"
       
        if let hashIndex = components.last?.firstIndex(of: "#") {
            let last = components.removeLast()
            components.append(last[..<hashIndex])
            
            let fragment = String(last[hashIndex...].dropFirst())
            return (components.map(Self.parse(pathComponent:)) + [PathComponent(full: fragment, name: fragment, kind: nil, hash: nil)], isAbsolute)
        }
        
        return (components.map(Self.parse(pathComponent:)), isAbsolute)
    }
    
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
            // The hash is actually a symbol kind
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

// MARK: Bridging

// TODO: Remove the need for bridging like this.

extension PathHierarchy {
    static func path(for unresolved: UnresolvedTopicReference) -> String {
        guard let fragment = unresolved.fragment else {
            return unresolved.path
        }
        return "\(unresolved.path)#\(urlReadableFragment(fragment))"
    }
    
    // TODO: This is only needed for the parent <-> child relationships
    func traversePreOrder(_ observe: (Node) -> Void) {
        for node in lookup.values {
            guard node !== articlesParent, node !== tutorialParent, node !== tutorialOverviewParent else { continue }
            observe(node)
        }
    }
    
    func topLevelSymbols() -> [ResolvedIdentifier] {
        var result: Set<ResolvedIdentifier> = []
        for root in roots.values {
            for (_, tree) in root.children {
                for subtree in tree.storage.values {
                    result.formUnion(subtree.values.filter({ $0.symbol != nil }).map(\.identifier))
                }
            }
        }
        return Array(result)
    }
}

// MARK: Error messages

extension PathHierarchy.Error {
    func errorMessage(context: DocumentationContext) -> String {
        switch self {
        case .partialResult(let partialResult, let remaining, let available):
            return "Reference at \(partialResult.pathWithoutDisambiguation().singleQuoted) can't resolve \(remaining.singleQuoted). Available children: \(available.joined(separator: ", "))."
            
        case .notFound:
            return "No local documentation matches this reference."
            
        case .lookupCollision(let partialResult, let collisions):
            let collisionDescription = collisions.map { "Add \($0.disambiguation.singleQuoted) to refer to \($0.node.fullNameOfValue(context: context).singleQuoted)"}.sorted()
            return "Reference is ambiguous after \(partialResult.pathWithoutDisambiguation().singleQuoted): \(collisionDescription.joined(separator: ". "))."
        }
    }
}

private extension PathHierarchy.Node {
    func pathWithoutDisambiguation() -> String {
        var components = [name]
        var node = self
        while let parent = node.parent {
            components.insert(parent.name, at: 0)
            node = parent
        }
        return "/" + components.joined(separator: "/")
    }
    
    func fullNameOfValue(context: DocumentationContext) -> String {
        guard let identifier = identifier else { return name }
        if let symbol = symbol {
            return context.symbolIndex[symbol.identifier.precise]!.name.description
        }
        let reference = context.resolvedReferenceMap[identifier]!
        if reference.fragment != nil {
            return context.nodeAnchorSections[reference]!.title
        } else {
            return context.documentationCache[reference]!.name.description
        }
    }
}

// MARK: Dump

private struct DumpableNode {
    var name: String
    var children: [DumpableNode]
}

private extension PathHierarchy.Node {
    func dumpableNode() -> DumpableNode {
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
    func dump() -> String {
        var children = roots.sorted(by: \.key).map { $0.value.dumpableNode() }
        if articlesParent.symbol == nil {
            children.append(articlesParent.dumpableNode()) // The article parent can be the same node as the module
        }
        children.append(contentsOf: [tutorialParent.dumpableNode(), tutorialOverviewParent.dumpableNode()])
        
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

// MARK: Disambiguation tree

private struct DisambiguationTree {
    // TODO: I have some ideas for how to optimize this. The tree is known to be small and be fixed depth.
    var storage: [String: [String: PathHierarchy.Node]] = [:]
    
    @discardableResult
    mutating func add(_ kind: String, _ usr: String, _ value: PathHierarchy.Node) -> Bool {
        if let existing = storage[kind]?[usr] {
            existing.merge(with: value)
            return true
        } else {
            storage[kind, default: [:]][usr] = value
            return false
        }
    }
    
    func merge(with other: DisambiguationTree) -> DisambiguationTree {
        return DisambiguationTree(storage: self.storage.merging(other.storage, uniquingKeysWith: { lhs, rhs in
            lhs.merging(rhs, uniquingKeysWith: {
                lhsValue, rhsValue in
                assert(lhsValue.symbol.identifier.precise == rhsValue.symbol.identifier.precise)
                return lhsValue
            })
        }))
    }
    
    enum Error: Swift.Error {
        case lookupCollision([(node: PathHierarchy.Node, disambiguation: String)])
    }
    
    func find(_ kind: String?, _ usr: String?) throws -> PathHierarchy.Node? {
        if let kind = kind {
            guard let first = storage[kind] else { return nil }
            if let usr = usr {
                return first[usr]
            } else if first.count == 1 {
                return first.values.first
            } else {
                // Disambiguate by their USR
                throw Error.lookupCollision(first.map { ($0.value, $0.key) })
            }
        } else if storage.count == 1, let first = storage.values.first {
            if let usr = usr {
                return first[usr]
            } else if first.count == 1 {
                return first.values.first
            } else {
                // Disambiguate by their USR
                throw Error.lookupCollision(first.map { ($0.value, $0.key) })
            }
        } else if let usr = usr {
            let kinds = storage.filter { $0.value.keys.contains(usr) }
            if kinds.isEmpty {
                return nil
            } else if kinds.count == 1 {
                return kinds.first!.value[usr]
            } else {
                // Disambiguate by their kind
                throw Error.lookupCollision(kinds.map { ($0.value[usr]!, $0.key) })
            }
        }
        // Disambiguate by a mix of kinds and USRs
        throw Error.lookupCollision(self.disambiguatedValues().map { ($0.value, String($0.disambiguation.dropFirst())) })
    }
    
    func disambiguatedValues() -> [(value: PathHierarchy.Node, disambiguation: String)] {
        if storage.count == 1 {
            let tree = storage.values.first!
            if tree.count == 1 {
                return [(tree.values.first!, "")]
            }
        }
        
        var collisions: [(value: PathHierarchy.Node, disambiguation: String)] = []
        for (kind, kindTree) in storage {
            if kindTree.count == 1 {
                // No other match has this kind
                collisions.append((value: kindTree.first!.value, disambiguation: "-"+kind))
                continue
            }
            for (usr, value) in kindTree {
                let kinds = storage.filter { $0.value.keys.contains(usr) }
                if kinds.count == 1 {
                    // No other match has this USR
                    collisions.append((value: value, disambiguation: "-"+usr))
                } else {
                    // This needs to be disambiguated by both kind and USR
                    collisions.append((value: value, disambiguation: "-\(kind)-\(usr)"))
                }
            }
        }
        return collisions
    }
}
