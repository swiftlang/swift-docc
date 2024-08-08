/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit
import Markdown

/// Translates a symbol's possible values into a render nodes's section.
struct PossibleValuesSectionTranslator: RenderSectionTranslator {
    
    func translateSection(for symbol: Symbol, renderNode: inout RenderNode, renderNodeTranslator: inout RenderNodeTranslator) -> VariantCollection<CodableContentSection?>? {
        guard (symbol.mixinsVariants.allValues.mapFirst(where: { mixin in
            mixin.variant[SymbolGraph.Symbol.AllowedValues.mixinKey] as? SymbolGraph.Symbol.AllowedValues
        }) != nil) else {
            return nil
        }
        
        
        return translateSectionToVariantCollection(
               documentationDataVariants: symbol.possibleValuesSectionVariants
        ) { _, possibleValuesSection in
            // Render the possible values with the matching description from the
            // possible values listed in the markdown.
            return PossibleValuesRenderSection(
                title: PossibleValuesSection.title,
                values: possibleValuesSection.possibleValues.map { possibleValueTag in
                    let valueContent = renderNodeTranslator.visitMarkupContainer(
                        MarkupContainer(possibleValueTag.contents)
                    ) as! [RenderBlockContent]
                    return PossibleValuesRenderSection.NamedValue(
                        name: possibleValueTag.value,
                        content: valueContent
                    )
                }
            )
        }
    }
    
}

