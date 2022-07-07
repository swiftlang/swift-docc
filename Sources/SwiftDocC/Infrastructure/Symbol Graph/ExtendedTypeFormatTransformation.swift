/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A namespace comprising functionality for converting between the standard Symbol Graph File
/// format with extension block symbols and the Extended Types Format extension used by SwiftDocC.
enum ExtendedTypeFormatTransformation { }

extension ExtendedTypeFormatTransformation {
    /// Transforms the extension symbol graph file to better match the hierarchical symbol structure that DocC uses when processing and rendering documentation.
    ///
    /// ## Discussion
    ///
    /// Performing this transformation before the symbols are registered allows the handling of extensions to be centralized in one place.
    ///
    /// ### Extensions in Symbol Graph Files
    ///
    /// Extension symbol graph files, i.e. such that are named `ExtendingModule@ExtendedModule.symbols.json`,
    /// use the Extension Block Symbol Format to store information about extensions to types from the respective extended module.
    ///
    /// - Note: The emission of extension information to extension symbol graph files can be disabled on the Swift compiler. If such graphs
    /// are encountered, this function returns `false` and does not modify the `symbolGraph`.
    ///
    /// When using the Extension Block Symbol Format in the symbol graph file, each [extension declaration](extension-decl),
    /// i.e. `extension X { ... }`, has one corresponding symbol with a `extension` kind. Each extension declaration symbol
    /// has one `extensionTo` relationship to the symbol that it extends.
    ///
    /// ```swift
    /// extension ExtendedSymbol { ... }
    /// //  │          ▲
    /// //  ╰──────────╯ extensionTo
    /// ```
    ///
    /// Each symbol that's defined in the extension declaration has a `memberOf` relationship to the extension declaration symbol.
    ///
    /// ```swift
    /// extension ExtendedSymbol {
    /// //  ▲
    /// //  ╰────────╮ memberOf
    ///     func addedSymbol() { ... }
    /// }
    /// ```
    ///
    /// If the extension adds protocol conformances, the extension declaration symbol has `conformsTo` relationships for each adopted protocol.
    ///
    /// ```swift
    /// extension ExtendedSymbol: AdoptedProtocol { ... }
    /// //  │                           ▲
    /// //  ╰───────────────────────────╯ conformsTo
    /// ```
    ///
    /// ### Transformation
    ///
    /// The Extension Block Symbol Format is designed to capture all information and directly reflect the declarations in your code. However,
    /// when reading documentation, we have slightly different demands. Therefore, we transform the Extension Block Symbol Format into the
    /// Extended Type Format, which aggregates and structures the extensions' contents.
    ///
    /// #### Extended Type Symbols
    ///
    /// For each extended symbol, all extension declarations are combined into a single "extended type" symbol with the combined
    /// `memberOf` and `conformsTo` relationships for those extension declarations. The extended symbol has the most visible
    /// access off all of the extensions and the longest documentation comment of all the extensions.
    ///
    /// ```swift
    /// /// Long comment that                       //      The combined "ExtendedSymbol" extended type
    /// /// spans two lines.                        //      symbol gets its documentation comment from
    /// internal extension ExtendedSymbol { ... }   // ◀─── this extension declaration
    ///                                             //      ..
    /// /// Short single-line comment.              //      and its "public" access control level from
    /// public extension ExtendedSymbol { ... }     // ◀─── this extension declaration
    /// ```
    ///
    /// The kind of the extended type symbol include information about the extended symbol's kind:
    ///
    ///  - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedStruct``
    ///  - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedClass``
    ///  - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedEnum``
    ///  - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedProtocol``
    ///  - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/unknownExtendedType``
    ///
    /// #### Documentation Hierarchy
    ///
    /// For the extended module, a new "extended module" symbol is created. Each top-level extended symbol has a `declaredIn` relationship to the extended module symbol:
    ///
    /// ```
    /// ┌─────────────┐             ┌──────────────────┐
    /// │  Extended   │  declaredIn │ "ExtendedSymbol" │
    /// │   Module    │◀────────────│   Extended Type  │
    /// └─────────────┘             └──────────────────┘
    /// ```
    ///
    /// For extension declarations where the extended type is nested within another type, an "extended type" symbol is created for each symbol
    /// in the hierarchy.
    ///
    /// ```swift
    /// extension Outer.Inner { ... }
    /// ```
    ///
    /// Each nested  "extended type" symbol has a `inContextOf` relationship to its "extended type" parent symbol.
    ///
    /// ```
    /// ┌─────────────┐             ┌─────────────┐              ┌─────────────┐
    /// │  Extended   │  declaredIn │   "Outer"   │  inContextOf │   "Inner"   │
    /// │   Module    │◀────────────│Extended Type│◀─────────────│Extended Type│
    /// └─────────────┘             └─────────────┘              └─────────────┘
    /// ```
    ///
    /// [extension-decl]: https://docs.swift.org/swift-book/ReferenceManual/Declarations.html#ID378
    ///
    /// #### Path Components
    ///
    /// The URLs for symbols declared in extensions include both the extend_ed_ and extend_ing_ module names:
    ///
    /// ```
    /// /ExtendingModule/ExtendedModule/Path/To/ExtendedSymbol/NewSymbol
    /// ```
    ///
    /// To accomplish this, all extended type symbols' path components are prefixed with the extended module.
    ///
    /// After transforming the extension symbol graph, the extended symbols are to be merged with the extending
    /// module's main symbol graph.
    ///
    /// - Parameter symbolGraph: An (extension) symbol graph that should use the Extension Block Symbol Format.
    /// - Parameter moduleName: The name of the extended module all top-level symbols in this symbol graph belong to.
    /// - Returns: Returns whether the transformation was applied or not. The transformation is applied if `symbolGraph` is an extension graph
    /// in the Extended Type Symbol Format.
    static func transformExtensionBlockFormatToExtendedTypeFormat(_ symbolGraph: inout SymbolGraph, moduleName: String) throws -> Bool {
        var extensionBlockSymbols = extractExtensionBlockSymbols(from: &symbolGraph)
        
        guard !extensionBlockSymbols.isEmpty else {
            return false
        }
        
        prependModuleNameToPathComponents(&symbolGraph.symbols.values, moduleName: moduleName)
        prependModuleNameToPathComponents(&extensionBlockSymbols.values, moduleName: moduleName)
        
        var (extensionToRelationships,
             memberOfRelationships,
             conformsToRelationships) = extractRelationshipsTouchingExtensionBlockSymbols(from: &symbolGraph, using: extensionBlockSymbols)
        
        var (extendedTypeSymbols,
             extensionBlockToExtendedTypeMapping,
             extendedTypeToExtensionBlockMapping) = synthesizePrimaryExtendedTypeSymbols(using: extensionBlockSymbols, extensionToRelationships)
        
        let contextOfRelationships = synthesizeSecondaryExtendedTypeSymbols(&extendedTypeSymbols)
        
        redirect(\.target, of: &memberOfRelationships, using: extensionBlockToExtendedTypeMapping)
        
        redirect(\.source, of: &conformsToRelationships, using: extensionBlockToExtendedTypeMapping)
        
        attachDocComments(to: &extendedTypeSymbols.values, using: { (target) -> [SymbolGraph.Symbol] in
            guard let relevantExtensionBlockSymbols = extendedTypeToExtensionBlockMapping[target.identifier.precise]?.compactMap({ id in extensionBlockSymbols[id] }).filter({ symbol in symbol.docComment != nil }) else {
                return []
            }
            
            // we sort the symbols here because their order is not guaranteed to stay the same
            // across compilation processes and we always want to choose the same doc comment
            // in case there are multiple candidates with maximum number of lines
            if let winner = relevantExtensionBlockSymbols.sorted(by: \.identifier.precise).max(by: { a, b in (a.docComment?.lines.count ?? 0) < (b.docComment?.lines.count ?? 0) }) {
                return [winner]
            } else {
                return []
            }
        })
        
        symbolGraph.relationships.append(contentsOf: memberOfRelationships)
        symbolGraph.relationships.append(contentsOf: conformsToRelationships)
        symbolGraph.relationships.append(contentsOf: contextOfRelationships)
        extendedTypeSymbols.values.forEach { symbol in symbolGraph.symbols[symbol.identifier.precise] = symbol }
        
        try synthesizeExtendedModuleSymbolAndDeclaredInRelationships(on: &symbolGraph,
                                                                      using: extendedTypeSymbols.values.filter { symbol in symbol.pathComponents.count == 2 }.map(\.identifier.precise),
                                                                      moduleName: moduleName)
        
        return true
    }

