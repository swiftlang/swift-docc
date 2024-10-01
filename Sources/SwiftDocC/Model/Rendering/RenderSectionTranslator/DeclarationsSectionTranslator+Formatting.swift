/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension DeclarationsSectionTranslator {
    typealias DeclarationFragments = SymbolGraph.Symbol.DeclarationFragments
    typealias Fragment = DeclarationFragments.Fragment

    func formatted(declarations: [[PlatformName?]:DeclarationFragments])
        -> [[PlatformName?]:DeclarationFragments] {
        declarations.mapValues { formatted(declaration: $0) }
    }

    func formatted(declaration: DeclarationFragments) -> DeclarationFragments {
        let formattedFragments = formatted(fragments: declaration.declarationFragments)
        return DeclarationFragments(declarationFragments: formattedFragments)
    }

    func formatted(fragments: [Fragment]) -> [Fragment] {
        fragments // TODO
    }
}
