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
                let uniqueNodesWithChildren = Set(disambiguatedChildren.filter { $0.disambiguation.value() != nil && !$0.value.children.isEmpty }.map { $0.value.symbol?.identifier.precise })
                
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
        for elements: some Sequence<Element>,
        includeLanguage: Bool = false,
        allowAdvancedDisambiguation: Bool = true
    ) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        
        var remainingIDs = Set(elements.map(\.node.identifier))
        
        // Kind disambiguation is the most readable, so we start by checking if any element has a unique kind.
        let groupedByKind = [String?: [Element]](grouping: elements, by: \.kind)
        for (kind, elements) in groupedByKind where elements.count == 1 && kind != nil {
            let element = elements.first!
            if includeLanguage, let symbol = element.node.symbol {
                collisions.append((value: element.node, disambiguation: .kind("\(SourceLanguage(id: symbol.identifier.interfaceLanguage).linkDisambiguationID).\(kind!)")))
            } else {
                collisions.append((value: element.node, disambiguation: .kind(kind!)))
            }
            remainingIDs.remove(element.node.identifier)
        }
        if remainingIDs.isEmpty {
            return collisions
        }
        
        if allowAdvancedDisambiguation {
            // Next, if a symbol returns a tuple with a unique number of values, disambiguate by that (without specifying what those arguments are)
            let groupedByReturnCount = [Int?: [Element]](grouping: elements, by: \.returnTypes?.count)
            for (returnTypesCount, elements) in groupedByReturnCount  {
                guard let returnTypesCount = returnTypesCount else { continue }
                guard elements.count > 1 else {
                    // Only one element has this number of return values. Disambiguate with only underscores.
                    let element = elements.first!
                    guard remainingIDs.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                    collisions.append((value: elements.first!.node, disambiguation: .returnTypes(.init(repeating: "_", count: returnTypesCount))))
                    remainingIDs.remove(element.node.identifier)
                    continue
                }
                guard returnTypesCount > 0 else { continue } // Need at least one return value to disambiguate
                
                for returnTypeIndex in 0..<returnTypesCount {
                    let grouped = [String: [Element]](grouping: elements, by: { $0.returnTypes![returnTypeIndex] })
                    for (returnType, elements) in grouped where elements.count == 1 {
                        // Only one element has this return type
                        let element = elements.first!
                        guard remainingIDs.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                        var disambiguation = [String](repeating: "_", count: returnTypesCount)
                        disambiguation[returnTypeIndex] = returnType
                        collisions.append((value: elements.first!.node, disambiguation: .returnTypes(disambiguation)))
                        remainingIDs.remove(element.node.identifier)
                        continue
                    }
                }
            }
            if remainingIDs.isEmpty {
                return collisions
            }
            
            let groupedByParameterCount = [Int?: [Element]](grouping: elements, by: \.parameterTypes?.count)
            for (parameterTypesCount, elements) in groupedByParameterCount  {
                guard let parameterTypesCount = parameterTypesCount else { continue }
                guard elements.count > 1 else {
                    // Only one element has this number of parameters. Disambiguate with only underscores.
                    let element = elements.first!
                    guard remainingIDs.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                    collisions.append((value: elements.first!.node, disambiguation: .parameterTypes(.init(repeating: "_", count: parameterTypesCount))))
                    remainingIDs.remove(element.node.identifier)
                    continue
                }
                guard parameterTypesCount > 0 else { continue } // Need at least one return value to disambiguate
                
                for parameterTypeIndex in 0..<parameterTypesCount {
                    let grouped = [String: [Element]](grouping: elements, by: { $0.parameterTypes![parameterTypeIndex] })
                    for (returnType, elements) in grouped where elements.count == 1 {
                        // Only one element has this return type
                        let element = elements.first!
                        guard remainingIDs.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                        var disambiguation = [String](repeating: "_", count: parameterTypesCount)
                        disambiguation[parameterTypeIndex] = returnType
                        collisions.append((value: elements.first!.node, disambiguation: .parameterTypes(disambiguation)))
                        remainingIDs.remove(element.node.identifier)
                        continue
                    }
                }
            }
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
    func disambiguatedValuesWithCollapsedUniqueSymbols(
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
    enum Disambiguation {
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
        
        /// Returns the kind or hash value that disambiguates this node.
        func value() -> String! {
            switch self {
            case .none:
                return nil
            case .kind(let value), .hash(let value):
                return value
            default:
                return String(makeSuffix().dropFirst())
            }
        }
        /// Makes a new disambiguation suffix string.
        func makeSuffix() -> String {
            switch self {
            case .none:
                return ""
            case .kind(let value), .hash(let value):
                return "-"+value
            case .returnTypes(let types):
                switch types.count {
                case 0: return "->()"
                case 1: return "->\(types.first!)"
                default: return "->(\(types.joined(separator: ",")))"
                }
            case .parameterTypes(let types):
                return "-(\(types.joined(separator: ",")))"
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
            case .parameterTypes, .returnTypes:
                return self
            }
        }
    }
}
