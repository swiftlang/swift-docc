/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import Foundation
private import SymbolKit
private import DocCCommon

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
        let nameTransform: (String) -> String = if transformToFileNames {
            symbolFileName(_:)
        } else {
            { $0 }
        }
        
        var pathsByUSR: [String: String] = [:]
        
        func descend(_ node: borrowing Node, accumulatedPath: consuming String, updating pathsByUSR: inout [String: String]) {
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
                    var path = "\(accumulatedPath)/\(nameTransform(node.name))"
                    if node.identifier == nil && disambiguatedChildren.count == 1 {
                        let element = container.storage.first!
                        // When descending through placeholder nodes, we trust that the known disambiguation
                        // that they were created with is necessary.
                        if let kind = element.kind {
                            path.append("-\(kind)")
                        }
                        if let hash = element.hash {
                            path.append("-\(hash)")
                        }
                    }
                    if let symbol = node.symbol,
                       // If a symbol node exist in multiple languages, prioritize the Swift variant.
                       node.counterpart == nil || symbol.identifier.interfaceLanguage == "swift"
                    {
                        let newPath = path.appending(disambiguation.makeSuffix())
                        if let oldPath = pathsByUSR.updateValue(newPath, forKey: symbol.identifier.precise) {
                            assertionFailure("Should only have gathered one path per symbol ID. Found \(oldPath) and \(newPath) for the same USR.")
                        }
                    }
                    if includeDisambiguationForUnambiguousChildren || uniqueNodesWithChildren.count > 1 {
                        path += disambiguation.makeSuffix()
                    }
                    descend(node, accumulatedPath: path, updating: &pathsByUSR)
                }
            }
        }
        
        for node in modules {
            let modulePath = "/\(nameTransform(node.name))"
            pathsByUSR[node.name] = modulePath
            descend(node, accumulatedPath: modulePath, updating: &pathsByUSR)
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
        assert(elements.allSatisfy({ $0.node.identifier != nil }), "All nodes should have been assigned an identifier before their disambiguation can be computed.")
        
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
                types: { element in
                    guard let parameterTypes = element.parameterTypes,
                          !parameterTypes.isEmpty,
                          let returnTypes = element.returnTypes
                    else {
                        return nil
                    }
                    return parameterTypes + returnTypes
                },
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
        // This implementation uses partitioning and sorting to avoid tracking non-symbol, unique symbols, and duplicate symbols in
        var storage = storage
        let articlePivot = storage.partition(by: { $0.node.symbol != nil })
        storage[articlePivot...].sort(by: { lhs, rhs in
            let lhsID = lhs.node.symbol!.identifier
            let rhsID = rhs.node.symbol!.identifier
            guard lhsID.precise == rhsID.precise else {
                return lhsID.precise < rhsID.precise
            }
            
            // Order Swift before other language representations of the same symbol
            return lhsID.interfaceLanguage == "swift"
        })
       
        // Use a new disambiguation container (with the collapsed symbols) to compute the minimal necessary disambiguation
        var new = PathHierarchy.DisambiguationContainer()
        for element in storage[..<articlePivot] {
            assert(element.node.symbol == nil, "Miscategorized '\(element.node.symbol!.names.title)' as non-symbol")
            new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
        }
        
        // Try to avoid a temporary head allocation if possible. The compiler _may_ use stack memory for this.
        var symbols = storage[articlePivot...]
        return withUnsafeTemporaryAllocation(of: Element.self, capacity: symbols.count /* There can never be more duplicates than the storage itself */) { duplicatesBuffer in
            var duplicatesCount = 0
            
            while let element = symbols.popFirst() {
                assert(element.node.symbol != nil, "Miscategorized '\(element.node.name)' as a symbol")
                // The first symbol is already sorted based on the interface language
                new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
                
                // Track any duplicates for the next step below.
                while symbols.first?.hash == element.hash {
                    duplicatesBuffer.initializeElement(at: duplicatesCount, to: symbols.removeFirst())
                    duplicatesCount &+= 1
                }
            }
            
            // Disambiguate the elements with the unique symbols collapsed (duplicate symbols with the same USR are not in `new`).
            var disambiguated = new.disambiguatedValues(includeLanguage: includeLanguage, allowAdvancedDisambiguation: allowAdvancedDisambiguation)
            
            // Add values for the duplicate symbols (without updating the _amount_ of necessary disambiguation)
            for index in 0 ..< duplicatesCount {
                let element = duplicatesBuffer[index]
                let primaryDisambiguation = disambiguated.first(where: { $0.value.symbol?.identifier.precise == element.node.symbol?.identifier.precise })!.disambiguation
            
                disambiguated.append((element.node, primaryDisambiguation.updated(kind: element.kind, hash: element.hash)))
            }
            
            duplicatesBuffer.deinitialize() // The closure is responsible for both initializing and deinitializing (but not deallocating) the temporary buffer.
            return disambiguated
        }
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

/// Transforms a symbol name to make it safe to use as a file name.
///
/// This process replaces any character that's not allowed in a path with "\_".
/// It also replaces a forward slash with "\_" to avoid the file name being considered two (or more) path components.
private func symbolFileName(_ symbolName: String) -> String {
    let utf8SymbolName = symbolName.utf8
    
    return String(unsafeUninitializedCapacity: utf8SymbolName.count) { buffer in
        var length = 0
        
        // Most symbol names consist of only ASCII characters; for example "SomeClass" and "+=(_:_:)".
        // In this common case, we can use a fast path.
        for byte in utf8SymbolName {
            if byte.isAllowedInSymbolFileName {
                buffer[length] = byte
                length &+= 1
                continue
            }
            // Replace disallowed characters with "_"
            buffer[length] = .init(ascii: "_")
            length &+= 1
            if byte.isSingleByteCharacter {
                // If the disallowed character was still a single-byte character we continue the fast path
                continue
            }
            
            // If we encounter _any_ variable-length unicode scalars we switch away from the fast path and process full `Character` values instead.
            // This ensures that visual characters that are represented by multiple unicode scalars are transformed into a single "_".
            for character in symbolName.dropFirst(length) {
                buffer[length] = if character.utf8.count == 1, let byte = character.utf8.first, byte.isAllowedInSymbolFileName {
                    byte
                } else {
                    .init(ascii: "_")
                }
                length &+= 1
            }
            // Return here so that the fast path loop doesn't continue processing what was already processed as full `Character` values.
            return length
        }
        
        return length
    }
}

private extension UTF8.CodeUnit {
    /// A Boolean value indicating if the UTF8 code unit is a character that's allowed in the "path" of a URL (except for "/" which is allowed in a path but not permitted in the file name).
    var isAllowedInSymbolFileName: Bool {
        switch self {
        case
            // ! & & ' ( ) * + , - .
            0x21, 0x24, 0x26...0x2E,
            // 0–9,
            0x30...0x39,
            // : ; = @
            0x3A, 0x3B, 0x3D, 0x40,
            // A-Z
            0x41...0x5A,
            // _
            0x5F,
            // a–z
            0x61...0x7A,
            // ~
            0x7E: true
        default:  false
        }
    }
    
    /// A Boolean value indicating if the UTF8 code unit represents a single-byte character or if it is the start of a variable-length unicode scalar.
    var isSingleByteCharacter: Bool {
        // The first bit in the first byte of a valid UTF8 code unit indicates if the variable-length encoding uses one or multiple bytes to represent that scalar.
        // Other bit patterns (with the first bit set) gives the exact length of how many bytes (2, 3, or 4) are used to represent that scalar.
        self < 0b1000_0000
    }
}
