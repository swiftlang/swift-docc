/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
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
    /// The path hierarchy is capable of producing shorter, less disambiguated, and more readable paths than what's used for topic references and URLs. 
    /// Each disambiguation improvement has a boolean parameter to disable it so that DocC can emit the same topic references and URLs as it used to.
    ///
    /// - Parameters:
    ///   - includeDisambiguationForUnambiguousChildren: Whether or not descendants unique to a single collision should maintain the containers disambiguation.
    ///   - includeLanguage: Whether or not kind disambiguation information should include the source language.
    ///   - allowAdvancedDisambiguation: Whether or not to support more advanced and more human readable types of disambiguation.
    /// - Returns: A map of unique identifier strings to disambiguated file paths.
    func caseInsensitiveDisambiguatedPaths(
        includeDisambiguationForUnambiguousChildren: Bool = false,
        includeLanguage: Bool = false,
        allowAdvancedDisambiguation: Bool = true
    ) -> [String: String] {
        return disambiguatedPaths(
            caseSensitive: false,
            transformToFileNames: true,
            includeDisambiguationForUnambiguousChildren: includeDisambiguationForUnambiguousChildren,
            includeLanguage: includeLanguage,
            allowAdvancedDisambiguation: allowAdvancedDisambiguation
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
        
        func gatherLinksFrom(_ containers: some Sequence<DisambiguationContainer>) {
            for container in containers {
                let disambiguatedChildren = container.disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: false, allowAdvancedDisambiguation: true)
                
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
        }
        
        gatherLinksFrom(node.children.values)
        if let counterpart = node.counterpart {
            gatherLinksFrom(counterpart.children.values)
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
            includeLanguage: false,
            allowAdvancedDisambiguation: true
        )
    }
    
    private func disambiguatedPaths(
        caseSensitive: Bool,
        transformToFileNames: Bool,
        includeDisambiguationForUnambiguousChildren: Bool,
        includeLanguage: Bool,
        allowAdvancedDisambiguation: Bool
    ) -> [String: String] {
        let nameTransform: (String) -> String
        if transformToFileNames {
            nameTransform = symbolFileName(_:)
        } else {
            nameTransform = { $0 }
        }
        
        func descend(_ node: Node, accumulatedPath: String) -> [String: String] {
            var innerPathsByUSR: [String: String] = [:]
            let children = [String: DisambiguationContainer](node.children.map {
                var name = $0.key
                if !caseSensitive {
                    name = name.lowercased()
                }
                return (nameTransform(name), $0.value)
            }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, container) in children {
                let disambiguatedChildren = container.disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: includeLanguage, allowAdvancedDisambiguation: allowAdvancedDisambiguation)
                let uniqueNodesWithChildren = Set(disambiguatedChildren.filter { $0.disambiguation != .none && !$0.value.children.isEmpty }.map { $0.value.symbol?.identifier.precise })
                
                for (node, disambiguation) in disambiguatedChildren {
                    var path: String
                    if node.identifier == nil && disambiguatedChildren.count == 1 {
                        // When descending through placeholder nodes, we trust that the known disambiguation
                        // that they were created with is necessary.
                        var knownDisambiguation = ""
                        let element = container.storage.first!
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
                    if let symbol = node.symbol,
                       // If a symbol node exist in multiple languages, prioritize the Swift variant.
                       node.counterpart == nil || symbol.identifier.interfaceLanguage == "swift"
                    {
                        innerPathsByUSR[symbol.identifier.precise] = path + disambiguation.makeSuffix()
                    }
                    if includeDisambiguationForUnambiguousChildren || uniqueNodesWithChildren.count > 1 {
                        path += disambiguation.makeSuffix()
                    }
                    innerPathsByUSR.merge(descend(node, accumulatedPath: path), uniquingKeysWith: { currentPath, newPath in
                        assertionFailure("Should only have gathered one path per symbol ID. Found \(currentPath) and \(newPath) for the same USR.")
                        return currentPath
                    })
                }
            }
            return innerPathsByUSR
        }
        
        var pathsByUSR: [String: String] = [:]
        
        for node in modules {
            let modulePath = "/" + node.name
            pathsByUSR[node.name] = modulePath
            pathsByUSR.merge(descend(node, accumulatedPath: modulePath), uniquingKeysWith: { currentPath, newPath in
                assertionFailure("Should only have gathered one path per symbol ID. Found \(currentPath) and \(newPath) for the same USR.")
                return currentPath
            })
        }
        
        assert(
            Set(pathsByUSR.values).count == pathsByUSR.keys.count,
            {
                let collisionDescriptions = pathsByUSR
                    .reduce(into: [String: [String]](), { $0[$1.value, default: []].append($1.key) })
                    .filter({ $0.value.count > 1 })
                    .map { "\($0.key)\n\($0.value.map({ "  " + $0 }).joined(separator: "\n"))" }
                return """
                Disambiguated paths contain \(collisionDescriptions.count) collision(s):
                \(collisionDescriptions.joined(separator: "\n"))
                """
            }()
        )
        
        return pathsByUSR
    }
}

