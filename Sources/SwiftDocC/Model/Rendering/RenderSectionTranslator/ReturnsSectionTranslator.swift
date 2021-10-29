/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Translates a symbol's return data into a render node's Returns section.
struct ReturnsSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.returnsSectionVariants
        ) { _, returns in
            guard !returns.content.isEmpty,
                  let returnsContent = renderNodeTranslator.visitMarkupContainer(
                    MarkupContainer(returns.content)
                  ) as? [RenderBlockContent]
            else {
                return nil
            }
            
            return ContentRenderSection(kind: .content, content: returnsContent, heading: "Return Value")
        }
    }
}
