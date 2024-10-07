/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

// All logic related to taking a list of fragments from a symbolgraph symbol
// and turning it into a similar list with additional whitespace formatting.
//
// The basic logic is as follows:
//
// 1. Extract the text from the fragment list and use `SwiftFormat` to output
//    a String of formatted source code
//    (see `Utility/Formatting/SyntaxFormatter.swift`)
// 2. Given the String of formatted source code from step 1, use
//    `FragmentBuilder` to turn that text back into a new list of fragments
//    (see `Utility/Formatting/FragmentBuilder.swift`)
//
// ```
// [Fragment] -> String -> [Fragment]
// ```
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

    /// Returns an array of `Fragment` elements with additional whitespace
    /// formatting text, like indentation and newlines.
    ///
    /// - Parameter fragments: An array of `Fragment` elements for a declaration
    ///    provided by `SymbolKit`.
    ///
    /// - Returns: A new array of `Fragment` elements with the same source code
    ///    text as the input fragments and also including some additional text
    ///    for indentation and splitting the code across multiple lines.
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
