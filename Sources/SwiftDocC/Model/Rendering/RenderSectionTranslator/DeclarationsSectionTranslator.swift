/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.declarationVariants
        ) { trait, declaration -> RenderSection? in
            guard !declaration.isEmpty else {
                return nil
            }
            
            var declarations = [DeclarationRenderSection]()
            for pair in declaration {
                let (platforms, declaration) = pair
                
                let platformNames = platforms.sorted { (lhs, rhs) -> Bool in
                    guard let lhsValue = lhs, let rhsValue = rhs else {
                        return lhs == nil
                    }
                    return lhsValue.rawValue < rhsValue.rawValue
                }
                
                let renderedTokens = renderDeclarationTokens(fragments: declaration.declarationFragments, renderNodeTranslator: &renderNodeTranslator)
                
                // If this symbol has overloads, render their declarations as well.
                // TODO: Handle objc overloads?
                let otherDeclarationsVariant = symbol.otherDeclarationsVariants[trait]
                let otherDeclarations = otherDeclarationsVariant?.map { overload -> DeclarationRenderSection.OtherDeclaration in
                    return DeclarationRenderSection.OtherDeclaration(
                            tokens: renderDeclarationTokens(fragments: overload.declaration[platforms]?.declarationFragments ?? [],
                                                            renderNodeTranslator: &renderNodeTranslator),
                            identifier: overload.identifier
                        )
                }
                
                declarations.append(
                    DeclarationRenderSection(
                        languages: [trait.interfaceLanguage ?? renderNodeTranslator.identifier.sourceLanguage.id],
                        platforms: platformNames,
                        tokens: renderedTokens,
                        otherDeclarations: otherDeclarations ?? []
                    )
                )
            }
        
            return DeclarationsRenderSection(declarations: declarations)
        }
    }
    
    func renderDeclarationTokens(fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment], renderNodeTranslator: inout RenderNodeTranslator)  -> [DeclarationRenderSection.Token] {
        
        return fragments.map { token in
            // Create a reference if one found
            var reference: ResolvedTopicReference?
            if let preciseIdentifier = token.preciseIdentifier,
               let resolved = renderNodeTranslator.context.symbolIndex[preciseIdentifier] {
                reference = resolved
                
                // Add relationship to render references
                renderNodeTranslator.collectedTopicReferences.append(resolved)
            }
            
            // Add the declaration token
            return DeclarationRenderSection.Token(fragment: token, identifier: reference?.absoluteString)
        }
    }
}
