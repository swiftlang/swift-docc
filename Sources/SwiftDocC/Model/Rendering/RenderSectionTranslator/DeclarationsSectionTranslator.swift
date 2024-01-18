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

            func translateFragment(_ fragment: SymbolGraph.Symbol.DeclarationFragments.Fragment) -> DeclarationRenderSection.Token {
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
                return DeclarationRenderSection.Token(fragment: fragment, identifier: reference?.absoluteString)
            }

            var declarations = [DeclarationRenderSection]()
            for pair in declaration {
                let (platforms, declaration) = pair
                
                let renderedTokens = declaration.declarationFragments.map(translateFragment)

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
                        tokens: renderedTokens
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
