/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

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
                
                let renderedTokens = declaration.declarationFragments.map { token -> DeclarationRenderSection.Token in
                    
                    // Create a reference if one found
                    var reference: ResolvedTopicReference?
                    if let preciseIdentifier = token.preciseIdentifier,
                       let resolved = renderNodeTranslator.context.symbolIndex[preciseIdentifier]?.reference {
                        reference = resolved
                        
                        // Add relationship to render references
                        renderNodeTranslator.collectedTopicReferences.append(resolved)
                    }
                    
                    // Add the declaration token
                    return DeclarationRenderSection.Token(fragment: token, identifier: reference?.absoluteString)
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
                        tokens: renderedTokens
                    )
                )
            }
        
            return DeclarationsRenderSection(declarations: declarations)
        }
    }
}
