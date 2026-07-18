/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension [[PlatformName?]: SymbolGraph.Symbol.DeclarationFragments] {
    func mainRenderFragments() -> SymbolGraph.Symbol.DeclarationFragments? {
        self.min(by: { lhs, rhs in
            // Join all the platform IDs and use that to get a stable value
            lhs.key.compactMap(\.?.rawValue).joined() < lhs.key.compactMap(\.?.rawValue).joined()
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
