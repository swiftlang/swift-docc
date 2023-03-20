/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's request parameters into a render node's parameters section.
struct HTTPParametersSectionTranslator: RenderSectionTranslator {
    let parameterSource: RESTParameterSource
    
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.httpParametersSectionVariants
        ) { _, httpParametersSection in
            // Filter out keys that aren't backed by a symbol or have a different source than requested
            let filteredParameters = httpParametersSection.parameters.filter { $0.symbol != nil && $0.source != nil && $0.source == parameterSource.rawValue }
            
            if filteredParameters.isEmpty { return nil }
            
            return RESTParametersRenderSection(
                title: "\(parameterSource.rawValue.capitalized) Parameters",
                items: filteredParameters.map { translateParameter($0, &renderNodeTranslator) },
                source: parameterSource
            )
        }
    }
    
    func translateParameter(_ parameter: HTTPParameter, _ renderNodeTranslator: inout RenderNodeTranslator) -> RenderProperty {
        let parameterContent = renderNodeTranslator.visitMarkupContainer(
            MarkupContainer(parameter.contents)
        ) as! [RenderBlockContent]
        
        var required: Bool? = nil
        var renderedTokens: [DeclarationRenderSection.Token]? = nil
        var attributes: [RenderAttribute] = []
        var isReadOnly: Bool? = nil
        var deprecated: Bool? = nil
        var introducedVersion: String? = nil 
        
        if let parameterSymbol = parameter.symbol {
            required = parameter.required
            
            // Convert the dictionary key's declaration into section tokens
            if let fragments = parameterSymbol.declarationFragments {
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
            if let constraint = parameterSymbol.defaultValue {
                attributes.append(RenderAttribute.default(String(constraint)))
            }
            if let constraint = parameterSymbol.minimum {
                attributes.append(RenderAttribute.minimum(String(constraint)))
            }
            if let constraint = parameterSymbol.maximum {
                attributes.append(RenderAttribute.maximum(String(constraint)))
            }
            if let constraint = parameterSymbol.minimumExclusive {
                attributes.append(RenderAttribute.minimumExclusive(String(constraint)))
            }
            if let constraint = parameterSymbol.maximumExclusive {
                attributes.append(RenderAttribute.maximumExclusive(String(constraint)))
            }
            if let constraint = parameterSymbol.allowedValues {
                attributes.append(RenderAttribute.allowedValues(constraint.map{String($0)}))
            }
            if let constraint = parameterSymbol.isReadOnly {
                isReadOnly = constraint
            }
            if let constraint = parameterSymbol.minimumLength {
                attributes.append(RenderAttribute.minimumLength(String(constraint)))
            }
            if let constraint = parameterSymbol.maximumLength {
                attributes.append(RenderAttribute.maximumLength(String(constraint)))
            }
            
            // Extract the availability information
            if let availabilityItems = parameterSymbol.availability, availabilityItems.count > 0 {
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
            name: parameter.name,
            type: renderedTokens ?? [],
            typeDetails: nil,
            content: parameterContent,
            attributes: attributes,
            mimeType: nil,
            required: required,
            deprecated: deprecated,
            readOnly: isReadOnly,
            introducedVersion: introducedVersion
        )
    }
}
