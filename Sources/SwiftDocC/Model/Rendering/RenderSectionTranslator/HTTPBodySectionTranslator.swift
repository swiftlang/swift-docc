/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's request body into a render node's body section.
struct HTTPBodySectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.httpBodySectionVariants
        ) { _, httpBodySection -> RenderSection? in
            guard let symbol = httpBodySection.body.symbol else { return nil }
            
            let responseContent = renderNodeTranslator.visitMarkupContainer(
                MarkupContainer(httpBodySection.body.contents)
            ) as! [RenderBlockContent]
            
            let renderedTokens = symbol.declarationFragments?.map { token -> DeclarationRenderSection.Token in
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
            
            return RESTBodyRenderSection(
                title: "HTTP Body",
                mimeType: httpBodySection.body.mediaType,
                bodyContentType: renderedTokens ?? [],
                content: responseContent,
                parameters: nil // TODO: Support body parameters
            )
        }
    }
}
