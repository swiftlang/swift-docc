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
                        let element = tree.storage.first!
                        if let kind = element.kind {
                            knownDisambiguation += "-\(kind)"
                        }
                        if let hash = element.hash {
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
    
    static func disambiguatedValues(
        for elements: some Sequence<Element>,
        includeLanguage: Bool = false
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        
        var remainingIDs = Set(elements.map(\.node.identifier))
        
        // Kind disambiguation is the most readable, so we start by checking if any element has a unique kind.
        let groupedByKind = [String?: [Element]](grouping: elements, by: \.kind)
        for (kind, elements) in groupedByKind where elements.count == 1 && kind != nil {
            let element = elements.first!
            if includeLanguage, let language = element.node.languages.min() {
                collisions.append((value: element.node, disambiguation: .kind("\(language.linkDisambiguationID).\(kind!)")))
            } else {
                collisions.append((value: element.node, disambiguation: .kind(kind!)))
            }
            remainingIDs.remove(element.node.identifier)
        }
        if remainingIDs.isEmpty {
            return collisions
        }
        
        for element in elements where remainingIDs.contains(element.node.identifier) {
            collisions.append((value: element.node, disambiguation: element.hash.map { .hash($0) } ?? .none))
        }
        return collisions
    }
    
    /// Returns all values paired with their disambiguation suffixes.
    ///
    /// - Parameter includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    func disambiguatedValues(includeLanguage: Bool = false) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        if storage.count == 1 {
            return [(storage.first!.node, .none)]
        }
        
        return Self.disambiguatedValues(for: storage, includeLanguage: includeLanguage)
    }
    
    /// Returns all values paired with their disambiguation suffixes without needing to disambiguate between two different versions of the same symbol.
    ///
    /// - Parameter includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    func disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: Bool) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        typealias DisambiguationPair = (String, String)
        
        var uniqueSymbolIDs = [String: [Element]]()
        var nonSymbols = [Element]()
        for element in storage {
            guard let symbol = element.node.symbol else {
                nonSymbols.append(element)
                continue
            }
            if symbol.identifier.interfaceLanguage == "swift" {
                uniqueSymbolIDs[symbol.identifier.precise, default: []].insert(element, at: 0)
            } else {
                uniqueSymbolIDs[symbol.identifier.precise, default: []].append(element)
            }
        }
        
        var duplicateSymbols = [String: ArraySlice<Element>]()
        
        var new = PathHierarchy.DisambiguationContainer()
        for element in nonSymbols {
            new.add(element.node, kind: element.kind, hash: element.hash)
        }
        for (id, symbolDisambiguations) in uniqueSymbolIDs {
            let element = symbolDisambiguations.first!
            new.add(element.node, kind: element.kind, hash: element.hash)
            
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
            for element in disambiguations {
                disambiguated.append((element.node, primaryDisambiguation.updated(kind: element.kind, hash: element.hash)))
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
        func updated(kind: String?, hash: String?) -> Self {
            switch self {
            case .none:
                return .none
            case .kind:
                return kind.map { .kind($0) } ?? self
            case .hash:
                return hash.map { .hash($0) } ?? self
            }
        }
    }
}
