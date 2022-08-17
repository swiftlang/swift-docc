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
/// format with extension block symbols and the extended types format extension used by SwiftDocC.
enum ExtendedTypesFormatTransformation { }

extension ExtendedTypesFormatTransformation {
    /// Merge symbols of kind ``SymbolKit/Symbolgraph/Symbol/KindIdentifier/extendedModule`` that represent the
    /// same module.
    ///
    /// When using the Extended Type Symbol Format on normal (i.e. non-unified) symbol graphs, each of the extension symbol graphs
    /// might contain an extended module symbol representing the same module. When merging all symbol graphs from one primary
    /// module into one `UnifiedSymbolGraph`, this may result in this unified graph having more than one extended module symbol
    /// with the same name. This function merges these duplicate extended module symbols and redirects the `declaredIn` relationships
    /// accordingly. As a result, the final graph will only contain one extended module symbol for each extended module.
    ///
    /// This transformation is relevant in the following case. Consider a project of three modules, `A`, `B`, and `C`, where `B` imports
    /// `A`, and `C` imports `A` and `B`.
    ///
    /// ```swift
    /// // Module A
    /// public struct AStruct { }
    ///
    /// // Module B
    /// import A
    ///
    /// public extension AStruct {
    ///     struct BStruct { }
    /// }
    ///
    /// public protocol BProtocol {}
    ///
    /// // Module C
    /// import A
    /// import B
    ///
    /// public extension AStruct.BStruct {
    ///     struct CStruct { }
    /// }
    ///
    /// public extension BProtocol {
    ///     func foo() { }
    /// }
    /// ```
    ///
    /// The Symbol Graph Files generated for module `C` are `C.symbols.json`, `C@A.symbols.json`, and
    /// `C@B.symbols.json`.
    ///
    /// `CStruct`, as well as the respective `swift.extension` symbol are part of
    /// `C@A.symbols.json`, as they are part of a top-level symbol declared in module `A`. However, since `CStruct`'s
    /// direct partent type is `BStruct`, which is declared in module `B`. Therefore, `CStruct` is considered an extension
    /// to module `B`, which is correctly stated in the `swiftExtension.extendedModule` property. Thus, the transformed
    /// symbol graph for `C@A.symbols.json` contains an extended module symbol for module `B`.
    ///
    /// `BProtocol.foo()`, as well as the respective `swift.extension` symbol are obviously part of `C@B.symbols.json`.
    /// Thus, this transformed symbol graph also contains an extended module symbol for module `B`.
    ///
    /// If one decides to merge the transformed symbol graphs for files `C.symbols.json`, `C@A.symbols.json`, and
    /// `C@B.symbols.json`, the resulting unified graph will have two extended module symbols for module `B`, which is
    /// undesirable. This method should therefore be applied to the unified symbol graph after all symbol graphs resulting from
    /// module `C` have been merged.
    static func mergeExtendedModuleSymbolsFromDifferentFiles(_ symbolGraph: UnifiedSymbolGraph) {
        var canonicalSymbolByModuleName: [String: UnifiedSymbolGraph.Symbol] = [:]
        var keyMap: [String: String] = [:]
        
        // choose canonical extended module symbol for each moduleName
        for symbol in symbolGraph.symbols.values.filter({symbol in symbol.kindIdentifier == "swift." + SymbolGraph.Symbol.KindIdentifier.extendedModule.identifier }).sorted(by: \.uniqueIdentifier) {
            if let canonical = canonicalSymbolByModuleName[symbol.title] {
                // merge accesslevel
                for (selector, level) in symbol.accessLevel {
                    if let oldLevel = canonical.accessLevel[selector] {
                        canonical.accessLevel[selector] = max(oldLevel, level)
                    } else {
                        canonical.accessLevel[selector] = level
                    }
                }
                
                canonicalSymbolByModuleName[symbol.title] = canonical
                keyMap[symbol.uniqueIdentifier] = canonical.uniqueIdentifier
            } else {
                canonicalSymbolByModuleName[symbol.title] = symbol
            }
        }
        
        // delete extended module symbols that were not chosen
        for alternativeId in keyMap.keys {
            symbolGraph.symbols.removeValue(forKey: alternativeId)
        }
        
        // remap `declaredIn` relationships to the respective chosen extended module symbol
        
        // this should only apply to `declaredIn` relationships
        for (selector, var relationships) in symbolGraph.relationshipsByLanguage {
            redirect(\.target, of: &relationships, using: keyMap)
            
            symbolGraph.relationshipsByLanguage[selector] = relationships
        }
        
        redirect(\.target, of: &symbolGraph.orphanRelationships, using: keyMap)
    }
}

