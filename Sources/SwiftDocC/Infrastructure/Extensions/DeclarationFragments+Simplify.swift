/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

fileprivate typealias Fragment = SymbolKit.SymbolGraph.Symbol.DeclarationFragments.Fragment

extension [Fragment] {
    /// Simplifies a declaration into its overloaded representation by removing type idenfiers.
    ///
    /// Consider the following Swift code:
    ///
    /// ```swift
    /// class MyClass {
    ///     func myFunc(param: Int) -> Int {}
    ///     func myFunc(param: String) -> String {}
    /// }
    /// ```
    ///
    /// These two methods can both be referred to as `myFunc(param:)`, regardless of their
    /// parameter and return types. However, when generating an overload group's landing page, we
    /// copy the symbol information from one of these methods, including the type names in the
    /// sub-heading and navigator titles. Ideally, we would want to be able to display
    /// `func myFunc(param:)` in curation and navigation to prevent any confusion.
    ///
    /// The idea behind this function is that any overload will have the same basic display
    /// fragments other than any type names, and that (in Swift) these type names (and only these
    /// type names) are all rendered as `typeIdentifier` fragments. Therefore, we can strip out
    /// these references and get a unified representation.
    ///
    /// However, doing this by itself will return `func myFunc(param: ) -> ` as the result. After
    /// stripping out any `typeIdentifier` fragments, this method then cleans up any visual
    /// oddities like the space in the parameters list and the trailing return-type arrow.
    func simplifyForOverloads() -> Self {
        var output = [Fragment]()

        for var nextFragment in self where nextFragment.kind != .typeIdentifier {
            // If this fragment is the text fragment with the return-type arrow, drop the arrow
            if nextFragment.kind == .text, nextFragment.spelling.hasSuffix(" -> ") {
                nextFragment.spelling = String(nextFragment.spelling.prefix(nextFragment.spelling.count - 4))
            }

            // We want to concatenate text fragments together, so bail here if that's not the situation we're in
            guard var lastFragment = output.last,
                    nextFragment.kind == .text,
                    lastFragment.kind == .text else {
                output.append(nextFragment)
                continue
            }
            output.removeLast()

            // If this is the last argument label before the closing parenthesis, trim the space out before concatenating
            if lastFragment.spelling.hasSuffix(" "), nextFragment.spelling.hasPrefix(")") {
                lastFragment.spelling = lastFragment.spelling.removingTrailingWhitespace()
            }

            // If we're between argument labels, drop the ", " and trim the interleaving whitespace
            if lastFragment.spelling.hasSuffix(": "), nextFragment.spelling == ", " {
                nextFragment.spelling = ""
                lastFragment.spelling = lastFragment.spelling.removingTrailingWhitespace()
            }

            // Now that we've cleaned up the text fragments, we can concatenate them together and
            // add the resulting fragment back to the output
            lastFragment.spelling += nextFragment.spelling
            output.append(lastFragment)
        }

        return output
    }
}
