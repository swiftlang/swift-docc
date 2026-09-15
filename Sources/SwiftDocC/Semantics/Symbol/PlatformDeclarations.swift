/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] {
    /// The declaration fragments for the group with the highest priority platform.
    func mainRenderFragments() -> SymbolGraph.Symbol.DeclarationFragments? {
        self.min(by: { lhs, rhs in
            PlatformName.areInIncreasingOrder(
                lhs.key.compactMap { $0 }.min()?.rawValue,
                rhs.key.compactMap { $0 }.min()?.rawValue
            )
        })?.value
    }

    func renderDeclarationTokens() -> [DeclarationRenderSection.Token]? {
        mainRenderFragments()?.declarationFragments.renderDeclarationTokens()
    }
}

extension Dictionary where Key == [PlatformName?] {
    /// Adds any fallback platforms to the platforms in the key and sorts them by priority.
    /// - Returns: A sorted array of platforms / `Value` tuples.
    func expandingPlatformsAndSorting() -> [(Key, Value)] {
        map { platforms, value in
            (PlatformName.addingFallbacks(platforms)
                .sorted { PlatformName.areInIncreasingOrder($0?.rawValue, $1?.rawValue) },
            value)
        }
        .sorted { PlatformName.areInIncreasingOrder($0.0.first??.rawValue, $1.0.first??.rawValue) }
    }
}

extension [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
    func renderDeclarationTokens() -> [DeclarationRenderSection.Token] {
        map { .init(fragment: $0, identifier: nil) }
    }
}

extension SymbolGraph.Symbol.DeclarationFragments {
    /// The declaration fragments represented as text
    func spelling() -> String {
        declarationFragments.map { $0.spelling }.joined()
    }
}
