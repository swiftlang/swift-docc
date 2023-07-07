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
                items: filteredKeys.map { renderNodeTranslator.createRenderProperty(name: $0.name, contents: $0.contents, required: $0.required, symbol: $0.symbol) }
            )
        }
    }
}
