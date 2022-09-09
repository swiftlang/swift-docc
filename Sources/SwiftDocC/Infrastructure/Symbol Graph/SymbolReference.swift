/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

extension String {
    /// Returns a copy of the string with an appended hash of the given identifier.
    func appendingHashedIdentifier(_ identifier: String) -> String {
        return appending("-\(identifier.stableHashString)")
    }
}

/// A reference to a symbol, possibly defined in a symbol graph.
public struct SymbolReference {
    /// Returns `true` if the symbol is a known graph leaf symbol.
    static func isLeaf(_ symbol: SymbolGraph.Symbol) -> Bool {
        return !symbol.kind.identifier.swiftSymbolCouldHaveChildren
    }
    
    /// Creates a new reference to a symbol.
    ///
    /// The two symbols `MyFramework/Manager`, a class, and `MyFramework/manager`, a static variable,
    /// have the same topic reference paths. For such symbols, set `shouldAddKind` to `true`
    /// to add the symbol kind to the reference path and generate the unique paths
    /// `/myframework/manager-swift.class` and `/myframework/manager-swift.variable`.
    ///
    /// Another case might be two symbols of the same kind with colliding paths, for example,
    /// the variable `MyFramework/vaRiable` and `MyFramework/VARiable`. Set `shouldAddHash` to `true`
    /// to append a hash of the symbol name at the end of the path to make the two paths distinct.
    /// - Parameters:
    ///   - identifier: The precise identifier of a symbol.
    ///   - interfaceLanguages: The source languages of the symbol.
    ///   - symbol: The default symbol graph node representing this symbol, if available.
    ///   - shouldAddHash: If `true`, the new reference has a hash appended to its path.
    ///   - shouldAddKind: If `true`, the new reference has the referenced-symbol kind appended to its path.
    public init(
        _ identifier: String,
        interfaceLanguages: Set<SourceLanguage>,
        defaultSymbol symbol: SymbolGraph.Symbol? = nil,
        shouldAddHash: Bool = false,
        shouldAddKind: Bool = false
    ) {
        self.interfaceLanguages = Set(interfaceLanguages)
        
        guard let symbol = symbol else {
            path = shouldAddHash ?
                identifier.appendingHashedIdentifier(identifier) :
                identifier
            return
        }

        // A module reference does not have path as it's a root symbol in the topic graph.
        if symbol.kind.identifier == SymbolGraph.Symbol.KindIdentifier.module {
            path = ""
            return
        }

        var name = symbol.pathComponents.joinedSymbolPathComponents

        if shouldAddKind {
            let interfaceLanguage = symbol.identifier.interfaceLanguage
            
            let languageIdentifier = SourceLanguage(
                knownLanguageIdentifier: interfaceLanguage
            )?.linkDisambiguationID ?? interfaceLanguage
            
            name = name.appending("-\(languageIdentifier).\(symbol.kind.identifier.identifier)")
        }
        if shouldAddHash {
            name = name.appendingHashedIdentifier(identifier)
        }

        path = name
    }
    
    /// Creates a new reference to a symbol.
    ///
    /// - Parameters:
    ///   - identifier: The precise identifier of a symbol.
    ///   - unifiedSymbol: The unified symbol graph node representing this symbol, if available.
    ///   - shouldAddHash: If `true`, the new reference has a hash appended to its path.
    ///   - shouldAddKind: If `true`, the new reference has the referenced-symbol kind appended to its path.
    public init(
        _ identifier: String,
        unifiedSymbol: UnifiedSymbolGraph.Symbol? = nil,
        shouldAddHash: Bool = false,
        shouldAddKind: Bool = false
    ) {
        self.init(
            identifier,
            interfaceLanguages: unifiedSymbol?.sourceLanguages ?? [],
            defaultSymbol: unifiedSymbol?.defaultSymbol,
            shouldAddHash: shouldAddHash,
            shouldAddKind: shouldAddKind
        )
    }
    
    /// Creates a new reference to a symbol.
    ///
    /// - Parameters:
    ///   - identifier: The precise identifier of a symbol.
    ///   - interfaceLanguage: The source language of the symbol.
    ///   - symbol: The symbol graph node representing this symbol, if available.
    ///   - shouldAddHash: If `true`, the new reference has a hash appended to its path.
    ///   - shouldAddKind: If `true`, the new reference has the referenced-symbol kind appended to its path.
    public init(
        _ identifier: String,
        interfaceLanguage: SourceLanguage,
        symbol: SymbolGraph.Symbol? = nil,
        shouldAddHash: Bool = false,
        shouldAddKind: Bool = false
    ) {
        self.init(
            identifier,
            interfaceLanguages: [interfaceLanguage],
            defaultSymbol: symbol,
            shouldAddHash: shouldAddHash,
            shouldAddKind: shouldAddKind
        )
    }
    
    /// Creates a new symbol reference with the given components and source languages.
    ///
    /// - Parameters:
    ///   - pathComponents: The relative path components from the module or framework to the symbol.
    ///   - interfaceLanguages: The source languages of the symbol.
    public init<SourceLanguages: Collection>(
        pathComponents: [String],
        interfaceLanguages: SourceLanguages
    ) where SourceLanguages.Element == SourceLanguage {
        self.path = pathComponents.joinedSymbolPathComponents
        self.interfaceLanguages = Set(interfaceLanguages)
    }
    
    /// Creates a new symbol reference with the given components and source language.
    ///
    /// - Parameters:
    ///   - pathComponents: The relative path components from the module or framework to the symbol.
    ///   - interfaceLanguage: The source language of the symbol.
    public init(pathComponents: [String], interfaceLanguage: SourceLanguage) {
        self.path = pathComponents.joinedSymbolPathComponents
        self.interfaceLanguages = [interfaceLanguage]
    }
    
    /// The relative path from the module or framework to the symbol itself.
    public let path: String
    
    /// The interface language for the reference.
    public let interfaceLanguages: Set<SourceLanguage>
    
    @available(*, deprecated, message: "Use 'interfaceLanguages' instead.")
    public var interfaceLanguage: SourceLanguage {
        if interfaceLanguages.contains(.swift) {
            return .swift
        } else if let firstInterfaceLanguage = interfaceLanguages.first {
            return firstInterfaceLanguage
        } else {
            return .swift
        }
    }
}

private extension Array where Element == String {
    var joinedSymbolPathComponents: String {
        return joined(separator: "/").components(
            separatedBy: CharacterSet.urlPathAllowed.inverted
        ).joined(separator: "_")
    }
}

extension UnifiedSymbolGraph.Symbol {
    var sourceLanguages: Set<SourceLanguage> {
        // FIXME: Replace with new SymbolKit API once available.
        // Adding a dedicated SymbolKit API for this purpose is tracked
        // with github.com/apple/swift-docc-symbolkit/issues/32 and rdar://85982095.
        return Set(
            pathComponents.keys.map { selector in
                SourceLanguage(knownLanguageIdentifier: selector.interfaceLanguage)
                    ?? SourceLanguage(id: selector.interfaceLanguage)
            }
        )
    }
}
