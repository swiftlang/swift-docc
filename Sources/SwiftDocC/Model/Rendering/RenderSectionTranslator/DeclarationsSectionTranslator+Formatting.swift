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
        do {
            let ids = createIdentifierMap(fragments)
            let rawText = extractText(from: fragments)
            let formattedText = try format(source: rawText)
            let formattedFragments = buildFragments(from: formattedText, identifiedBy: ids)

            return formattedFragments
        } catch {
            // if there's an error that happens when using swift-format, ignore
            // it and simply return back the original, unformatted fragments
            return fragments
        }
    }

    private func createIdentifierMap(_ fragments: [Fragment]) -> [String:String] {
        var map: [String:String] = [:]

        for fragment in fragments {
            if let id = fragment.preciseIdentifier {
                map[fragment.spelling] = id
            }
        }

        return map
    }

    private func extractText(from fragments: [Fragment]) -> String {
        fragments.reduce("") { "\($0)\($1.spelling)" }
    }

    private func format(source: String) throws -> String {
        try SyntaxFormatter().format(source: source)
    }

    private func buildFragments(
        from source: String,
        identifiedBy ids: [String:String] = [:]
    ) -> [Fragment] {
        FragmentBuilder().buildFragments(from: source, identifiers: ids)
    }
}
