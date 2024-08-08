/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// Translates a symbol's constraints and details into a render node's Attributes section.
struct AttributesSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.attributesVariants
        ) { _, attributes in
            
            func translateFragments(_ fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> [DeclarationRenderSection.Token] {
                return fragments.map { fragment in
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
            }
            
            let attributesRenderSection = AttributesRenderSection(
                title: "Attributes",
                attributes: attributes.compactMap { kind, attribute in
                    
                    switch (kind, attribute) {
                    case (.minimum, let value as SymbolGraph.AnyNumber):
                        return RenderAttribute.minimum(String(value))
                    case (.maximum, let value as SymbolGraph.AnyNumber):
                        return RenderAttribute.maximum(String(value))
                    case (.minimumExclusive, let value as SymbolGraph.AnyNumber):
                        return RenderAttribute.minimumExclusive(String(value))
                    case (.maximumExclusive, let value as SymbolGraph.AnyNumber):
                        return RenderAttribute.maximumExclusive(String(value))
                    case (.minimumLength, let value as Int):
                        return RenderAttribute.minimumLength(String(value))
                    case (.maximumLength, let value as Int):
                        return RenderAttribute.maximumLength(String(value))
                    case (.default, let value as SymbolGraph.AnyScalar):
                        return RenderAttribute.default(String(value))
                    case (.allowedTypes, let types as [SymbolGraph.Symbol.TypeDetail]):
                        let tokens = types.compactMap { $0.fragments.map(translateFragments) }
                        return RenderAttribute.allowedTypes(tokens)
                    case (.allowedValues, let values as [SymbolGraph.AnyScalar]):
                        let stringValues = values.map { String($0) }
                        if symbol.possibleValuesSectionVariants.allValues.isEmpty {
                            return RenderAttribute.allowedValues(stringValues)
                        }
                        return nil
                    default:
                        return nil
                    }
                    
                }.sorted { $0.title < $1.title }
            )
            guard let attributes = attributesRenderSection.attributes, !attributes.isEmpty else {
                return nil
            }
            
            return attributesRenderSection
        }
    }
    
    
}
