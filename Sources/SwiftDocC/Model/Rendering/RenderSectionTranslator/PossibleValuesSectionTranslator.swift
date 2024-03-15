/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's possible values into a render node's Possible Values section.
struct PossibleValuesSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.possibleValuesSectionVariants
        ) { _, possibleValuesSection in
            // Render section only if values were listed in the markdown
            // and there are value defined in the symbol graph.
            guard !possibleValuesSection.documentedValues.isEmpty else { return nil }
            guard !possibleValuesSection.definedValues.isEmpty else { return nil }
            
            // Build a lookup table of the documented values
            var documentationLookup = [String: PossibleValue]()
            possibleValuesSection.documentedValues.forEach { documentationLookup[$0.value] = $0 }

            // Generate list of possible values for rendering from the full list of defined values,
            // pulling in any documentation from the documented values list when available.
            let renderedValues = possibleValuesSection.definedValues.map {
                let valueString = String($0)
                let possibleValue = documentationLookup[valueString] ?? PossibleValue(value: valueString, contents: [])
                let valueContent = renderNodeTranslator.visitMarkupContainer(
                    MarkupContainer(possibleValue.contents)
                ) as! [RenderBlockContent]
                return PossibleValuesRenderSection.NamedValue(name: possibleValue.value, content: valueContent)
            }
            
            return PossibleValuesRenderSection(
                title: PossibleValuesSection.title,
                values: renderedValues
            )
        }
    }
}
