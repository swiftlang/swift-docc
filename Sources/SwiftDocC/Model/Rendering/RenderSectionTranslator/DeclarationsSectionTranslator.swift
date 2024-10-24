/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

typealias OverloadDeclaration = (
    declaration: [SymbolGraph.Symbol.DeclarationFragments.Fragment],
    reference: ResolvedTopicReference,
    conformance: ConformanceSection?
)

/// Translates a symbol's declaration into a render node's Declarations section.
struct DeclarationsSectionTranslator: RenderSectionTranslator {
    /// A mapping from a symbol reference to the "common fragments" in its overload group.
    static let commonFragmentsMap: Synchronized<[ResolvedTopicReference: [SymbolGraph.Symbol.DeclarationFragments.Fragment]]> = .init([:])

    /// Set the common fragments for the given symbol references.
    func setCommonFragments(
        references: [ResolvedTopicReference],
        fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment])
    {
        Self.commonFragmentsMap.sync({ map in
            for reference in references {
                map[reference] = fragments
            }
        })
    }

    /// Fetch the common fragments for the given reference, if present.
    func commonFragments(
        for reference: ResolvedTopicReference
    ) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment]? {
        Self.commonFragmentsMap.sync({ $0[reference] })
    }

    /// Fetch the common fragments for the given references, or compute it if necessary.
    func commonFragments(
        for mainDeclaration: OverloadDeclaration,
        overloadDeclarations: [OverloadDeclaration]
    ) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
        if let fragments = commonFragments(for: mainDeclaration.reference) {
            return fragments
        }

        let preProcessedDeclarations = [mainDeclaration.declaration] + overloadDeclarations.map(\.declaration)

        // Collect the "common fragments" so we can highlight the ones that are different
        // in each declaration
        let commonFragments = longestCommonSubsequence(preProcessedDeclarations)

        setCommonFragments(
            references: [mainDeclaration.reference] + overloadDeclarations.map(\.reference),
            fragments: commonFragments)

        return commonFragments
    }

    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(documentationDataVariants: symbol.declarationVariants) { trait, declaration -> RenderSection? in
            guard !declaration.isEmpty else {
                return nil
            }

            /// Convert a ``SymbolGraph`` declaration fragment into a ``DeclarationRenderSection/Token``
            /// by resolving any symbol USRs to the appropriate reference link.
            func translateFragment(
                _ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment,
                highlight: Bool
            ) -> DeclarationRenderSection.Token {
                let reference: ResolvedTopicReference?
                if let preciseIdentifier = fragment.preciseIdentifier,
                    let resolved = renderNodeTranslator.context.localOrExternalReference(
                        symbolID: preciseIdentifier
                    )
                {
                    reference = resolved
                    renderNodeTranslator.collectedTopicReferences.append(resolved)
                } else {
                    reference = nil
                }

                // Add the declaration token
                return DeclarationRenderSection.Token(
                    fragment: fragment,
                    identifier: reference?.absoluteString,
                    highlight: highlight
                )
            }

            /// Convenience wrapper for `translateFragment(_:highlight:)` that can be used in
            /// an iterator mapping.
            func translateFragment(
                _ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment
            ) -> DeclarationRenderSection.Token {
                return translateFragment(fragment, highlight: false)
            }

            /// Translate a whole ``SymbolGraph`` declaration to a ``DeclarationRenderSection``
            /// declaration and highlight any tokens that aren't shared with a sequence of common tokens.
            func translateDeclaration(
                _ declaration: [SymbolGraph.Symbol.DeclarationFragments.Fragment],
                commonFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]
            ) -> [DeclarationRenderSection.Token] {
                var translatedDeclaration: [DeclarationRenderSection.Token] = []
                var commonIndex = 0
                for fragment in declaration {
                    if commonIndex < commonFragments.count, fragment == commonFragments[commonIndex] {
                        // fragment is common to all declarations, render plain
                        translatedDeclaration.append(translateFragment(fragment))
                        commonIndex += 1
                    } else {
                        // fragment is unique to this declaration, render highlighted
                        translatedDeclaration.append(translateFragment(fragment, highlight: true))
                    }
                }

                return postProcessTokens(translatedDeclaration)
            }

            func renderOtherDeclarationsTokens(
                from overloadDeclarations: [OverloadDeclaration],
                displayIndex: Int,
                commonFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]
            ) -> DeclarationRenderSection.OtherDeclarations {
                var otherDeclarations: [DeclarationRenderSection.OtherDeclarations.Declaration] = []

                for overloadDeclaration in overloadDeclarations {
                    let translatedDeclaration = translateDeclaration(
                        overloadDeclaration.declaration,
                        commonFragments: commonFragments)
                    otherDeclarations.append(.init(
                        tokens: translatedDeclaration,
                        identifier: overloadDeclaration.reference.absoluteString,
                        conformance: overloadDeclaration.conformance
                    ))

                    // Add a topic reference to the overload
                    renderNodeTranslator.collectedTopicReferences.append(
                        overloadDeclaration.reference
                    )
                }

                return .init(declarations: otherDeclarations, displayIndex: displayIndex)
            }

            func collectOverloadDeclarations(from overloads: Symbol.Overloads) -> [OverloadDeclaration]? {
                let declarations = overloads.references.compactMap { overloadReference -> OverloadDeclaration? in
                    guard let overload = try? renderNodeTranslator.context
                        .entity(with: overloadReference).semantic as? Symbol
                    else {
                        return nil
                    }

                    let conformance = renderNodeTranslator.contentRenderer.conformanceSectionFor(overloadReference, collectedConstraints: [:])

                    let declarationFragments = overload.declarationVariants[trait]?.values
                        .first?
                        .declarationFragments
                    precondition(
                        declarationFragments != nil,
                        "Overloaded symbols must have declaration fragments."
                    )
                    return declarationFragments.map({
                        (declaration: $0, reference: overloadReference, conformance: conformance)
                    })
                }

                guard !declarations.isEmpty else {
                    return nil
                }
                return declarations
            }

            func sortPlatformNames(_ platforms: [PlatformName?]) -> [PlatformName?] {
                platforms.sorted { (lhs, rhs) -> Bool in
                    guard let lhsValue = lhs, let rhsValue = rhs else {
                        return lhs == nil
                    }
                    return lhsValue.rawValue < rhsValue.rawValue
                }
            }

            var declarations: [DeclarationRenderSection] = []
            let languages = [
                trait.interfaceLanguage ?? renderNodeTranslator.identifier.sourceLanguage.id
            ]
            for pair in declaration {
                let (platforms, declaration) = pair

                let renderedTokens: [DeclarationRenderSection.Token]
                let otherDeclarations: DeclarationRenderSection.OtherDeclarations?

                // If this symbol has overloads, render their declarations as well.
                if let overloads = symbol.overloadsVariants[trait],
                    let overloadDeclarations = collectOverloadDeclarations(from: overloads)
                {
                    // Pre-process the declarations by splitting text fragments apart to increase legibility
                    let mainDeclaration = declaration.declarationFragments.flatMap(preProcessFragment(_:))
                    let processedOverloadDeclarations = overloadDeclarations.map({
                        OverloadDeclaration($0.declaration.flatMap(preProcessFragment(_:)), $0.reference, $0.conformance)
                    })

                    // Collect the "common fragments" so we can highlight the ones that are different
                    // in each declaration
                    let commonFragments = commonFragments(
                        for: (mainDeclaration, renderNode.identifier, nil),
                        overloadDeclarations: processedOverloadDeclarations)

                    renderedTokens = translateDeclaration(
                        mainDeclaration,
                        commonFragments: commonFragments
                    )
                    otherDeclarations = renderOtherDeclarationsTokens(
                        from: processedOverloadDeclarations,
                        displayIndex: overloads.displayIndex,
                        commonFragments: commonFragments)
                } else {
                    renderedTokens = declaration.declarationFragments.map(translateFragment)
                    otherDeclarations = nil
                }

                declarations.append(
                    DeclarationRenderSection(
                        languages: languages,
                        platforms: sortPlatformNames(platforms),
                        tokens: renderedTokens,
                        otherDeclarations: otherDeclarations
                    )
                )
            }

            if let alternateDeclarations = symbol.alternateDeclarationVariants[trait] {
                for pair in alternateDeclarations {
                    let (platforms, decls) = pair
                    let platformNames = sortPlatformNames(platforms)
                    for alternateDeclaration in decls {
                        let renderedTokens = alternateDeclaration.declarationFragments.map(translateFragment)

                        declarations.append(
                            DeclarationRenderSection(
                                languages: languages,
                                platforms: platformNames,
                                tokens: renderedTokens
                            )
                        )
                    }
                }
            }

            return DeclarationsRenderSection(declarations: declarations)
        }
    }
}