    /// Tries to obtain `docComment`s for all `targets` and copies the documentation from sources to the target.
    ///
    /// Iterates over all `targets` calling the `source` method to obtain a list of symbols that should serve as sources for the target's `docComment`.
    /// If there is more than one symbol containing a `docComment` in the compound list of target and the list returned by `source`, `onConflict` is
    /// called iteratively on the (modified) target and the next source element.
    private static func attachDocComments<T: MutableCollection>(to targets: inout T,
                                                                using source: (T.Element) -> [SymbolGraph.Symbol],
                                                                onConflict resolveConflict: (_ old: T.Element, _ new: SymbolGraph.Symbol)
                                                 -> SymbolGraph.LineList? = { _, _ in nil })
    where T.Element == SymbolGraph.Symbol {
        for index in targets.indices {
            var target = targets[index]
            
            guard target.docComment == nil else {
                continue
            }
            
            for source in source(target) {
                if case (.some(_), .some(_)) =  (target.docComment, source.docComment) {
                    target.docComment = resolveConflict(target, source)
                } else {
                    target.docComment = target.docComment ?? source.docComment
                }
            }
            
            targets[index] = target
        }
    }
    
    /// Adds the `extendedModule` name from the `swiftExtension` mixin to the beginning of the `pathComponents` array of all `symbols`.
    private static func prependModuleNameToPathComponents<S: MutableCollection>(_ symbols: inout S, moduleName: String) where S.Element == SymbolGraph.Symbol {
        for i in symbols.indices {
            let symbol = symbols[i]
            
            symbols[i] = symbol.replacing(\.pathComponents, with: [moduleName] + symbol.pathComponents)
        }
    }

