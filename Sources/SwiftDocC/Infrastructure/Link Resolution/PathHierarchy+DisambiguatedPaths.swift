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
    /// - Returns: A map of unique identifier strings to disambiguated file paths
    func caseInsensitiveDisambiguatedPaths(
        includeDisambiguationForUnambiguousChildren: Bool = false,
        includeLanguage: Bool = false
    ) -> [String: String] {
        func descend(_ node: Node, accumulatedPath: String) -> [(String, (String, Bool))] {
            var results: [(String, (String, Bool))] = []
            let caseInsensitiveChildren = [String: DisambiguationContainer](node.children.map { (symbolFileName($0.key.lowercased()), $0.value) }, uniquingKeysWith: { $0.merge(with: $1) })
            
            for (_, tree) in caseInsensitiveChildren {
                let disambiguatedChildren = tree.disambiguatedValuesWithCollapsedUniqueSymbols(includeLanguage: includeLanguage)
                let uniqueNodesWithChildren = Set(disambiguatedChildren.filter { $0.disambiguation.value() != nil && !$0.value.children.isEmpty }.map { $0.value.symbol?.identifier.precise })
                for (node, disambiguation) in disambiguatedChildren {
                    var path: String
                    if node.identifier == nil && disambiguatedChildren.count == 1 {
                        // When descending through placeholder nodes, we trust that the known disambiguation
                        // that they were created with is necessary.
                        var knownDisambiguation = ""
                        let element = tree.storage.first!
                        if let kind = element.kind, kind != "_" {
                            knownDisambiguation += "-\(kind)"
                        }
                        if let hash = element.hash, hash != "_" {
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

extension PathHierarchy.DisambiguationContainer {
    static func disambiguatedValues(for elements: [Element], includeLanguage: Bool = false) -> [(value: PathHierarchy.Node, disambiguation: Disambiguation)] {
        var collisions: [(value: PathHierarchy.Node, disambiguation: Disambiguation)] = []
        // TODO: Expose enough types and API so that this logic can be thoroughly tested.
        
        var remaining = Set(elements.map(\.node.identifier))
        
        // Kind disambiguation is the most readable, so we start by checking if any element has a unique kind.
        let groupedByKind = [String?: [Element]](grouping: elements, by: \.kind)
        for (kind, elements) in groupedByKind where elements.count == 1 && kind != nil {
            let element = elements.first!
            if includeLanguage, let symbol = element.node.symbol {
                collisions.append((value: element.node, disambiguation: .kind("\(SourceLanguage(id: symbol.identifier.interfaceLanguage).linkDisambiguationID).\(kind!)")))
            } else {
                collisions.append((value: element.node, disambiguation: .kind(kind!)))
            }
            remaining.remove(element.node.identifier)
        }
        
        if remaining.isEmpty {
            return collisions
        }
        
        // Next, if a symbol returns a tuple with a unique number of values, disambiguate by that (without specifying what those arguments are)
        let groupedByReturnCount = [Int?: [Element]](grouping: elements, by: \.returnTypes?.count)
        for (returnTypesCount, elements) in groupedByReturnCount  {
            guard let returnTypesCount = returnTypesCount else { continue }
            guard elements.count > 1 else {
                // Only one element has this number of return values. Disambiguate with only underscores.
                let element = elements.first!
                guard remaining.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                collisions.append((value: elements.first!.node, disambiguation: .returnTypes(.init(repeating: "_", count: returnTypesCount))))
                remaining.remove(element.node.identifier)
                continue
            }
            guard returnTypesCount > 0 else { continue } // Need at least one return value to disambiguate
            
            for returnTypeIndex in 0..<returnTypesCount {
                let grouped = [String: [Element]](grouping: elements, by: { $0.returnTypes![returnTypeIndex] })
                for (returnType, elements) in grouped where elements.count == 1 {
                    // Only one element has this return type
                    let element = elements.first!
                    guard remaining.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                    var disambiguation = [String](repeating: "_", count: returnTypesCount)
                    disambiguation[returnTypeIndex] = returnType
                    collisions.append((value: elements.first!.node, disambiguation: .returnTypes(disambiguation)))
                    remaining.remove(element.node.identifier)
                    continue
                }
            }
        }
        if remaining.isEmpty {
            return collisions
        }
        
        let groupedByParameterCount = [Int?: [Element]](grouping: elements, by: \.parameterTypes?.count)
        for (parameterTypesCount, elements) in groupedByParameterCount  {
            guard let parameterTypesCount = parameterTypesCount else { continue }
            guard elements.count > 1 else {
                // Only one element has this number of parameters. Disambiguate with only underscores.
                let element = elements.first!
                guard remaining.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                collisions.append((value: elements.first!.node, disambiguation: .parameterTypes(.init(repeating: "_", count: parameterTypesCount))))
                remaining.remove(element.node.identifier)
                continue
            }
            guard parameterTypesCount > 0 else { continue } // Need at least one return value to disambiguate
            
            for parameterTypeIndex in 0..<parameterTypesCount {
                let grouped = [String: [Element]](grouping: elements, by: { $0.parameterTypes![parameterTypeIndex] })
                for (returnType, elements) in grouped where elements.count == 1 {
                    // Only one element has this return type
                    let element = elements.first!
                    guard remaining.contains(element.node.identifier) else { continue } // Don't disambiguate the same element more than once
                    var disambiguation = [String](repeating: "_", count: parameterTypesCount)
                    disambiguation[parameterTypeIndex] = returnType
                    collisions.append((value: elements.first!.node, disambiguation: .parameterTypes(disambiguation)))
                    remaining.remove(element.node.identifier)
                    continue
                }
            }
        }
        if remaining.isEmpty {
            return collisions
        }
        
        for element in elements where remaining.contains(element.node.identifier){
            collisions.append((value: element.node, disambiguation: .hash(element.hash ?? "_")))
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
        
        return Self.disambiguatedValues(for: Array(storage), includeLanguage: includeLanguage)
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
            new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
        }
        for (id, symbolDisambiguations) in uniqueSymbolIDs {
            let element = symbolDisambiguations.first!
            new.add(element.node, kind: element.kind, hash: element.hash, parameterTypes: element.parameterTypes, returnTypes: element.returnTypes)
            
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
        case parameterTypes([String])
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
            case .kind(let original):
                return .kind(kind ?? original)
            case .hash(let original):
                return .hash(hash ?? original)
            case .parameterTypes, .returnTypes:
                return self
            }
        }
    }
}