extension PathHierarchy.DisambiguationContainer {
    
    static func disambiguatedValues(
        for elements: some Collection<Element>,
        includeLanguage: Bool = false,
        allowAdvancedDisambiguation: Bool = true
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions = _disambiguatedValues(for: elements, includeLanguage: includeLanguage, allowAdvancedDisambiguation: allowAdvancedDisambiguation)
        
        // If all but one of the collisions are disfavored, remove the disambiguation for the only favored element.
        if let onlyFavoredElementIndex = collisions.onlyIndex(where: { !$0.value.isDisfavoredInLinkCollisions }) {
            collisions[onlyFavoredElementIndex].disambiguation = .none
        }
        return collisions
    }
    
    private static func _disambiguatedValues(
        for elements: some Collection<Element>,
        includeLanguage: Bool,
        allowAdvancedDisambiguation: Bool
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        // Assume that all elements will find a disambiguation (or close to it)
        collisions.reserveCapacity(elements.count)
        
        var remainingIDs = Set<ResolvedIdentifier>()
        remainingIDs.reserveCapacity(elements.count)
        for element in elements {
            guard let id = element.node.identifier else { continue }
            remainingIDs.insert(id)
        }
        
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
        
        if allowAdvancedDisambiguation {
            let elementsThatSupportAdvancedDisambiguation = elements.filter { !$0.node.isExcludedFromAdvancedLinkDisambiguation }
            
            // Next, if a symbol returns a tuple with a unique number of values, disambiguate by that (without specifying what those arguments are)
            collisions += _disambiguateByTypeSignature(
                elementsThatSupportAdvancedDisambiguation,
                types: \.returnTypes,
                makeDisambiguation: { _, disambiguatingTypeNames in
                    .returnTypes(disambiguatingTypeNames)
                },
                remainingIDs: &remainingIDs
            )
            if remainingIDs.isEmpty {
                return collisions
            }
            
            collisions += _disambiguateByTypeSignature(
                elementsThatSupportAdvancedDisambiguation,
                types: \.parameterTypes,
                makeDisambiguation: { _, disambiguatingTypeNames in
                    .parameterTypes(disambiguatingTypeNames)
                },
                remainingIDs: &remainingIDs
            )
            if remainingIDs.isEmpty {
                return collisions
            }
            
            collisions += _disambiguateByTypeSignature(
                elementsThatSupportAdvancedDisambiguation,
                types: { ($0.parameterTypes ?? []) + ($0.returnTypes ?? []) },
                makeDisambiguation: { element, disambiguatingTypeNames in
                    let numberOfReturnTypes = element.returnTypes?.count ?? 0
                    return .mixedTypes(parameterTypes: disambiguatingTypeNames.dropLast(numberOfReturnTypes), returnTypes: disambiguatingTypeNames.suffix(numberOfReturnTypes))
                },
                remainingIDs: &remainingIDs
            )
            if remainingIDs.isEmpty {
                return collisions
            }
        }
        
        for element in elements where remainingIDs.contains(element.node.identifier) {
            collisions.append((value: element.node, disambiguation: element.hash.map { .hash($0) } ?? .none))
        }
        return collisions
    }
    
    /// Returns all values paired with their disambiguation suffixes.
    ///
    /// - Parameters:
    ///   - includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    ///   - allowAdvancedDisambiguation: Whether or not to support more advanced and more human readable types of disambiguation.
    func disambiguatedValues(
        includeLanguage: Bool = false,
        allowAdvancedDisambiguation: Bool = true
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        if storage.count == 1 {
            return [(storage.first!.node, .none)]
        }
        
        return Self.disambiguatedValues(for: storage, includeLanguage: includeLanguage, allowAdvancedDisambiguation: allowAdvancedDisambiguation)
    }
    
    /// Returns all values paired with their disambiguation suffixes without needing to disambiguate between two different versions of the same symbol.
    ///
    /// - Parameters:
    ///   - includeLanguage: Whether or not the kind disambiguation information should include the language, for example: "swift".
    ///   - allowAdvancedDisambiguation: Whether or not to support more advanced and more human readable types of disambiguation.
    fileprivate func disambiguatedValuesWithCollapsedUniqueSymbols(
        includeLanguage: Bool,
        allowAdvancedDisambiguation: Bool
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
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
            new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
        }
        for (id, symbolDisambiguations) in uniqueSymbolIDs {
            let element = symbolDisambiguations.first!
            new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
            
            if symbolDisambiguations.count > 1 {
                duplicateSymbols[id] = symbolDisambiguations.dropFirst()
            }
        }
        