fileprivate extension DeclarationRenderSection.Token {
    /// Whether this token is a text token with a changed highlight.
    var isHighlightedText: Bool {
        self.highlight == .changed && self.kind == .text
    }

    /// Whether this token has any highlight applied to it.
    var isHighlighted: Bool {
        self.highlight != nil
    }

    /// Create a new ``Kind/text`` token with the given text and highlight.
    init(plainText text: String, highlight: Highlight? = nil) {
        self.init(text: text, kind: .text, highlight: highlight)
    }
}

/// "Post-process" a sequence of declaration tokens by recombining text tokens and cleaning up
/// highlighted spans of tokens.
///
/// The output of `preProcessFragment` is suitable for differencing, but causes unexpected results
/// when handed directly to Swift-DocC-Render and applied to its declaration formatter. This
/// function recombines adjacent tokens so that the declaration formatter can correctly see the
/// structure of a declaration and format it accordingly.
///
/// In addition, this function takes the opportunity to trim whitespace at the beginning and end of
/// highlighted spans of tokens, to beautify the resulting declaration.
fileprivate func postProcessTokens(
    _ tokens: [DeclarationRenderSection.Token]
) -> [DeclarationRenderSection.Token] {
    var processedTokens: [DeclarationRenderSection.Token] = []

    // This function iterates a list of tokens, keeping track of a "previous token" and comparing it
    // against the "current token" to perform the following transformations:
    //
    // 1. Trim whitespace from the end of a highlighted token if the following token is not
    //    highlighted.
    // 2. Trim whitespace from the beginning of a highlighted token if the previous token was not
    //    highlighted.
    // 3. Concatenate plain-text tokens if they are both highlighted or both not highlighted.

    /// If the given tokens are both plain-text tokens with the same highlight, return a token with
    /// both tokens' texts.
    func concatenateTokens(
        _ lhs: DeclarationRenderSection.Token,
        _ rhs: DeclarationRenderSection.Token
    ) -> DeclarationRenderSection.Token? {
        guard lhs.kind == .text, rhs.kind == .text, lhs.highlight == rhs.highlight else {
            return nil
        }
        var result = lhs
        result.text += rhs.text
        return result
    }

    guard var previousToken = tokens.first else { return [] }
    for var currentToken in tokens.dropFirst() {
        // First, check whether the tokens we have start or end a highlighted span, and whether
        // that span started or ended (respectively) with whitespace. If so, break off that
        // whitespace into a new, unhighlighted token, and save any excess tokens accordingly.
        // This is complicated by the fact that the whitespace token could be all whitespace,
        // removing the need to create a new token. Both of these branches also "fall through"
        // to the concatenation check below, in case the creation of a new unhighlighted token
        // allows it to be combined with the current token.

        // If the previous token was a highlighted plain-text token that ended with whitespace,
        // and the current token is not highlighted, then remove the highlighting for the
        // whitespace.
        if previousToken.isHighlightedText,
            !currentToken.isHighlighted,
            previousToken.text.last?.isWhitespace == true
        {
            if previousToken.text.allSatisfy(\.isWhitespace) {
                // if the last token was all whitespace, just convert it to be unhighlighted
                previousToken.highlight = nil
            } else {
                // otherwise, split the trailing whitespace into a new token
                let trimmedText = previousToken.text.removingTrailingWhitespace()
                let trailingWhitespace = previousToken.text.suffix(
                    previousToken.text.count - trimmedText.count
                )
                previousToken.text = trimmedText
                processedTokens.append(previousToken)

                previousToken = .init(plainText: String(trailingWhitespace))
            }
        } else if !previousToken.isHighlighted,
            currentToken.isHighlightedText,
            currentToken.text.first?.isWhitespace == true
        {
            // Vice versa: If the current token is a highlighted plain-text token that begins
            // with whitespace, and the previous token is not highlighted, then remove the
            // highlighting for that whitespace.

            if currentToken.text.allSatisfy(\.isWhitespace) {
                // if this token is all whitespace, just convert it to be unhighlighted
                currentToken.highlight = nil
            } else {
                // otherwise, split the leading whitespace into a new token
                let trimmedText = currentToken.text.removingLeadingWhitespace()
                let leadingWhitespace = currentToken.text.prefix(
                    currentToken.text.count - trimmedText.count
                )
                currentToken.text = trimmedText

                // if we can combine the whitespace with the previous token, do that
                let whitespaceToken = DeclarationRenderSection.Token(plainText: String(leadingWhitespace))
                if let combinedToken = concatenateTokens(previousToken, whitespaceToken) {
                    previousToken = combinedToken
                } else {
                    processedTokens.append(previousToken)
                    previousToken = whitespaceToken
                }
            }
        }

        if let combinedToken = concatenateTokens(previousToken, currentToken) {
            // if we could combine the tokens, save it to the current token so it becomes the
            // "previous" token at the end of the loop
            currentToken = combinedToken
        } else {
            // otherwise, just save off the previous token so we can store the next
            // one for the next iteration
            processedTokens.append(previousToken)
        }
        previousToken = currentToken
    }
    processedTokens.append(previousToken)

    return processedTokens
}

