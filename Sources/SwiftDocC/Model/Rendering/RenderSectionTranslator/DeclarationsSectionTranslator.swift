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

            func translateFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment, highlightDiff: Bool? = nil) -> DeclarationRenderSection.Token {
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
                return DeclarationRenderSection.Token(fragment: fragment, identifier: reference?.absoluteString, highlightDiff: highlightDiff)
            }

            func translateFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment) -> DeclarationRenderSection.Token {
                return translateFragment(fragment, highlightDiff: nil)
            }

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

                return translatedDeclaration
            }

            typealias OverloadDeclaration = (declaration: [SymbolGraph.Symbol.DeclarationFragments.Fragment], reference: ResolvedTopicReference)

            func renderOtherDeclarationsTokens(
                from overloadDeclarations: [OverloadDeclaration],
                displayIndex: Int,
                commonFragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]
            ) -> DeclarationRenderSection.OtherDeclarations {
                var otherDeclarations = [DeclarationRenderSection.OtherDeclarations.Declaration]()

                for overloadDeclaration in overloadDeclarations {
                    var commonIndex = 0
                    var translatedDeclaration: [DeclarationRenderSection.Token] = []
                    for fragment in overloadDeclaration.declaration {
                        if commonIndex < commonFragments.count && fragment == commonFragments[commonIndex] {
                            // fragment is common to all declarations, render plain
                            translatedDeclaration.append(translateFragment(fragment))
                            commonIndex += 1
                        } else {
                            // fragment is unique to this declaration, render highlighted
                            translatedDeclaration.append(translateFragment(fragment, highlightDiff: true))
                        }
                    }
                    otherDeclarations.append(.init(
                        tokens: translatedDeclaration,
                        identifier: overloadDeclaration.reference.absoluteString))

                    // Add a topic reference to the overload
                    renderNodeTranslator.collectedTopicReferences.append(overloadDeclaration.reference)
                }

                return .init(declarations: otherDeclarations, displayIndex: displayIndex)
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
                    // Collect the "common fragments" so we can highlight the ones that are different
                    // in each declaration
                    // FIXME: Pre-process declarations to break up text fragments for better visual output
                    let commonFragments = longestCommonSubsequence([declaration.declarationFragments] + overloadDeclarations.map(\.declaration))

                    renderedTokens = translateDeclaration(declaration.declarationFragments, commonFragments: commonFragments)
                    otherDeclarations = renderOtherDeclarationsTokens(
                        from: overloadDeclarations,
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

/// Calculate the "longest common subsequence" of two sequences.
///
/// The longest common subsequence (LCS) of a set of sequences is the sequence of items that
/// appears in all the input sequences in the same order. For example given the sequences `ABAC`
/// and `CAACB`, the letters `AAC` appear in the same order in both of them, even though the letter
/// `B` interrupts the sequence in the first one.
fileprivate func longestCommonSubsequence<Element>(_ inputLHS: [Element], _ inputRHS: [Element]) -> [Element] where Element: Equatable {
    // Optimization: Trim out the elements that are common to both sequences so we can reduce the
    // number of required comparisons
    let commonPrefix = zip(inputLHS, inputRHS).prefix(while: { $0 == $1 }).map(\.0)
    let lhs = inputLHS.dropFirst(commonPrefix.count)
    let rhs = inputRHS.dropFirst(commonPrefix.count)

    if lhs.isEmpty || rhs.isEmpty {
        return commonPrefix
    }

    // "Longest common subsequence" is the underlying problem behind `diff` and other kinds of
    // sequence comparisons. The fundamental issue with trying a naive "running comparison" solution
    // is knowing how long a subsequence of differing tokens is, i.e. when to "rejoin" the sequences
    // together. The well-understood solution for two sequences follows a "dynamic programming"
    // style, creating a matrix of element-to-element comparisons and building the resulting
    // answer(s) from that.
    //
    // Here's an example, using the inputs from this function's doc comment. The built-up matrix
    // compares each element of one sequence with each element of the other sequence, marking which
    // pairs of elements are equal:
    //
    //   | A | B | A | C
    // -----------------
    // C |   |   |   | X
    // A | X |   | X |
    // A | X |   | X |
    // C |   |   |   | X
    // B |   | X |   |
    //
    // To construct the answer, the algorithm then walks the matrix row-wise from top to bottom,
    // following two rules:
    //
    // 1. If the two elements were not equal, take the longest sequence from either the cell above
    //    or the cell to the left. (Reading "off the edge" of the matrix yields an empty sequence.)
    //    If both sequences were the same length, take both of them.
    // 2. If the two elements were equal, take the sequence(s) from the cell diagonally up-left and
    //    append the element to them.
    //
    // When you have finished walking the matrix, the sequence(s) from the bottom-right cell are the
    // longest common subsequence(s) of the pair.
    //
    // When this algorithm is used to calculate an edit sequence from the left-column sequence to
    // the top-row sequence (e.g. using `diff`), "taking the sequence from the row above" represents
    // a deletion, and "taking the sequence from the cell to the left" represents an insertion. To
    // better reflect the output from a proper diff when deduplicating multiple result sequences,
    // this implementation proactively selects the "row above" sequence, which corresponds to
    // preferentially printing deletions before insertions.

    // In lieu of keeping the complete matrix of equal comparisons, store the intermediate sequences
    // and only save the "previous row" so we don't have to walk it back later.
    var previousRow: [[Element]] = .init(repeating: [], count: rhs.count)

    /// Fetches the element in the index before the given one, or an empty array if that would read out of bounds.
    func getPreviousOrDefault(_ array: [[Element]], index: Int) -> [Element] {
        if index == 0 {
            return []
        } else {
            return array[index - 1]
        }
    }

    /// Returns the longer sequence, or `lhs` if they are of equal length.
    func maxLength(_ lhs: [Element], _ rhs: [Element]) -> [Element] {
        if rhs.count > lhs.count {
            return rhs
        } else {
            return lhs
        }
    }

    // Iterate row-wise: compare all the elements in the first sequence.
    for lhsValue in lhs {
        var currentRow: [[Element]] = .init(repeating: [], count: rhs.count)
        // Iterate column-wise: with the indices and values from the second sequence, perform the comparison.
        for (rhsIndex, rhsValue) in rhs.enumerated() {
            if lhsValue == rhsValue {
                // If the values are equal, pull the sequence "diagonally up-left" from this coordinate,
                // and append the current element to it.
                currentRow[rhsIndex] = getPreviousOrDefault(previousRow, index: rhsIndex) + [lhsValue]
            } else {
                // If the values are not equal, pull the longer sequence from either the row above or
                // the column to the left. Short-circuit by preferring the "row-above" value in case
                // they're equal.
                currentRow[rhsIndex] = maxLength(previousRow[rhsIndex], getPreviousOrDefault(currentRow, index: rhsIndex))
            }
        }
        // Now that we've computed this comparison row, save it for the next iteration.
        previousRow = currentRow
    }

    return commonPrefix + previousRow.last!
}

/// Computes the "longest common subsequence" of a list of sequences.
fileprivate func longestCommonSubsequence<Element>(_ sequences: [[Element]]) -> [Element] where Element: Equatable {
    var resultSequence: [Element]? = nil

    // This function relies on the two-sequence LCS to expand to an arbitrary set of sequences. The
    // idea is effectively a `reduce1` without a default case. This does expand the worst-case time
    // complexity to nearly `L^N` comparisons, with `L` being the average length of the sequences,
    // and `N` being the number of sequences. In practice, since overloaded declarations tend to
    // share a common prefix (which is trimmed in the underlying implementation), and because this
    // is a rolling comparison against the calculated LCS, the actual number of comparisons is
    // likely to be less than that in the average case.
    for sequence in sequences {
        if let currentResult = resultSequence {
            resultSequence = longestCommonSubsequence(currentResult, sequence)
        } else {
            resultSequence = sequence
        }
    }
    return resultSequence ?? []
}