        var disambiguated = new.disambiguatedValues(includeLanguage: includeLanguage, allowAdvancedDisambiguation: allowAdvancedDisambiguation)
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
    enum Disambiguation: Equatable {
        /// No disambiguation is needed.
        case none
        /// This node is disambiguated by its kind.
        case kind(String)
        /// This node is disambiguated by its hash.
        case hash(String)
        /// This node is disambiguated by its parameter types.
        case parameterTypes([String])
        /// This node is disambiguated by its return types.
        case returnTypes([String])
        /// This node is disambiguated by a mix of parameter types and return types.
        case mixedTypes(parameterTypes: [String], returnTypes: [String])
        
        /// Makes a new disambiguation suffix string.
        func makeSuffix() -> String {
            switch self {
            case .none:
                return ""
            case .kind(let value), .hash(let value):
                // For example: "-enum.case" or "-h1a2s3h"
                return "-"+value
                
            case .returnTypes(let types):
                // For example: "->String" (returns String) or "->()" (returns Void).
                return switch types.count {
                    case 0:  "->()"
                    case 1:  "->\(types.first!)"
                    default: "->(\(types.joined(separator: ",")))"
                }
            case .parameterTypes(let types):
                // For example: "-(String,_)" or "-(_,Int)"` (a certain parameter has a certain type), or "-()" (has no parameters).
                return "-(\(types.joined(separator: ",")))"
                
            case .mixedTypes(parameterTypes: let parameterTypes, returnTypes: let returnTypes):
                return Self.parameterTypes(parameterTypes).makeSuffix() + Self.returnTypes(returnTypes).makeSuffix()
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
            case .parameterTypes, .returnTypes, .mixedTypes:
                return self
            }
        }
    }
    
    private static func _disambiguateByTypeSignature(
        _ elements: [Element],
        types: (Element) -> [String]?,
        makeDisambiguation: (Element, [String]) -> Disambiguation,
        remainingIDs: inout Set<ResolvedIdentifier>
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        // Assume that all elements will find a disambiguation (or close to it)
        collisions.reserveCapacity(elements.count)
        
        typealias ElementAndTypeNames = (element: Element, typeNames: [String])
        var groupedByTypeCount: [Int: [ElementAndTypeNames]] = [:]
        for element in elements {
            guard let typeNames = types(element) else { continue }
 
            groupedByTypeCount[typeNames.count, default: []].append((element, typeNames))
        }
        
        for (numberOfTypeNames, elementAndTypeNamePairs) in groupedByTypeCount {
            guard elementAndTypeNamePairs.count > 1 else {
                // Only one element has this number of types. Disambiguate with only underscores.
                let (element, _) = elementAndTypeNamePairs.first!
                guard remainingIDs.remove(element.node.identifier) != nil else {
                    continue // Don't disambiguate the same element more than once
                }
                collisions.append((value: element.node, disambiguation: makeDisambiguation(element, .init(repeating: "_", count: numberOfTypeNames))))
                continue
            }
            
            guard numberOfTypeNames > 0 else {
                continue // Need at least one type name to disambiguate (when there are multiple elements without parameters or return values)
            }
            
            let suggestedDisambiguations = minimalSuggestedDisambiguation(forOverloadsAndTypeNames: elementAndTypeNamePairs)
            
            for (pair, disambiguation) in zip(elementAndTypeNamePairs, suggestedDisambiguations) {
                guard let disambiguation else {
                    continue // This element can't be uniquely disambiguated using these types
                }
                guard remainingIDs.remove(pair.element.node.identifier) != nil else {
                    continue // Don't disambiguate the same element more than once
                }
                collisions.append((value: pair.element.node, disambiguation: makeDisambiguation(pair.element, disambiguation)))
            }
        }
        return collisions
    }
}

private extension Collection {
    /// Returns the only index of the collection that satisfies the given predicate.
    /// - Parameters:
    ///   - predicate: A closure that takes an element of the collection as its argument and returns a Boolean value indicating whether the element is a match.
    /// - Returns: The index of the only element that satisfies `predicate`, or `nil` if  multiple elements satisfy the predicate or if no element satisfy the predicate.
    /// - Complexity: O(_n_), where _n_ is the length of the collection.
    func onlyIndex(where predicate: (Element) throws -> Bool) rethrows -> Index? {
        guard let matchingIndex = try firstIndex(where: predicate),
              // Ensure that there are no other matches in the rest of the collection
              try !self[index(after: matchingIndex)...].contains(where: predicate)
        else {
            return nil
        }
        
        return matchingIndex
    }
}
