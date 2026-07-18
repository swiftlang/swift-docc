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
            PlatformName.isInOrder(
                lhs.key.compactMap { $0 }.min()?.rawValue,
                rhs.key.compactMap { $0 }.min()?.rawValue
            )
        })?.value
    }

    func renderDeclarationTokens() -> [DeclarationRenderSection.Token]? {
        mainRenderFragments()?.declarationFragments.renderDeclarationTokens()
    }
}

extension [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
    func renderDeclarationTokens() -> [DeclarationRenderSection.Token] {
        map { .init(fragment: $0, identifier: nil) }
    }
}
