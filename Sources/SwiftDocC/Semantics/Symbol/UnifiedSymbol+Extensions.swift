/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
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
    
    private func defaultSelector(
        in selectors: some Sequence<UnifiedSymbolGraph.Selector>
    ) -> UnifiedSymbolGraph.Selector? {
        return selectors.min(by: UnifiedSymbolGraph.Selector.Ordering(among: selectors).areInIncreasingOrder)
    }

    func symbol(forSelector selector: UnifiedSymbolGraph.Selector?) -> SymbolGraph.Symbol? {
        guard let selector,
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
        // Prioritize the longest doc comment with a "swift" selector,
        // if there is one.
        return docComment.min(by: { lhs, rhs in
            if (lhs.key.interfaceLanguage == "swift") != (rhs.key.interfaceLanguage == "swift") {
                // sort swift selectors before non-swift ones
                return lhs.key.interfaceLanguage == "swift"
            }

            // if the comments are equal, bail early without iterating them again
            guard lhs.value != rhs.value else {
                return false
            }

            let lhsLength = lhs.value.lines.totalCount
            let rhsLength = rhs.value.lines.totalCount

            if lhsLength == rhsLength {
                // if the comments are the same length, just sort them lexicographically
                return lhs.value.lines.isLexicographicallyBefore(rhs.value.lines)
            } else {
                // otherwise, sort by the length of the doc comment,
                // so that `min` returns the longest comment
                return lhsLength > rhsLength
            }
        })?.key
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

extension UnifiedSymbolGraph.Selector {
    /// An ordering that wraps the comparator to sort a list of selectors.
    /// This wrapper computes the number of non-Swift selectors per platform once,
    /// and allows the comparator to reuse it for each comparison.
    struct Ordering {
        private let nonSwiftSelectorsPerPlatform: [String?: Int]

        init(among selectors: some Sequence<UnifiedSymbolGraph.Selector>) {
            var nonSwiftSelectorsPerPlatform: [String?: Int] = [:]
            for selector in selectors where selector.interfaceLanguage != "swift" {
                nonSwiftSelectorsPerPlatform[selector.platform, default: 0] += 1
            }
            self.nonSwiftSelectorsPerPlatform = nonSwiftSelectorsPerPlatform
        }

        /// A comparator that performs a cascading sort on a list of selectors:
        ///
        /// - A Swift selector is preferred over a non-Swift one.
        /// - If both selectors are for Swift, the value with the most non-Swift selectors for its platform is chosen.
        /// - If it is still a tie, the hierarchical platform order is used.
        func areInIncreasingOrder(
            _ lhs: UnifiedSymbolGraph.Selector,
            _ rhs: UnifiedSymbolGraph.Selector
        ) -> Bool {
            switch (lhs.interfaceLanguage, rhs.interfaceLanguage) {
            // If both selectors are Swift, choose the one with the highest number of non-Swift selectors for its platform
            case ("swift", "swift"):
                let lhsMatchingPlatformsCount = nonSwiftSelectorsPerPlatform[lhs.platform, default: 0]
                let rhsMatchingPlatformsCount = nonSwiftSelectorsPerPlatform[rhs.platform, default: 0]
                if lhsMatchingPlatformsCount != rhsMatchingPlatformsCount {
                    return lhsMatchingPlatformsCount > rhsMatchingPlatformsCount
                }
                // Use the hierarchical platform order
                return PlatformName.areInIncreasingOrder(lhs.platform, rhs.platform)
            case ("swift", _):
                return true
            case (_, "swift"):
                return false
            default:
                // Use the hierarchical platform order
                return PlatformName.areInIncreasingOrder(lhs.platform, rhs.platform)
            }
        }
    }
}

extension Dictionary where Key == UnifiedSymbolGraph.Selector {
    func sortedBySelector() -> [(key: Key, value: Value)] {
        let ordering = UnifiedSymbolGraph.Selector.Ordering(among: keys)
        return sorted { ordering.areInIncreasingOrder($0.key, $1.key) }
    }
}

extension [SymbolGraph.LineList.Line] {
    fileprivate var totalCount: Int {
        return reduce(into: 0) { result, line in
            result += line.text.count
        }
    }

    fileprivate func isLexicographicallyBefore(_ other: Self) -> Bool {
        self.lexicographicallyPrecedes(other) { $0.text < $1.text }
    }
}
