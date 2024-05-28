/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// Translates a symbol's declaration into a render node's Declarations section.
struct DeclarationsSectionTranslator: RenderSectionTranslator {
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
            func translateFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment, highlightDiff: Bool = false) -> DeclarationRenderSection.Token {
                let reference: ResolvedTopicReference?
                if let preciseIdentifier = fragment.preciseIdentifier,
                   let resolved = renderNodeTranslator.context.localOrExternalReference(symbolID: preciseIdentifier)
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
                    highlightDiff: highlightDiff)
            }

            /// Convenience overload for `translateFragment(_:highlightDiff:)` that can be used in
            /// an iterator mapping.
            func translateFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment) -> DeclarationRenderSection.Token {
                return translateFragment(fragment, highlightDiff: false)
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
                        translatedDeclaration.append(translateFragment(fragment, highlightDiff: true))
                    }
                }

                // post-process the declaration to combine adjacent text fragments
                var processedDeclaration: [DeclarationRenderSection.Token] = []
                var currentToken: DeclarationRenderSection.Token? = nil
                for var token in translatedDeclaration {
                    if var previousToken = currentToken {
                        if previousToken.kind == .highlightDiff,
                           token.kind != .highlightDiff,
                           let previousInnerToken = previousToken.tokens?.last,
                           previousInnerToken.kind == .text,
                           previousInnerToken.text.last?.isWhitespace == true
                        {
                            var newTokens: [DeclarationRenderSection.Token] = previousToken.tokens!.dropLast()
                            // if we've ended a span of highlighted tokens with trailing whitespace,
                            // trim the space out of the highlighted section before continuing
                            if previousInnerToken.text.allSatisfy(\.isWhitespace) {
                                // if the last token was all whitespace, just convert it to be unhighlighted
                                // and save off the remaining highlighted tokens
                                processedDeclaration.append(.init(
                                    text: previousToken.text,
                                    kind: previousToken.kind,
                                    tokens: newTokens))
                                previousToken = .init(
                                    text: previousInnerToken.text,
                                    kind: .text)
                            } else {
                                // otherwise, split off the trailing whitespace into a new token and
                                // save off the rest of the highlighted text
                                let trimmedText = previousInnerToken.text.removingTrailingWhitespace()
                                newTokens.append(.init(text: trimmedText, kind: .text))
                                processedDeclaration.append(.init(
                                    text: previousToken.text,
                                    kind: previousToken.kind,
                                    tokens: newTokens))
                                let trailingWhitespace = previousInnerToken.text.suffix(previousInnerToken.text.count - trimmedText.count)

                                // save the trailing whitespace into `previousToken` as a plain-text
                                // token so we can potentially combine it with the next token below
                                previousToken = .init(
                                    text: String(trailingWhitespace),
                                    kind: .text)
                            }
                        } else if previousToken.kind != .highlightDiff,
                                  token.kind == .highlightDiff,
                                  token.tokens?.count == 1,
                                  let innerToken = token.tokens?.first,
                                  innerToken.kind == .text,
                                  innerToken.text.first?.isWhitespace == true
                        {
                            // if we're about to start a span of highlighted tokens with leading
                            // whitespace, trim the space out of the highlighted section before
                            // continuing
                            if innerToken.text.allSatisfy(\.isWhitespace) {
                                // if this token is all whitespace, just extract it so it renders
                                // without highlighting
                                token = innerToken
                            } else {
                                // otherwise, split the whitespace into a new token and save the
                                // remainder back into the token being processed
                                let trimmedText = innerToken.text.removingLeadingWhitespace()
                                let leadingWhitespace = innerToken.text.prefix(innerToken.text.count - trimmedText.count)
                                token = .init(
                                    text: token.text,
                                    kind: token.kind,
                                    tokens: [.init(text: trimmedText, kind: .text)])
                                // if we can combine the whitespace with the previous token, do that
                                if previousToken.kind == .text {
                                    previousToken = .init(
                                        text: previousToken.text + leadingWhitespace,
                                        kind: .text)
                                } else {
                                    // otherwise, save off the previous token and create a new token
                                    // with just the whitespace in it
                                    processedDeclaration.append(previousToken)
                                    previousToken = .init(
                                        text: String(leadingWhitespace),
                                        kind: .text)
                                }
                            }
                        }

                        if previousToken.kind == .text,
                            token.kind == .text
                        {
                            // combine adjacent text tokens if they're both plain
                            token = .init(
                                text: previousToken.text + token.text,
                                kind: .text)
                        } else if previousToken.kind == .highlightDiff, token.kind == .highlightDiff {
                            if let previousInnerTokens = previousToken.tokens,
                               let previousInnerToken = previousInnerTokens.last,
                               let nextInnerTokens = token.tokens, nextInnerTokens.count == 1,
                               let nextInnerToken = nextInnerTokens.first,
                               previousInnerToken.kind == .text, nextInnerToken.kind == .text
                            {
                                // combine adjacent text tokens if they're both highlighted
                                var newTokens: [DeclarationRenderSection.Token] = previousInnerTokens.dropLast()
                                newTokens.append(.init(
                                    text: previousInnerToken.text + nextInnerToken.text,
                                    kind: .text))
                                token = .init(
                                    text: "",
                                    kind: .highlightDiff,
                                    tokens: newTokens)
                            } else {
                                // fold adjacent highlighted tokens into the same token list
                                token = .init(
                                    text: previousToken.text,
                                    kind: previousToken.kind,
                                    tokens: (previousToken.tokens ?? []) + (token.tokens ?? []))
                            }
                        } else {
                            // otherwise, just save off the previous token so we can store the next
                            // one for the next iteration
                            processedDeclaration.append(previousToken)
                        }
                    }
                    currentToken = token
                }
                if let currentToken = currentToken {
                    processedDeclaration.append(currentToken)
                }

                return processedDeclaration
            }

            typealias OverloadDeclaration = (declaration: [SymbolGraph.Symbol.DeclarationFragments.Fragment], reference: ResolvedTopicReference)

            func renderOtherDeclarationsTokens(
                from overloadDeclarations: [OverloadDeclaration],
                displayIndex: Int,
                commonFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]
            ) -> DeclarationRenderSection.OtherDeclarations {
                var otherDeclarations = [DeclarationRenderSection.OtherDeclarations.Declaration]()

                for overloadDeclaration in overloadDeclarations {
                    let translatedDeclaration = translateDeclaration(
                        overloadDeclaration.declaration,
                        commonFragments: commonFragments)
                    otherDeclarations.append(.init(
                        tokens: translatedDeclaration,
                        identifier: overloadDeclaration.reference.absoluteString))

                    // Add a topic reference to the overload
                    renderNodeTranslator.collectedTopicReferences.append(overloadDeclaration.reference)
                }

                return .init(declarations: otherDeclarations, displayIndex: displayIndex)
            }

            /// "Pre-process" a declaration fragment by eagerly splitting apart text fragments
            /// into chunks that are more likely to be held in common with other declarations.
            ///
            /// This method exists to clean up the diff visualization in circumstances where parts
            /// of a text fragment are shared in common, but have been combined with other text
            /// that is not shared. For example, a declaration such as `myFunc<T>(param: T)` will
            /// have a text fragment `>(` before the parameter list, which is technically not
            /// shared with a similar declaration `myFunc(param: Int)` which only has a `(`
            /// fragment.
            ///
            /// Text should be broken up in three scenarios:
            /// 1. Before a parenthesis or comma, as in the previous example,
            /// 2. Before and after whitespace, to increase the chances of matching non-whitespace
            ///    tokens with each other, and
            /// 3. After a `?` character, to eagerly separate optional parameter types from their
            ///    surrounding syntax.
            ///
            /// > Note: Any adjacent text fragments that are both shared or highlighted should
            /// > be recombined after translation, to allow Swift-DocC-Render to correctly format
            /// > Swift declarations into multiple lines. This is performed as part of
            /// > `translateDeclaration(_:commonFragments:)` above.
            func preProcessFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment) -> [SymbolGraph.Symbol.DeclarationFragments.Fragment] {
                guard fragment.kind == .text, !fragment.spelling.isEmpty else {
                    return [fragment]
                }
                var textPartitions: [String] = []
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
                        textPartitions.append(String(fragment.spelling[substringIndex..<nextIndex]))
                        substringIndex = nextIndex
                    }
                    currentElement = nextElement
                }

                if substringIndex != fragment.spelling.endIndex {
                    textPartitions.append(String(fragment.spelling[substringIndex...]))
                }

                return textPartitions.map({ .init(kind: .text, spelling: $0, preciseIdentifier: nil) })
            }

            var declarations = [DeclarationRenderSection]()
            for pair in declaration {
                let (platforms, declaration) = pair

                let renderedTokens: [DeclarationRenderSection.Token]
                let otherDeclarations: DeclarationRenderSection.OtherDeclarations?

                // If this symbol has overloads, render their declarations as well.
                if let overloads = symbol.overloadsVariants[trait],
                   let overloadDeclarations = symbol.overloadsVariants[trait]?.references.compactMap({ overloadReference -> OverloadDeclaration? in
                    guard let overload = try? renderNodeTranslator.context.entity(with: overloadReference).semantic as? Symbol else {
                        return nil
                    }

                    let declarationFragments = overload.declarationVariants[trait]?.values.first?.declarationFragments
                    assert(declarationFragments != nil, "Overloaded symbols must have declaration fragments.")
                    return declarationFragments.map({ (declaration: $0, reference: overloadReference )})
                }), !overloadDeclarations.isEmpty {
                    // Pre-process the declarations by splitting text fragments apart to increase legibility
                    let mainDeclaration = declaration.declarationFragments.flatMap(preProcessFragment(_:))
                    let processedOverloadDeclarations = overloadDeclarations.map({ ($0.declaration.flatMap(preProcessFragment(_:)), $0.reference) })
                    let preProcessedDeclarations = [mainDeclaration] + processedOverloadDeclarations.map(\.0)

                    // Collect the "common fragments" so we can highlight the ones that are different
                    // in each declaration
                    let commonFragments = longestCommonSubsequence(preProcessedDeclarations)

                    renderedTokens = translateDeclaration(mainDeclaration, commonFragments: commonFragments)
                    otherDeclarations = renderOtherDeclarationsTokens(
                        from: processedOverloadDeclarations,
                        displayIndex: overloads.displayIndex,
                        commonFragments: commonFragments)
                } else {
                    renderedTokens = declaration.declarationFragments.map(translateFragment)
                    otherDeclarations = nil
                }

                let platformNames = platforms.sorted { (lhs, rhs) -> Bool in
                    guard let lhsValue = lhs, let rhsValue = rhs else {
                        return lhs == nil
                    }
                    return lhsValue.rawValue < rhsValue.rawValue
                }

                declarations.append(
                    DeclarationRenderSection(
                        languages: [trait.interfaceLanguage ?? renderNodeTranslator.identifier.sourceLanguage.id],
                        platforms: platformNames,
                        tokens: renderedTokens,
                        otherDeclarations: otherDeclarations
                    )
                )
            }

            if let alternateDeclarations = symbol.alternateDeclarationVariants[trait] {
                for pair in alternateDeclarations {
                    let (platforms, decls) = pair
                    for alternateDeclaration in decls {
                        let renderedTokens = alternateDeclaration.declarationFragments.map(translateFragment)

                        let platformNames = platforms
                            .compactMap { $0 }
                            .sorted(by: \.rawValue)

                        declarations.append(
                            DeclarationRenderSection(
                                languages: [trait.interfaceLanguage ?? renderNodeTranslator.identifier.sourceLanguage.id],
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