    /// Collects all symbols with kind identifier `.extension`, removes them from the `symbolGraph`, and returns them separately.
    ///
    /// - Returns: The extracted symbols of kind `.extension` keyed by their precise identifier.
    private static func extractExtensionBlockSymbols(from symbolGraph: inout SymbolGraph) -> [String: SymbolGraph.Symbol] {
        var extensionBlockSymbols: [String: SymbolGraph.Symbol] = [:]
        
        symbolGraph.apply(compactMap: { symbol in
            guard symbol.kind.identifier == SymbolGraph.Symbol.KindIdentifier.extension else {
                return symbol
            }
            
            extensionBlockSymbols[symbol.identifier.precise] = symbol
            return nil
        })
        
        return extensionBlockSymbols
    }

    /// Collects all relationships that touch any of the given extension symbols, removes them from the `symbolGraph`, and returns them separately.
    ///
    /// The relevant relationships in this context are of the following kinds:
    ///
    /// - `.extensionTo`: the `source` must be of kind `.extension`
    /// - `.conformsTo`: the `source` may be of kind `.extension`
    /// - `.memberOf`: the `target` may be of kind `.extension`
    ///
    /// - Parameter extensionBlockSymbols: A mapping between Symbols of kind `.extension` and their precise identifiers.
    ///
    /// - Returns: The extracted relationships listed separately by kind.
    private static func extractRelationshipsTouchingExtensionBlockSymbols(from symbolGraph: inout SymbolGraph,
                                                           using extensionBlockSymbols: [String: SymbolGraph.Symbol])
        -> (extensionToRelationships: [SymbolGraph.Relationship],
            memberOfRelationships: [SymbolGraph.Relationship],
            conformsToRelationships: [SymbolGraph.Relationship]) {
            
        var extensionToRelationships: [SymbolGraph.Relationship] = []
        var memberOfRelationships: [SymbolGraph.Relationship] = []
        var conformsToRelationships: [SymbolGraph.Relationship] = []
        
        symbolGraph.relationships = symbolGraph.relationships.compactMap { relationship in
            switch relationship.kind {
            case .extensionTo:
                if extensionBlockSymbols[relationship.source] != nil {
                    extensionToRelationships.append(relationship)
                    return nil
                }
            case .memberOf:
                if extensionBlockSymbols[relationship.target] != nil {
                    memberOfRelationships.append(relationship)
                    return nil
                }
            case .conformsTo:
                if extensionBlockSymbols[relationship.source] != nil {
                    conformsToRelationships.append(relationship)
                    return nil
                }
            default:
                break
            }
            return relationship
        }
        
        return (extensionToRelationships, memberOfRelationships, conformsToRelationships)
    }

