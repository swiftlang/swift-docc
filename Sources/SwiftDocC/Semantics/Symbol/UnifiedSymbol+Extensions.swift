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
        // Return the default selector from the main graph selectors, or if one could not be determined, from all
        // the symbol's selectors including ones for extension symbol graphs.
        return defaultSelector(in: mainGraphSelectors) ?? defaultSelector(in: pathComponents.keys)
    }
    
    private func defaultSelector<Selectors: Sequence>(
        in selectors: Selectors
    ) -> UnifiedSymbolGraph.Selector? where Selectors.Element == UnifiedSymbolGraph.Selector {
        // Return the default selector based on the ordering defined below.
        return selectors.sorted { lhsSelector, rhsSelector in
            switch (lhsSelector.interfaceLanguage, rhsSelector.interfaceLanguage) {
                
            // If both selectors are Swift, pick the one that has the most matching platforms with the other selectors.
            case ("swift", "swift"):
                let nonSwiftSelectors = selectors.filter { $0.interfaceLanguage != "swift" }
                
                let lhsMatchingPlatformsCount = nonSwiftSelectors.filter { $0.platform == lhsSelector.platform }.count
                let rhsMatchingPlatformsCount = nonSwiftSelectors.filter { $0.platform == rhsSelector.platform }.count
                
                if lhsMatchingPlatformsCount == rhsMatchingPlatformsCount {
                    // If they have the same number of matching platforms, return the alphabetically smallest platform.
                    return arePlatformsInIncreasingOrder(lhsSelector.platform, rhsSelector.platform)
                }
                
                return lhsMatchingPlatformsCount > rhsMatchingPlatformsCount
            case ("swift", _):
                return true
            case (_, "swift"):
                return false
            default:
                // Return the alphabetically smallest platform.
                return arePlatformsInIncreasingOrder(lhsSelector.platform, rhsSelector.platform)
            }
        }.first
    }
    
    private func arePlatformsInIncreasingOrder(_ platform1: String?, _ platform2: String?) -> Bool {
        switch (platform1, platform2) {
        case (nil, _):
            return true
        case (_, nil):
            return false
        case (let platform1?, let platform2?):
            return platform1 < platform2
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
        return symbol(forSelector: documentedSymbolSelector)
    }
    
    /// Returns the primary symbol selector to use as documentation source.
    var documentedSymbolSelector: UnifiedSymbolGraph.Selector? {
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
        if let defaultInterfaceLanguage = defaultSelector?.interfaceLanguage {
            return identifier(forLanguage: defaultInterfaceLanguage)
        } else {
            return identifier(forLanguage: "swift")
        }
    }
}
