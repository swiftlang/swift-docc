/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
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
        guard let httpBodySection = symbol.httpBodySection,
              let symbol = httpBodySection.body.symbol,
              let mediaType = httpBodySection.body.mediaType
        else { return nil }
            
        // Filter out parameters that aren't backed by a symbol or don't have a "body" source.
        let filteredParameters = httpBodySection.body.parameters.filter { $0.symbol != nil && $0.source == "body" }
        
        let bodyContent = renderNodeTranslator.visitMarkupContainer(
            MarkupContainer(httpBodySection.body.contents)
        ) as! [RenderBlockContent]
        
        let renderedTokens = symbol.declarationFragments?.map { token -> DeclarationRenderSection.Token in
            // Create a reference if one found
            let reference: ResolvedTopicReference?
            if let preciseIdentifier = token.preciseIdentifier,
               let resolved = renderNodeTranslator.context.localOrExternalReference(symbolID: preciseIdentifier)
            {
                reference = resolved
                
                // Add relationship to render references
                renderNodeTranslator.collectedTopicReferences.append(resolved)
            } else {
                reference = nil
            }
            
            // Add the declaration token
            return DeclarationRenderSection.Token(fragment: token, identifier: reference?.absoluteString)
        }
        
        return VariantCollection(defaultValue: CodableContentSection(
            RESTBodyRenderSection(
                title: "HTTP Body",
                mimeType: mediaType,
                bodyContentType: renderedTokens ?? [],
                content: bodyContent,
                parameters: filteredParameters.map { renderNodeTranslator.createRenderProperty(name: $0.name, contents: $0.contents, required: $0.required, symbol: $0.symbol)  }
            )
        ))
    }
}