    /// Synthesizes extended type symbols from the given `extensionBlockSymbols` and `extensionToRelationships`.
    ///
    /// Creates symbols of the following kinds:
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedStruct``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedClass``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedEnum``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedProtocol``
    ///
    /// Each created symbol comprises one or more symbols of kind `.extension` that have an `.extensionTo` relationship with the
    /// same type.
    ///
    /// - Returns: - the created extended type symbols keyed by their precise identifier, along with a bidirectional
    /// mapping between the extended type symbols and the `.extension` symbols
    private static func synthesizePrimaryExtendedTypeSymbols<RS: Sequence>(using extensionBlockSymbols: [String: SymbolGraph.Symbol],
                                                                           _ extensionToRelationships: RS)
    -> (extendedTypeSymbols: [String: SymbolGraph.Symbol],
        extensionBlockToExtendedTypeMapping: [String: String],
        extendedTypeToExtensionBlockMapping: [String: [String]])
    where RS.Element == SymbolGraph.Relationship {
            
        var extendedTypeSymbols: [String: SymbolGraph.Symbol] = [:]
        var extensionBlockToExtendedTypeMapping: [String: String] = [:]
        var extendedTypeToExtensionBlockMapping: [String: [String]] = [:]
        var pathComponentToExtendedTypeMapping: [ArraySlice<String>: String] = [:]
        
        extensionBlockToExtendedTypeMapping.reserveCapacity(extensionBlockSymbols.count)
        
        let createExtendedTypeSymbolAndAnchestors = { (extensionBlockSymbol: SymbolGraph.Symbol, id: String) -> SymbolGraph.Symbol in
            var newMixins = [String: Mixin]()
            
            if var swiftExtension = extensionBlockSymbol[mixin: SymbolGraph.Symbol.Swift.Extension.self] {
                swiftExtension.constraints = []
                newMixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = swiftExtension
            }
            
            if let declarationFragments = extensionBlockSymbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self]?.declarationFragments {
                var prefixWithoutWhereClause: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = Array(declarationFragments[..<3])
                
            outer: for fragment in declarationFragments[3...] {
                    switch (fragment.kind, fragment.spelling) {
                    case (.typeIdentifier, _),
                         (.identifier, _),
                         (.text, "."):
                        prefixWithoutWhereClause.append(fragment)
                    default:
                        break outer
                    }
                }
                
                newMixins[SymbolGraph.Symbol.DeclarationFragments.mixinKey] = SymbolGraph.Symbol.DeclarationFragments(declarationFragments: Array(prefixWithoutWhereClause))
            }
            
            return SymbolGraph.Symbol(identifier: .init(precise: id,
                                                        interfaceLanguage: extensionBlockSymbol.identifier.interfaceLanguage),
                                      names: extensionBlockSymbol.names,
                                      pathComponents: extensionBlockSymbol.pathComponents,
                                      docComment: nil,
                                      accessLevel: extensionBlockSymbol.accessLevel,
                                      kind: .extendedType(for: extensionBlockSymbol),
                                      mixins: newMixins)
        }
        
        // mapping from the extensionTo.target to the TYPE_KIND.extension symbol's identifier.precise
        var extendedTypeSymbolIdentifiers: [String: String] = [:]
        
        // we sort the relationships here because their order is not guaranteed to stay the same
        // across compilation processes and choosing the same base symbol (and its USR) is important
        // to keeping (colliding) links stable
        for extensionTo in extensionToRelationships.sorted(by: \.source) {
            guard let extensionBlockSymbol = extensionBlockSymbols[extensionTo.source] else {
                continue
            }
            
            let extendedSymbolId = extendedTypeSymbolIdentifiers[extensionTo.target] ?? extensionBlockSymbol.identifier.precise
            extendedTypeSymbolIdentifiers[extensionTo.target] = extendedSymbolId
            
            let symbol: SymbolGraph.Symbol = extendedTypeSymbols[extendedSymbolId]?.replacing(\.accessLevel) { oldSymbol in
                max(oldSymbol.accessLevel, extensionBlockSymbol.accessLevel)
            } ?? createExtendedTypeSymbolAndAnchestors(extensionBlockSymbol, extendedSymbolId)
            
            pathComponentToExtendedTypeMapping[symbol.pathComponents[...]] = symbol.identifier.precise
            
            extendedTypeSymbols[symbol.identifier.precise] = symbol
            
            extensionBlockToExtendedTypeMapping[extensionTo.source] = symbol.identifier.precise
            extendedTypeToExtensionBlockMapping[symbol.identifier.precise, default: []] += [extensionBlockSymbol.identifier.precise]
        }
        
