/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

struct MentionsSectionTranslator: RenderSectionTranslator {
    var symbolReference: ResolvedTopicReference
    init(referencingSymbol symbolReference: ResolvedTopicReference) {
        self.symbolReference = symbolReference
    }

    func translateSection(for symbol: Symbol, renderNode: inout RenderNode, renderNodeTranslator: inout RenderNodeTranslator) -> VariantCollection<CodableContentSection?>? {
        guard FeatureFlags.current.isMentionedInEnabled else {
            return nil
        }

        let mentions = renderNodeTranslator.context.articleSymbolMentions.articlesMentioning(symbolReference)
        guard !mentions.isEmpty else {
            return nil
        }

        renderNodeTranslator.collectedTopicReferences.append(contentsOf: mentions)

        let section = MentionsRenderSection(mentions: mentions.map { $0.url })
        return VariantCollection(defaultValue: CodableContentSection(section))
    }
}