/// "Pre-process" a declaration fragment by eagerly splitting apart text fragments into chunks that
/// are more likely to be held in common with other declarations.
///
/// This method exists to clean up the diff visualization in circumstances where parts of a text
/// fragment are shared in common, but have been combined with other text that is not shared. For
/// example, a declaration such as `myFunc<T>(param: T)` will have a text fragment `>(` before the
/// parameter list, which is technically not shared with a similar declaration `myFunc(param: Int)`
/// which only has a `(` fragment.
///
/// Text should be broken up in three scenarios:
/// 1. Before a parenthesis or comma, as in the previous example,
/// 2. Before and after whitespace, to increase the chances of matching non-whitespace tokens with
///    each other, and
/// 3. After a `?` character, to eagerly separate optional parameter types from their surrounding
///    syntax.
///
/// > Note: Any adjacent text fragments that are both shared or highlighted should be recombined
/// > after translation, to allow Swift-DocC-Render to correctly format Swift declarations into
/// > multiple lines. This is performed as part of `translateDeclaration(_:commonFragments:)` above.
fileprivate func preProcessFragment(
    _ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment
) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
    guard fragment.kind == .text, !fragment.spelling.isEmpty else {
        return [fragment]
    }
    var textPartitions: [Substring] = []
    var substringIndex = fragment.spelling.startIndex
    var currentElement = fragment.spelling[substringIndex]

    func areInSameChunk(_ currentElement: Character, _ nextElement: Character) -> Bool {
        if "(),".contains(nextElement) {
            // an open paren means we have a token like `>(` which should be split
            // a close paren means we have a token like ` = nil)` which should be split
            // a comma is similar to the close paren situation
            return false
        } else if currentElement.isWhitespace != nextElement.isWhitespace {
            // break whitespace into their own blocks
            return false
        } else if currentElement == "?" {
            // if we have a token like `?>` or similar we should break the fragment
            return false
        } else {
            return true
        }
    }

    // FIXME: replace this with `chunked(by:)` if we add swift-algorithms as a dependency
    for (nextIndex, nextElement) in fragment.spelling.indexed().dropFirst() {
        if !areInSameChunk(currentElement, nextElement) {
            textPartitions.append(fragment.spelling[substringIndex..<nextIndex])
            substringIndex = nextIndex
        }
        currentElement = nextElement
    }

    if substringIndex != fragment.spelling.endIndex {
        textPartitions.append(fragment.spelling[substringIndex...])
    }

    return textPartitions.map({ .init(kind: .text, spelling: String($0), preciseIdentifier: nil) })
}

/// Calculate the "longest common subsequence" of a list of sequences.
///
/// The longest common subsequence (LCS) of a set of sequences is the sequence of items that
/// appears in all the input sequences in the same order. For example given the sequences `ABAC`
/// and `CAACB`, the letters `AAC` appear in the same order in both of them, even though the letter
/// `B` interrupts the sequence in the first one.
fileprivate func longestCommonSubsequence<Element: Equatable>(_ sequences: [[Element]]) -> [Element] {
    guard var result = sequences.first else { return [] }

    for other in sequences.dropFirst() {
        // This implementation uses the Swift standard library's `CollectionDifference` API to
        // calculate the difference between two sequences, then back-computes the LCS by applying
        // just the calculated "removals" to the first sequence. Then, in the next loop iteration,
        // recalculate the LCS between the result and the next input sequence. By the time all the
        // input sequences have been iterated, we have a common subsequence from all the inputs.
        for case .remove(let offset, _, _) in other.difference(from: result).removals.reversed() {
            result.remove(at: result.startIndex + offset)
        }
    }

    return result
}