        return (extendedTypeSymbols, extensionBlockToExtendedTypeMapping, extendedTypeToExtensionBlockMapping)
    }
    
    /// Synthesizes missing ancestor extended type symbols for any nested types among the `extendedTypeSymbols` and
    /// creates the relevant ``SymbolKit/SymbolGraph/Relationship/inContextOf`` relationships.
    ///
    /// Creates symbols of the following kinds:
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/unknownExtendedType``
    ///
    /// If a nested type is extended, but its parent (or another ancestor) is not, this ancestor is not part of the
    /// extension block symbol format. In that case, a extended type symbol of unknown kind is synthesized by
    /// this function. However, if the ancestor symbol is extended, the `extendedTypeSymbols` should
    /// already contain the respective symbol. In that case, the ``SymbolKit/SymbolGraph/Relationship/inContextOf``
    /// is attached to the existing symbol.
    ///
    /// - Returns: the ``SymbolKit/SymbolGraph/Relationship/inContextOf`` relationships between the
    /// relevant extended type symbols
    private static func synthesizeSecondaryExtendedTypeSymbols(_ extendedTypeSymbols: inout [String: SymbolGraph.Symbol]) -> [SymbolGraph.Relationship] {
        let sortedKeys: [(pathComponents: [String], preciseId: String)] = extendedTypeSymbols.map { key, value in
            (value.pathComponents, key)
        }.sorted(by: { a, b in a.pathComponents.count <= b.pathComponents.count && a.preciseId < b.preciseId })
        
        var pathComponentsToSymbolIds: [ArraySlice<String>: String] = [:]
        pathComponentsToSymbolIds.reserveCapacity(extendedTypeSymbols.count)
        for (key, symbol) in extendedTypeSymbols {
            pathComponentsToSymbolIds[symbol.pathComponents[...]] = key
        }
        
        func lookupSymbol(_ pathComponents: ArraySlice<String>) -> SymbolGraph.Symbol? {
            guard let id = pathComponentsToSymbolIds[pathComponents] else {
                return nil
            }
            
            return extendedTypeSymbols[id]
        }
        
        var relationships = [SymbolGraph.Relationship]()
        var symbolIsConnectedToParent = [String: Bool]()
        symbolIsConnectedToParent.reserveCapacity(extendedTypeSymbols.count)
        
        for (pathComponents, preciseId) in sortedKeys {
            guard var symbol = extendedTypeSymbols[preciseId] else {
                continue
            }
            
            var pathComponents = pathComponents[0..<pathComponents.count-1]
            
            // we want to create one extended type symbol for each level of nesting,
            // except for the module
            while !pathComponents[1...].isEmpty {
                let parent = lookupSymbol(pathComponents)?.replacing(\.accessLevel) { oldSymbol in
                    max(oldSymbol.accessLevel, symbol.accessLevel)
                } ?? SymbolGraph.Symbol(identifier: .init(precise: "s:e:" + symbol.identifier.precise,
                                                          interfaceLanguage: symbol.identifier.interfaceLanguage),
                                        names: .init(title: pathComponents[1...].joined(separator: "."),
                                                navigator: pathComponents.last?.asDeclarationFragment(.identifier),
                                                subHeading: nil,
                                                prose: nil),
                                        pathComponents: Array(pathComponents),
                                        docComment: nil,
                                        accessLevel: symbol.accessLevel,
                                        kind: .unknownExtendedType,
                                        mixins: symbol.mixins.keeping(SymbolGraph.Symbol.Swift.Extension.mixinKey))
                
                
                pathComponentsToSymbolIds[pathComponents] = parent.identifier.precise
                extendedTypeSymbols[parent.identifier.precise] = parent
                
                if !symbolIsConnectedToParent[symbol.identifier.precise, default: false] {
                    relationships.append(.init(source: symbol.identifier.precise,
                                               target: parent.identifier.precise,
                                               kind: .inContextOf,
                                               targetFallback: parent.title))
                    symbolIsConnectedToParent[symbol.identifier.precise] = true
                }
                
                symbol = parent
                pathComponents.removeLast()
            }
        }
        
        return relationships
    }
    
    /// Updates the `anchor` of each relationship according to the given `keyMap`.
    ///
    /// If the `anchor` of a relationship cannot be found in the `keyMap`, the relationship is not modified.
    ///
    /// - Parameter anchor: usually either `\.source` or `\.target`
    /// - Parameter relationships: the relationships to redirect
    /// - Parameter keyMap: the mapping of old to new ids
    private static func redirect<RC: MutableCollection>(_ anchor: WritableKeyPath<SymbolGraph.Relationship, String>,
                                  of relationships: inout RC,
                                  using keyMap: [String: String]) where RC.Element == SymbolGraph.Relationship {
        for index in relationships.indices {
            let relationship = relationships[index]
            
            guard let newId = keyMap[relationship[keyPath: anchor]] else {
                continue
            }
            
            relationships[index] = relationship.replacing(anchor, with: newId)
        }
    }

    /// Synthesizes the extended module symbol and declaredIn relationships on the given `symbolGraph` based on the given `extendedTypeSymbolIds`.
    ///
    /// Creates one symbol of kind ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedModule`` with the given name.
    /// The extended type symbols are connected with the extended module symbol using relationships of kind
    /// ``SymbolKit/SymbolGraph/Relationship/declaredIn``.
    private static func synthesizeExtendedModuleSymbolAndDeclaredInRelationships<S: Sequence>(on symbolGraph: inout SymbolGraph, using extendedTypeSymbolIds: S, moduleName: String) throws
    where S.Element == String {
        var extendedModuleId: String?
        
        // we sort the symbols here because their order is not guaranteed to stay the same
        // across compilation processes and choosing the same base symbol (and its USR) is important
        // to keeping (colliding) links stable
        for extendedTypeSymbolId in extendedTypeSymbolIds.sorted() {
            guard let extendedTypeSymbol = symbolGraph.symbols[extendedTypeSymbolId] else {
                continue
            }
            
            let id = extendedModuleId ?? "s:m:" + extendedTypeSymbol.identifier.precise
            extendedModuleId = id
            
            
            let symbol = symbolGraph.symbols[id]?.replacing(\.accessLevel) { oldSymbol in
                max(oldSymbol.accessLevel, extendedTypeSymbol.accessLevel)
            } ?? SymbolGraph.Symbol(identifier: .init(precise: id, interfaceLanguage: extendedTypeSymbol.identifier.interfaceLanguage),
                                    names: .init(title: moduleName, navigator: nil, subHeading: nil, prose: nil),
                                    pathComponents: [moduleName],
                                    docComment: nil,
                                    accessLevel: extendedTypeSymbol.accessLevel,
                                    kind: .init(parsedIdentifier: .extendedModule, displayName: "Extended Module"),
                                    mixins: [:])
            
            symbolGraph.symbols[id] = symbol
            
            let relationship = SymbolGraph.Relationship(source: extendedTypeSymbol.identifier.precise, target: symbol.identifier.precise, kind: .declaredIn, targetFallback: symbol.names.title)
            
            symbolGraph.relationships.append(relationship)
        }
    }
}

