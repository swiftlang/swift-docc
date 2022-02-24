/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension UnifiedSymbolGraph.Symbol {
    var defaultSelector: UnifiedSymbolGraph.Selector? {
        if let mainSelector = self.mainGraphSelectors.first, mainSelector.interfaceLanguage == "swift" {
            return mainSelector
        }

        let defaultSelector = UnifiedSymbolGraph.Selector(interfaceLanguage: "swift", platform: nil)

        if self.pathComponents.keys.contains(defaultSelector) {
            return defaultSelector
        } else if let firstSwiftSelector = self.pathComponents.keys.first(where: { $0.interfaceLanguage == "swift" }) {
            return firstSwiftSelector
        } else if FeatureFlags.current.isExperimentalObjectiveCSupportEnabled {
            return mainGraphSelectors.first ?? pathComponents.keys.first
        } else {
            return nil
        }
    }

    func symbol(forSelector selector: UnifiedSymbolGraph.Selector?) -> SymbolGraph.Symbol? {
        guard let selector = selector,
              let kind = self.kind[selector],
              let pathComponents = self.pathComponents[selector],
              let names = self.names[selector],
              let accessLevel = self.accessLevel[selector],
              let mixins = self.mixins[selector] else {
            return nil
        }

        return SymbolGraph.Symbol(
            identifier: SymbolGraph.Symbol.Identifier(
                precise: self.uniqueIdentifier,
                interfaceLanguage: selector.interfaceLanguage),
            names: names,
            pathComponents: pathComponents,
            docComment: self.docComment[selector],
            accessLevel: accessLevel,
            kind: kind,
            mixins: mixins
        )
    }

    var defaultSymbol: SymbolGraph.Symbol? {
        symbol(forSelector: defaultSelector)
    }
    
    /// Returns the primary symbol to use as documentation source.
    var documentedSymbol: SymbolGraph.Symbol? {
        guard FeatureFlags.current.isExperimentalObjectiveCSupportEnabled else {
            return defaultSymbol
        }
        
        return symbol(forSelector: documentedSymbolSelector)
    }
    
    /// Returns the primary symbol selector to use as documentation source.
    var documentedSymbolSelector: UnifiedSymbolGraph.Selector? {
        guard FeatureFlags.current.isExperimentalObjectiveCSupportEnabled else {
            return defaultSelector
        }
        
        // We'll prioritize the first documented 'swift' symbol, if we have
        // one.
        return docComment.keys.first { selector  in
            return selector.interfaceLanguage == "swift"
        } ?? docComment.keys.first
    }

    func identifier(forLanguage interfaceLanguage: String) -> SymbolGraph.Symbol.Identifier {
        return SymbolGraph.Symbol.Identifier(
            precise: self.uniqueIdentifier,
            interfaceLanguage: interfaceLanguage
        )
    }

    var defaultIdentifier: SymbolGraph.Symbol.Identifier {
        guard FeatureFlags.current.isExperimentalObjectiveCSupportEnabled else {
            return identifier(forLanguage: "swift")
        }
        
        if let defaultInterfaceLanguage = defaultSelector?.interfaceLanguage {
            return identifier(forLanguage: defaultInterfaceLanguage)
        } else {
            return identifier(forLanguage: "swift")
        }
    }
}
