/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's dictionary keys into a render node's Properties section.
struct DictionaryKeysSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.dictionaryKeysSectionVariants
        ) { _, dictionaryKeysSection in
            guard !dictionaryKeysSection.dictionaryKeys.isEmpty else { return nil }
            
            // Filter out keys that aren't backed by a symbol
            let filteredKeys = dictionaryKeysSection.dictionaryKeys.filter { $0.symbol != nil }
            
            return PropertiesRenderSection(
                title: DictionaryKeysSection.title,
                items: filteredKeys.map { translateDictionaryKey($0, &renderNodeTranslator) }
            )
        }
    }
    
    func translateDictionaryKey(_ key: DictionaryKey, _ renderNodeTranslator: inout RenderNodeTranslator) -> RenderProperty {
        let keyContent = renderNodeTranslator.visitMarkupContainer(
            MarkupContainer(key.contents)
        ) as! [RenderBlockContent]
        
        var required : Bool? = nil
        var renderedTokens : [DeclarationRenderSection.Token]? = nil
        var attributes : [RenderAttribute] = []
        var isReadOnly : Bool? = nil
        var deprecated: Bool? = nil
        var introducedVersion: String? = nil 
        
        if let keySymbol = key.symbol {
            required = key.required
            
            // Convert the dictionary key's declaration into section tokens
            if let fragments = keySymbol.declarationFragments {
                renderedTokens = fragments.map { token -> DeclarationRenderSection.Token in
                    
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
            }
                
            // Populate attributes
            if let constraint = keySymbol.defaultValue {
                attributes.append(RenderAttribute.default(String(constraint)))
            }
            if let constraint = keySymbol.minimum {
                attributes.append(RenderAttribute.minimum(String(constraint)))
            }
            if let constraint = keySymbol.maximum {
                attributes.append(RenderAttribute.maximum(String(constraint)))
            }
            if let constraint = keySymbol.minimumExclusive {
                attributes.append(RenderAttribute.minimumExclusive(String(constraint)))
            }
            if let constraint = keySymbol.maximumExclusive {
                attributes.append(RenderAttribute.maximumExclusive(String(constraint)))
            }
            if let constraint = keySymbol.allowedValues {
                attributes.append(RenderAttribute.allowedValues(constraint.map{String($0)}))
            }
            if let constraint = keySymbol.isReadOnly {
                isReadOnly = constraint
            }
            if let constraint = keySymbol.minimumLength {
                attributes.append(RenderAttribute.minimumLength(String(constraint)))
            }
            if let constraint = keySymbol.maximumLength {
                attributes.append(RenderAttribute.maximumLength(String(constraint)))
            }
            
            // Extract the availability information
            if let availabilityItems = keySymbol.availability, availabilityItems.count > 0 {
                availabilityItems.forEach { item in
                    if deprecated == nil && (item.isUnconditionallyDeprecated || item.deprecatedVersion != nil) {
                        deprecated = true
                    }
                    if let intro = item.introducedVersion, introducedVersion == nil {
                        introducedVersion = "\(intro)"
                    }
                }
            }
        }
        
        return RenderProperty(
            name: key.name,
            type: renderedTokens ?? [],
            typeDetails: nil,
            content: keyContent,
            attributes: attributes,
            mimeType: nil,
            required: required,
            deprecated: deprecated,
            readOnly: isReadOnly,
            introducedVersion: introducedVersion
        )
    }
}