// MARK: Apply Mappings to SymbolGraph

private extension SymbolGraph {
    mutating func apply(compactMap include: (SymbolGraph.Symbol) throws -> SymbolGraph.Symbol?) rethrows {
        for (key, symbol) in self.symbols {
            self.symbols.removeValue(forKey: key)
            if let newSymbol = try include(symbol) {
                self.symbols[newSymbol.identifier.precise] = newSymbol
            }
        }
    }
}

// MARK: Replacing Convenience Functions

private extension SymbolGraph.Symbol {
    func replacing<V>(_ keyPath: WritableKeyPath<Self, V>, with value: V) -> Self {
        var new = self
        new[keyPath: keyPath] = value
        return new
    }
    
    func replacing<V>(_ keyPath: WritableKeyPath<Self, V>, with closure: (Self) -> V) -> Self {
        var new = self
        new[keyPath: keyPath] = closure(self)
        return new
    }
}

private extension SymbolGraph.Relationship {
    func replacing<V>(_ keyPath: WritableKeyPath<Self, V>, with value: V) -> Self {
        var new = self
        new[keyPath: keyPath] = value
        return new
    }
}

private extension String {
    func asDeclarationFragment(_ kind: SymbolGraph.Symbol.DeclarationFragments.Fragment.Kind) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
        [.init(kind: kind, spelling: self, preciseIdentifier: nil)]
    }
}

private extension Dictionary {
    func keeping(_ keys: Key...) -> Self {
        var new = Self()
        
        for key in keys {
            new[key] = self[key]
        }
        
        return new
    }
}
