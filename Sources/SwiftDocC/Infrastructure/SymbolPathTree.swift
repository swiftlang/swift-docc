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

// TODO: Integrate this with and link resolution
// TODO: Clean up the draft implementation (inline TODOs and more)
// TODO: Optimize performance (inline TODOs and more)
// TODO: Document (both API and some important implementation aspects)

struct SymbolPathTree {
    
    init<Graphs: Sequence>(symbolGraphs: Graphs) where Graphs.Element == SymbolGraph {
        var roots: [String: Node] = [:]
        
        for graph in symbolGraphs {
            let moduleName = graph.module.name
            let moduleNode: Node
            if let existingModuleNode = roots[moduleName] {
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
                let newModuleNode = SymbolPathTree.Node(value: moduleSymbol)
                roots[moduleName] = newModuleNode
                moduleNode = newModuleNode
            }
            
            let nodes: [String: SymbolPathTree.Node] = graph.symbols.mapValues({ SymbolPathTree.Node(value: $0) })
            
            for relationship in graph.relationships where [.memberOf, .requirementOf, .optionalRequirementOf].contains(relationship.kind) {
                guard let sourceNode = nodes[relationship.source], let targetNode = nodes[relationship.target] else { continue }
                targetNode.add(
                    child: sourceNode,
                    path: sourceNode.value.pathComponents.last!,
                    kind: sourceNode.value.kind.identifier.identifier,
                    usr: sourceNode.value.identifier.precise.stableHashString
                )
            }
            for topLevelNode in nodes.values where topLevelNode.parent == nil {
                // TODO: Remove this duplication of computing the values
                moduleNode.add(
                    child: topLevelNode,
                    path: topLevelNode.value.pathComponents.last!,
                    kind: topLevelNode.value.kind.identifier.identifier,
                    usr: topLevelNode.value.identifier.precise.stableHashString
                )
            }
            assert(nodes.filter({ $0.value.parent == nil }).isEmpty, "Check that all nodes have a parent")
        }
        
        // build the lookup list
        var lookup = [ResolvedIdentifier: Node]()
        func descend(_ node: Node) {
            node.identifier = ResolvedIdentifier()
            lookup[node.identifier] = node
            
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
        
        self.roots = roots
        self.lookup = lookup
    }
    
    let roots: [String: Node]
    let lookup: [ResolvedIdentifier: Node]
    
    func caseInsensitiveDisambiguatedPaths() -> [String: String] {
        func descend(_ node: Node, accumulatedPath: String) -> [(String, String)] {
            var results: [(String, String)] = [(node.value.identifier.precise, accumulatedPath)]
            let caseInsensitiveChildren = [String: DisambiguationTree](node.children.map { ($0.key.lowercased(), $0.value) }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (name, tree) in caseInsensitiveChildren {
                let disambiguatedChildren = tree.disambiguatedValues()
                for (node, disambiguation) in disambiguatedChildren {
                    let path = accumulatedPath + "/" + name + disambiguation
                    results += descend(node, accumulatedPath: path)
                }
            }
            return results
        }
        
        var results: [(String, String)] = []
        
        for (moduleName, node) in roots {
            let path = "/" + moduleName.lowercased()
            results += descend(node, accumulatedPath: path)
        }
        
        // ???: Should this be [String: [String]]?
        return [String: String](results, uniquingKeysWith: { lhs, rhs in min(lhs, rhs) })
    }
    
    final class Node {
        fileprivate var children: [String: DisambiguationTree]
        
        var parent: Node?
        var value: SymbolGraph.Symbol
        var identifier: ResolvedIdentifier!
        
        init(value: SymbolGraph.Symbol) {
            self.value = value
            self.children = [:]
        }
        
        func add(child: Node, path: String, kind: String, usr: String) {
            child.parent = self
            children[path, default: .init()].add(kind, usr, child)
        }
        
        func merge(with other: Node) -> Node {
            let new = Node(value: self.value)
            assert(self.parent?.value == other.parent?.value)
            new.parent = self.parent
            new.children = self.children.merging(other.children, uniquingKeysWith: { $0.merge(with: $1) })
            return new
        }
    }
    
    enum Error: Swift.Error {
        case notFound // TODO: What information would be helpful in a diagnostic here?
        case lookupCollision([(value: Node, disambiguation: String)])
    }
        
    func find(path: String, parent: ResolvedIdentifier? = nil) throws -> SymbolGraph.Symbol {
        return try findNode(path: path, parent: parent).value
    }
    
    func findNode(path rawPath: String, parent: ResolvedIdentifier? = nil) throws -> Node {
        var path = Self.parse(path: rawPath)
        guard !path.isEmpty else {
            throw Error.notFound
        }
        
        let root: Node
        var remaining = path[...]
        if path.first!.0 == "/" {
            // Absolute link
            path = Array(path.dropFirst())
            guard let matchedRoot = roots[path.first!.0] else {
                throw Error.notFound
            }
            root = matchedRoot
            remaining = path.dropFirst()
        } else if let parent = parent {
            var parentNode = lookup[parent]!
            let firstPathName = path.first!.0
            while !parentNode.children.keys.contains(firstPathName) {
                guard let parent = parentNode.parent else {
                    if let moduleMatch = roots[firstPathName] {
                        parentNode = moduleMatch
                        remaining = remaining.dropFirst()
                        break
                    }
                    throw Error.notFound
                }
                parentNode = parent
            }
            root = parentNode
        } else {
            // ???: Allow relative links to skip the module?
            guard let matchedRoot = roots[path.first!.0] else {
                throw Error.notFound
            }
            root = matchedRoot
            remaining = path.dropFirst()
        }
        
        if remaining.isEmpty {
            return root
        }
        var node = root
        while true {
            guard let children = node.children[remaining.first!.0] else {
                throw Error.notFound
            }
            
            do {
                guard let child = try children.find(remaining.first!.1, remaining.first!.2) else {
                    throw Error.notFound
                }
                node = child
                remaining = remaining.dropFirst()
                if remaining.isEmpty {
                    return child
                }
            } catch Error.lookupCollision(let collisions) {
                guard let nextPathComponent = remaining.dropFirst().first else {
                    // Re-throw the original error
                    throw Error.lookupCollision(collisions)
                }
                // Check if the collision can be disambiguated by the children
                let possibleMatches = collisions.compactMap {
                    return try? $0.value.children[nextPathComponent.0]?.find(nextPathComponent.1, nextPathComponent.2)
                }
                if possibleMatches.count == 1 {
                    return possibleMatches.first!
                } else {
                    // Re-throw the original error
                    throw Error.lookupCollision(collisions)
                }
            }
        }

    }
    
    public static func parse(path: String) -> [(String, String?, String?)] {
        guard !path.isEmpty else { return [] }
        guard let components = URL(string: path)?.pathComponents else { return [] }
        
        return components.map {
            guard $0.contains("-") else {
                return ($0, nil, nil)
            }
            
            var s = $0[...]
            var kind, hash: String?
            
            if let dashIndex = s.lastIndex(of: "-") {
                hash = String(s[dashIndex...].dropFirst())
                s = s[..<dashIndex]
                if knownSymbolKinds.contains(hash!) {
                    return (String(s), hash, nil)
                }
                if let languagePrefix = knownLanguagePrefixes.first(where: { hash!.starts(with: $0) }) {
                    return (String(s), String(hash!.dropFirst(languagePrefix.count)), nil)
                }
            }
            if let dashIndex = s.lastIndex(of: "-") {
                kind = String(s[dashIndex...].dropFirst())
                s = s[..<dashIndex]
                if let languagePrefix = knownLanguagePrefixes.first(where: { kind!.starts(with: $0) }) {
                    return (String(s), String(kind!.dropFirst(languagePrefix.count)), hash)
                }
            }
            
            return (String(s), kind, hash)
        }
    }
}

// MARK: Dump

private struct DumpableNode {
    var name: String
    var children: [DumpableNode]
}

private extension SymbolPathTree.Node {
    func dumpableNode() -> DumpableNode {
        return DumpableNode(
            name: "{ \(value.identifier.precise) : \(value.identifier.interfaceLanguage).\(value.kind.identifier.identifier) }",
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

extension SymbolPathTree {
    func dump() -> String {
        let root = DumpableNode(name: ".", children: roots.sorted(by: \.key).map { $0.value.dumpableNode() })
        return dump(root)
    }
    
    private func dump(_ node: DumpableNode, decorator: String = "") -> String {
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

fileprivate struct DisambiguationTree {
    typealias Value = SymbolPathTree.Node
    // TODO: I have some ideas for how to optimize this. The tree is known to be small and be fixed depth.
    var storage: [String: [String: Value]] = [:]
    
    mutating func add(_ kind: String, _ usr: String, _ value: Value) {
        if let existing = storage[kind]?[usr] {
            storage[kind, default: [:]][usr] = existing.merge(with: value)
        } else {
            storage[kind, default: [:]][usr] = value
        }
    }
    
    func merge(with other: DisambiguationTree) -> DisambiguationTree {
        return DisambiguationTree(storage: self.storage.merging(other.storage, uniquingKeysWith: { lhs, rhs in
            lhs.merging(rhs, uniquingKeysWith: {
                lhsValue, rhsValue in
                assert(lhsValue.value == rhsValue.value)
                return lhsValue
            })
        }))
    }
    
    func find(_ kind: String?, _ usr: String?) throws -> Value? {
        if let kind = kind, let first = storage[kind] {
            if let usr = usr {
                return first[usr]
            } else if first.count == 1 {
                return first.values.first
            } else {
                // Disambiguate by their USR
                throw SymbolPathTree.Error.lookupCollision(first.map { ($0.value, $0.key) })
            }
        } else if storage.count == 1, let first = storage.values.first {
            if let usr = usr {
                return first[usr]
            } else if first.count == 1 {
                return first.values.first
            } else {
                // Disambiguate by their USR
                throw SymbolPathTree.Error.lookupCollision(first.map { ($0.value, $0.key) })
            }
        } else if let usr = usr {
            let kinds = storage.filter { $0.value.keys.contains(usr) }
            if kinds.isEmpty {
                return nil
            } else if kinds.count == 1 {
                return kinds.first!.value[usr]
            } else {
                // Disambiguate by their kind
                throw SymbolPathTree.Error.lookupCollision(kinds.map { ($0.value[usr]!, $0.key) })
            }
        }
        // Disambiguate by a mix of kinds and USRs
        throw SymbolPathTree.Error.lookupCollision(self.disambiguatedValues().map { ($0.value, String($0.disambiguation.dropFirst())) })
    }
    
    func disambiguatedValues() -> [(value: Value, disambiguation: String)] {
        if storage.count == 1 {
            let tree = storage.values.first!
            if tree.count == 1 {
                return [(tree.values.first!, "")]
            }
        }
        
        var collisions: [(value: Value, disambiguation: String)] = []
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