extension ExtendedTypesFormatTransformation {
    /// Convert from the extension block symbol format to the extended type symbol format.
    ///
    /// First, the function checks if there are any symbols of kind `.extension` in the graph.
    /// If not, function returns `false` without altering the graph in any way.
    ///
    /// If it finds such symbols, it applies the actual transformation. Refer to the sections below to find
    /// out how the two formats differ.
    ///
    /// In addition, the transformation prepends each symbol's `swiftExtension.extendedModule`
    /// name to its `pathComponents`.
    ///
    /// ### The Extension Block Symbol Format
    ///
    /// The extension block symbol format captures extensions to external types in the following way:
    /// - a member symbol of the according kind for all added members
    /// - a symbol of kind `.extension` _for each extension block_ (i.e. `extension X { ... }`)
    /// - a `.memberOf` relationship between each member symbol and the `.extension` symbol representing
    /// the extension block the member was declared in
    /// - a `.conformsTo` relationship between each relevant protocol and the `.extension` symbol representing
    /// the extension block where the external type was conformed to the respective protocol
    /// - an `.extensionTo` relationship between each `.extension` symbol and the symbol of the original declaration
    /// of the external type it extends
    ///
    /// ```
    ///                                                                         ┌──────────────┐
    ///                                              ┌───────────conformsTo────►│swift.protocol│
    ///                                              │                        m └──────────────┘
    ///                                              │
    /// ┌─────────────┐                              │n                         ┌────────────────┐
    /// │Original Type│                      ┌───────┴───────┐                  │Extension Member│
    /// │    Symbol   │◄────extensionTo──────┤swift.extension│◄────memberOf─────┤     Symbol     │
    /// └─────────────┘ 1                  n └───────────────┘ 1              n └────────────────┘
    /// ```
    ///
    /// ### The Extended Type Symbol Format
    ///
    /// The extended type symbol format provides a more concise and hierarchical structure:
    /// - a member symbol of the according kind for all added members
    /// - an **extended type symbol** _for each external type that was extended_:
    ///     - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedStruct``
    ///     - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extemdedClass``
    ///     - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedEnum``
    ///     - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedProtocol``
    /// - a `.memberOf` relationship between each member symbol and the **extended type symbol** representing
    /// the type that was extended
    /// - a `.conformsTo` relationship between each relevant protocol and the **extended type symbol** representing
    /// the the type that was extended
    /// - a ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedModule`` symbol for each module that
    /// was extended with at leas one `.extension` symbol
    /// - a ``SymbolKit/SymbolGraph/Relationship/declaredIn`` relationship between each **extended type symbol**
    /// and the **extended module symbol** representing the module the extended type was originally declared in
    ///
    /// ```
    ///                                                                        ┌──────────────┐
    ///                                             ┌───────────conformsTo────►│swift.protocol│
    ///                                             │                        m └──────────────┘
    ///                                             │n
    /// ┌────────────┐                      ┌───────┴─────┐                    ┌────────────────┐
    /// │swift.module│                      │Extended Type│                    │Extension Member│
    /// │ .extension │◄────declaredIn───────┤   Symbol    │◄──────memberOf─────┤     Symbol     │
    /// └────────────┘ 1                   n└─────────────┘ 1                n └────────────────┘
    /// ```
    ///
    /// - Parameter symbolGraph: An (extension) symbol graph that should use the extensoin block symbol format.
    /// - Returns: Returns whether the transformation was applied (the `symbolGraph` was an extension graph
    /// in the extended type symbol format) or not
    static func transformExtensionBlockFormatToExtendedTypeFormat(_ symbolGraph: inout SymbolGraph) throws -> Bool {
        var extensionBlockSymbols = extractExtensionBlockSymbols(from: &symbolGraph)
        
        guard !extensionBlockSymbols.isEmpty else {
            return false
        }
        
        prependModuleNameToPathComponents(&symbolGraph.symbols.values)
        prependModuleNameToPathComponents(&extensionBlockSymbols.values)
        
        var (extensionToRelationships,
             memberOfRelationships,
             conformsToRelationships) = extractRelationshipsTouchingExtensionBlockSymbols(from: &symbolGraph, using: extensionBlockSymbols)
        
        var (extendedTypeSymbols,
             extensionBlockToExtendedTypeMapping,
             extendedTypeToExtensionBlockMapping) = synthesizeExtendedTypeSymbols(using: extensionBlockSymbols, extensionToRelationships)
        
        redirect(\.target, of: &memberOfRelationships, using: extensionBlockToExtendedTypeMapping)
        
        redirect(\.source, of: &conformsToRelationships, using: extensionBlockToExtendedTypeMapping)
        
        attachDocComments(to: &extendedTypeSymbols.values, using: { (target) -> [SymbolGraph.Symbol] in
            guard let relevantExtensionBlockSymbols = extendedTypeToExtensionBlockMapping[target.identifier.precise]?.compactMap({ id in extensionBlockSymbols[id] }).filter({ symbol in symbol.docComment != nil }) else {
                return []
            }
            
            // we sort the symbols here because their order is not guaranteed to stay the same
            // accross compilation processes and we always want to choose the same doc comment
            // in case there are multiple candidates with maximum number of lines
            if let winner = relevantExtensionBlockSymbols.sorted(by: \.identifier.precise).max(by: { a, b in (a.docComment?.lines.count ?? 0) < (b.docComment?.lines.count ?? 0) }) {
                return [winner]
            } else {
                return []
            }
        })
        
        symbolGraph.relationships.append(contentsOf: memberOfRelationships)
        symbolGraph.relationships.append(contentsOf: conformsToRelationships)
        extendedTypeSymbols.values.forEach { symbol in symbolGraph.symbols[symbol.identifier.precise] = symbol }
        
        try synthesizeExtendedModuleSymbolsAndDeclaredInRelationships(on: &symbolGraph, using: extendedTypeSymbols.values.map(\.identifier.precise))
        
        return true
    }

