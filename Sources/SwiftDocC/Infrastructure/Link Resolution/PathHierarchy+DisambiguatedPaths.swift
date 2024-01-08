/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

private let nonAllowedPathCharacters = CharacterSet.urlPathAllowed.inverted.union(["/"])

private func symbolFileName(_ symbolName: String) -> String {
    return symbolName.components(separatedBy: nonAllowedPathCharacters).joined(separator: "_")
}

extension PathHierarchy {
    /// Determines the least disambiguated paths for all symbols in the path hierarchy.
    ///
    /// - Parameters:
    ///   - includeDisambiguationForUnambiguousChildren: Whether or not descendants unique to a single collision should maintain the containers disambiguation.
    ///   - includeLanguage: Whether or not kind disambiguation information should include the source language.
    /// - Returns: A map of unique identifier strings to disambiguated file paths.
    func caseInsensitiveDisambiguatedPaths(
        includeDisambiguationForUnambiguousChildren: Bool = false,
        includeLanguage: Bool = false
    ) -> [String: String] {
        return disambiguatedPaths(
            caseSensitive: false,
            transformToFileNames: true,
            includeDisambiguationForUnambiguousChildren: includeDisambiguationForUnambiguousChildren,
            includeLanguage: includeLanguage
        )
    }
    
    /// Determines the disambiguated relative links of all the direct descendants of the given node.
    ///
    /// - Parameters:
    ///   - nodeID: The identifier of the node to determine direct descendant links for.
    /// - Returns: A map if node identifiers to pairs of links and flags indicating if the link is disambiguated or not.
    func disambiguatedChildLinks(of nodeID: ResolvedIdentifier) -> [ResolvedIdentifier: (link: String, hasDisambiguation: Bool)] {
        let node = lookup[nodeID]!
        
        var gathered = [(symbolID: String, (link: String, hasDisambiguation: Bool, id: ResolvedIdentifier, isSwift: Bool))]()
        for (_, tree) in node.children {
            let disambiguatedChildren = tree.disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: false)
            
            for (node, disambiguation) in disambiguatedChildren {
                guard let id = node.identifier, let symbolID = node.symbol?.identifier.precise else { continue }
                let suffix = disambiguation.makeSuffix()
                gathered.append((
                    symbolID: symbolID, (
                        link: node.name + suffix,
                        hasDisambiguation: !suffix.isEmpty,
                        id: id,
                        isSwift: node.symbol?.identifier.interfaceLanguage == "swift"
                    )
                ))
            }
        }
        
        // If a symbol node exist in multiple languages, prioritize the Swift variant.
        let uniqueSymbolValues = Dictionary(gathered, uniquingKeysWith: { lhs, rhs in lhs.isSwift ? lhs : rhs })
            .values.map({ ($0.id, ($0.link, $0.hasDisambiguation)) })
        return .init(uniqueKeysWithValues: uniqueSymbolValues)
    }
    
    /// Determines the least disambiguated links for all symbols in the path hierarchy.
    ///
    /// - Returns: A map of unique identifier strings to disambiguated links.
    func disambiguatedAbsoluteLinks() -> [String: String] {
        return disambiguatedPaths(
            caseSensitive: true,
            transformToFileNames: false,
            includeDisambiguationForUnambiguousChildren: false,
            includeLanguage: false
        )
    }
    
    private func disambiguatedPaths(
        caseSensitive: Bool,
        transformToFileNames: Bool,
        includeDisambiguationForUnambiguousChildren: Bool,
        includeLanguage: Bool
    ) -> [String: String] {
        let nameTransform: (String) -> String
        if transformToFileNames {
            nameTransform = symbolFileName(_:)
        } else {
            nameTransform = { $0 }
        }
        
        func descend(_ node: Node, accumulatedPath: String) -> [(String, (String, Bool))] {
            var results: [(String, (String, Bool))] = []
            let children = [String: DisambiguationContainer](node.children.map {
                var name = $0.key
                if !caseSensitive {
                    name = name.lowercased()
                }
                return (nameTransform(name), $0.value)
            }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in children {
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
                        path = accumulatedPath + "/" + nameTransform(node.name) + knownDisambiguation
                    } else {
                        path = accumulatedPath + "/" + nameTransform(node.name)
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
        
        for node in modules {
            let path = "/" + node.name
            gathered.append(
                (node.name, (path, node.symbol == nil || node.symbol!.identifier.interfaceLanguage == "swift"))
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

extension PathHierarchy.DisambiguationContainer {
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
        
        var new = Self()
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
