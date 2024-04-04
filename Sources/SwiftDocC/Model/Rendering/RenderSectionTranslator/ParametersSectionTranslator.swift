/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's parameters into a render node's Parameters section.
struct ParametersSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.parametersSectionVariants
        ) { _, parameters in
            guard !parameters.parameters.isEmpty else { return nil }
            
            return ParametersRenderSection(
                parameters: parameters.parameters
                    .map { parameter in
                        let parameterContent = renderNodeTranslator.visitMarkupContainer(
                            MarkupContainer(parameter.contents)
                        ) as! [RenderBlockContent]
                        return ParameterRenderSection(name: parameter.name, content: parameterContent)
                    }
            )
        }
    }
}
