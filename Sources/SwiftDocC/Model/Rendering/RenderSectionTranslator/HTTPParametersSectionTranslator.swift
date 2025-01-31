/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2024 Apple Inc. and the Swift project authors
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
        guard let httpParametersSection = symbol.httpParametersSection else { return nil }
        
        // Filter out keys that aren't backed by a symbol or have a different source than requested
        let filteredParameters = httpParametersSection.parameters.filter { $0.symbol != nil && $0.source != nil && $0.source == parameterSource.rawValue }
        guard !filteredParameters.isEmpty else { return nil }
        
        return VariantCollection(defaultValue: CodableContentSection(
            RESTParametersRenderSection(
                title: "\(parameterSource.rawValue.capitalized) Parameters",
                parameters: filteredParameters.map { renderNodeTranslator.createRenderProperty(name: $0.name, contents: $0.contents, required: $0.required, symbol: $0.symbol) },
                source: parameterSource
            )
        ))
    }
}
