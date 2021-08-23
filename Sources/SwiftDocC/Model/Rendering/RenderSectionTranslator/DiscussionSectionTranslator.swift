/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SymbolKit

/// Translates a symbol's discussion into a render node's Discussion section.
struct DiscussionSectionTranslator: RenderSectionTranslator {
    func translateSection(
        for symbol: Symbol,
        renderNode: inout RenderNode,
        renderNodeTranslator: inout RenderNodeTranslator
    ) -> VariantCollection<CodableContentSection?>? {
        translateSectionToVariantCollection(
            documentationDataVariants: symbol.discussionVariants
        ) { _, discussion in
            guard let discussionContent = renderNodeTranslator.visitMarkupContainer(MarkupContainer(discussion.content)) as? [RenderBlockContent],
                  !discussionContent.isEmpty
            else {
                return nil
            }
            
            let title: String?
            if let first = discussionContent.first, case RenderBlockContent.heading = first {
                // There's already an authored heading. Don't add another heading.
                title = nil
            } else {
                switch renderNode.metadata.role.flatMap(RenderMetadata.Role.init) {
                case .dictionarySymbol?, .restRequestSymbol?:
                    title = "Discussion"
                case .symbol?:
                    title = symbol.kind.identifier.swiftSymbolCouldHaveChildren ? "Overview" : "Discussion"
                default:
                    title = "Overview"
                }
            }
                
            return ContentRenderSection(kind: .content, content: discussionContent, heading: title)
        }
    }
}