    /// Tries to obtain `docComment`s for all `targets` and copies the documentaiton from sources to the target.
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
    private static func prependModuleNameToPathComponents<S: MutableCollection>(_ symbols: inout S) where S.Element == SymbolGraph.Symbol {
        for i in symbols.indices {
            let symbol = symbols[i]
            
            guard let extendedModuleName = symbol[mixin: SymbolGraph.Symbol.Swift.Extension.self]?.extendedModule else {
                continue
            }
            
            symbols[i] = symbol.replacing(\.pathComponents, with: [extendedModuleName] + symbol.pathComponents)
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
    /// The relevant relationships in this context are of the follwing kinds:
    ///
    /// - `.extenisonTo`: the `source` must be of kind `.extension`
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

    /// Synthesizes extended type symbols from the given `extensionBlockSymbols` and `extensoinToRelationships`.
    ///
    /// Creates symbols of the following kinds:
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedStruct``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extemdedClass``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedEnum``
    /// - ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedProtocol``
    ///
    /// Each created symbol comprises one or more symbols of kind `.extension` that have an `.extensionTo` relationship with the
    /// same type.
    ///
    /// - Returns: - the created extended type symbols keyed by their precise identifier, along with a bidirectional
    /// mapping between the extended type symbols and the `.extension` symbols
    private static func synthesizeExtendedTypeSymbols<RS: Sequence>(using extensionBlockSymbols: [String: SymbolGraph.Symbol],
                                                     _ extensionToRelationships: RS)
    -> (extendedTypeSymbols: [String: SymbolGraph.Symbol],
        extensionBlockToExtendedTypeMapping: [String: String],
        extendedTypeToExtensionBlockMapping: [String: [String]])
    where RS.Element == SymbolGraph.Relationship {
            
        var extendedTypeSymbols: [String: SymbolGraph.Symbol] = [:]
        var extensionBlockToExtendedTypeMapping: [String: String] = [:]
        var extendedTypeToExtensionBlockMapping: [String: [String]] = [:]
        
        extensionBlockToExtendedTypeMapping.reserveCapacity(extensionBlockSymbols.count)
        
        let createExtendedTypeSymbol = { (extensionBlockSymbol: SymbolGraph.Symbol, id: String) -> SymbolGraph.Symbol in
            var newMixins = [String: Mixin]()
            
            if var swiftExtension = extensionBlockSymbol[mixin: SymbolGraph.Symbol.Swift.Extension.self] {
                swiftExtension.constraints = []
                newMixins[SymbolGraph.Symbol.Swift.Extension.mixinKey] = swiftExtension
            }
            
            if let declarationFragments = extensionBlockSymbol[mixin: SymbolGraph.Symbol.DeclarationFragments.self]?.declarationFragments {
                var prefixWithoutWhereClause: [SymbolGraph.Symbol.DeclarationFragments.Fragment] = Array(declarationFragments[..<3])
                
            outer: for fragement in declarationFragments[3...] {
                    switch (fragement.kind, fragement.spelling) {
                    case (.typeIdentifier, _),
                         (.identifier, _),
                         (.text, "."):
                        prefixWithoutWhereClause.append(fragement)
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
        // accross compilation processes and choosing the same base symbol (and its USR) is important
        // to keeping (colliding) links stable
        for extensionTo in extensionToRelationships.sorted(by: \.source) {
            guard let extensionBlockSymbol = extensionBlockSymbols[extensionTo.source] else {
                continue
            }
            
            let extendedSymbolId = extendedTypeSymbolIdentifiers[extensionTo.target] ?? extensionBlockSymbol.identifier.precise
            extendedTypeSymbolIdentifiers[extensionTo.target] = extendedSymbolId
            
            let symbol: SymbolGraph.Symbol = extendedTypeSymbols[extendedSymbolId]?.replacing(\.accessLevel) { oldSymbol in
                max(oldSymbol.accessLevel, extensionBlockSymbol.accessLevel)
            } ?? createExtendedTypeSymbol(extensionBlockSymbol, extendedSymbolId)
            
            extendedTypeSymbols[symbol.identifier.precise] = symbol
            
            extensionBlockToExtendedTypeMapping[extensionTo.source] = symbol.identifier.precise
            extendedTypeToExtensionBlockMapping[symbol.identifier.precise]
            = (extendedTypeToExtensionBlockMapping[symbol.identifier.precise] ?? []) + [extensionBlockSymbol.identifier.precise]
        }
        
        return (extendedTypeSymbols, extensionBlockToExtendedTypeMapping, extendedTypeToExtensionBlockMapping)
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

    /// Synthesizes extended module symbols and declaredIn relationships on the given `symbolGraph` based on the given `extendedTypeSymbolIds`.
    ///
    /// Creates one symbol of kind ``SymbolKit/SymbolGraph/Symbol/KindIdentifier/extendedModule`` for all extended type symbols that
    /// extend a type declared in the same module. The extended type symbols are connected with the extended module symbols using relationships of kind
    /// ``SymbolKit/SymbolGraph/Relationship/declaredIn``.
    private static func synthesizeExtendedModuleSymbolsAndDeclaredInRelationships<S: Sequence>(on symbolGraph: inout SymbolGraph, using extendedTypeSymbolIds: S) throws
    where S.Element == String {
        // extensionMixin.extendedModule to module.extension symbol's identifier.precise mapping
        var moduleSymbolIdenitfiers: [String: String] = [:]
        
        // we sort the symbols here because their order is not guaranteed to stay the same
        // accross compilation processes and choosing the same base symbol (and its USR) is important
        // to keeping (colliding) links stable
        for extendedTypeSymbolId in extendedTypeSymbolIds.sorted() {
            guard let extendedTypeSymbol = symbolGraph.symbols[extendedTypeSymbolId] else {
                continue
            }
            
            guard let extensionMixin = extendedTypeSymbol[mixin: SymbolGraph.Symbol.Swift.Extension.self] else {
                continue
            }
            
            let id = moduleSymbolIdenitfiers[extensionMixin.extendedModule] ?? "s:m:" + extendedTypeSymbol.identifier.precise
            moduleSymbolIdenitfiers[extensionMixin.extendedModule] = id
            
            
            let symbol = symbolGraph.symbols[id]?.replacing(\.accessLevel) { oldSymbol in
                max(oldSymbol.accessLevel, extendedTypeSymbol.accessLevel)
            } ?? SymbolGraph.Symbol(identifier: .init(precise: id, interfaceLanguage: extendedTypeSymbol.identifier.interfaceLanguage),
                                    names: .init(title: extensionMixin.extendedModule, navigator: nil, subHeading: nil, prose: nil),
                                    pathComponents: [extensionMixin.extendedModule],
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
    
    func replacing<V>(_ keyPath: WritableKeyPath<Self, V>, with closue: (Self) -> V) -> Self {
        var new = self
        new[keyPath: keyPath] = closue(self)
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
