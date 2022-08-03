/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// A type that can be converted to a DocC symbol.
public protocol DocCSymbolRepresentable: Equatable {
    /// A namespaced, unique identifier for the kind of symbol.
    ///
    /// For example, a Swift class might use `swift.class`.
    var kindIdentifier: String? { get }
    
    /// A unique identifier for this symbol.
    ///
    /// For Swift, this is the USR.
    var preciseIdentifier: String? { get }
    
    /// The case-sensitive title of this symbol as would be used in documentation.
    ///
    /// > Note: DocC embeds function parameter information directly in the title.
    /// > For example: `functionName(parameterName:secondParameter)`
    /// > or `functionName(_:firstNamedParameter)`.
    var title: String { get }
}

public extension DocCSymbolRepresentable {
    /// The given symbol information as a symbol link component.
    ///
    /// The component will include a disambiguation suffix
    /// based on the included information in the symbol. For example, if the symbol
    /// includes a kind identifier and a precise identifier, both
    /// will be represented in the link component.
    var asLinkComponent: AbsoluteSymbolLink.LinkComponent {
        AbsoluteSymbolLink.LinkComponent(
            name: title,
            disambiguationSuffix: .init(
                kindIdentifier: kindIdentifier,
                preciseIdentifier: preciseIdentifier
            )
        )
    }
}

extension AbsoluteSymbolLink.LinkComponent {
    /// Given an array of symbols that are overloads for the symbol represented
    /// by this link component, returns those that are precisely identified by the component.
    ///
    /// If the link is not specific enough to disambiguate between the given symbols,
    /// this function will return an empty array.
    public func disambiguateBetweenOverloadedSymbols<SymbolType: DocCSymbolRepresentable>(
        _ overloadedSymbols: [SymbolType]
    ) -> [SymbolType] {
        // First confirm that we were given symbols to disambiguate
        guard !overloadedSymbols.isEmpty else {
            return []
        }
        
        // Pair each overloaded symbol with its required disambiguation
        // suffix. This will tell us what kind of disambiguation suffix the
        // link should have.
        let overloadedSymbolsWithSuffixes = zip(
            overloadedSymbols, overloadedSymbols.requiredDisambiguationSuffixes
        )
        
        // Next we filter the given symbols for those that are precise matches
        // for the component.
        let matchingSymbols = overloadedSymbolsWithSuffixes.filter { (symbol, _) in
            // Filter the results by those that are fully represented by the element.
            // This includes checking case sensitivity and disambiguation suffix.
            // This _should_ always return a single element but we can't be entirely sure.
            return fullyRepresentsSymbol(symbol)
        }
        
        // We now check all the returned matching symbols to confirm that
        // the current link has the correct disambiguation suffix
        for (_, (shouldAddIdHash, shouldAddKind)) in matchingSymbols {
            if shouldAddIdHash && shouldAddKind {
                guard case .kindAndPreciseIdentifier = disambiguationSuffix else {
                    return []
                }
            } else if shouldAddIdHash {
                guard case .preciseIdentifierHash = disambiguationSuffix else {
                    return []
                }
            } else if shouldAddKind {
                guard case .kindIdentifier = disambiguationSuffix else {
                    return []
                }
            } else {
                guard case .none = disambiguationSuffix else {
                    return []
                }
            }
        }
        
        // Since we've validated that the link has the correct
        // disambiguation suffix, we now return all matching symbols.
        return matchingSymbols.map(\.0)
    }
    
    /// Returns true if the given symbol is fully represented by the
    /// symbol link.
    ///
    /// This means that the element has the same name (case-sensitive)
    /// and, if the symbol link has a disambiguation suffix, the given element has the same
    /// type or usr.
    private func fullyRepresentsSymbol<SymbolType: DocCSymbolRepresentable>(
        _ symbol: SymbolType
    ) -> Bool {
        guard name == symbol.title else {
            return false
        }
        
        switch self.disambiguationSuffix {
        case .none:
            return true
        case .kindIdentifier(let kindIdentifier):
            return symbol.kindIdentifier == kindIdentifier
        case .preciseIdentifierHash(let preciseIdentifierHash):
            return symbol.preciseIdentifier?.stableHashString == preciseIdentifierHash
        case .kindAndPreciseIdentifier(
            kindIdentifier: let kindIdentifier,
            preciseIdentifierHash: let preciseIdentifierHash):
            return symbol.preciseIdentifier?.stableHashString == preciseIdentifierHash
                && symbol.kindIdentifier == kindIdentifier
        }
    }
}

public extension Collection where Element: DocCSymbolRepresentable {
    /// Given a collection of colliding symbols, returns the disambiguation suffix required
    /// for each symbol to disambiguate it from the others in the collection.
    var requiredDisambiguationSuffixes: [(shouldAddIdHash: Bool, shouldAddKind: Bool)] {
        guard let first = first else {
            return []
        }
        
        guard count > 1 else {
            // There are no path collisions
            return Array(repeating: (shouldAddIdHash: false, shouldAddKind: false), count: count)
        }
        
        if allSatisfy({ symbol in symbol.kindIdentifier == first.kindIdentifier }) {
            // All collisions are the same symbol kind.
            return Array(repeating: (shouldAddIdHash: true, shouldAddKind: false), count: count)
        } else {
            // Disambiguate by kind
            return map { currentSymbol in
                let kindCount = filter { $0.kindIdentifier == currentSymbol.kindIdentifier }.count
                
                if LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
                    return (
                        shouldAddIdHash: kindCount > 1,
                        shouldAddKind: kindCount == 1
                    )
                } else {
                    return (
                        shouldAddIdHash: kindCount > 1,
                        shouldAddKind: true
                    )
                }
            }
        }
    }
}

extension SymbolGraph.Symbol: DocCSymbolRepresentable {
    public var preciseIdentifier: String? {
        self.identifier.precise
    }
    
    public var title: String {
        self.names.title
    }
    
    public var kindIdentifier: String? {
        "\(self.identifier.interfaceLanguage).\(self.kind.identifier.identifier)"
    }
    
    public static func == (lhs: SymbolGraph.Symbol, rhs: SymbolGraph.Symbol) -> Bool {
        lhs.identifier.precise == rhs.identifier.precise
    }
}

extension UnifiedSymbolGraph.Symbol: DocCSymbolRepresentable {
    public var preciseIdentifier: String? {
        self.uniqueIdentifier
    }

    public var title: String {
        guard let selector = self.defaultSelector else {
            fatalError("""
                Failed to find a supported default selector. \
                Language unsupported or corrupt symbol graph provided.
                """
            )
        }

        return self.names[selector]!.title
    }

    public var kindIdentifier: String? {
        guard let selector = self.defaultSelector else {
            fatalError("""
                Failed to find a supported default selector. \
                Language unsupported or corrupt symbol graph provided.
                """
            )
        }

        return "\(selector.interfaceLanguage).\(self.kind[selector]!.identifier.identifier)"
    }

    public static func == (lhs: UnifiedSymbolGraph.Symbol, rhs: UnifiedSymbolGraph.Symbol) -> Bool {
        lhs.uniqueIdentifier == rhs.uniqueIdentifier
    }
}
