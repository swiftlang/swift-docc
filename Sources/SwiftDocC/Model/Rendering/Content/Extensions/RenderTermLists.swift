/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

private import DocCCommon

extension RenderInlineContent: TermListDetectableInline {
    package var termListPlainText: String? {
        if case .text(let text) = self { text } else { nil }
    }
    
    package init(termListPlainText: String) {
        self = .text(termListPlainText)
    }
}

extension Collection<RenderBlockContent.ListItem> {
    /// Splits these list items into consecutive unordered lists and term lists, preserving their order.
    ///
    /// - Returns: A `.termList` for each run of consecutive term-list items and an `.unorderedList` for each run of other list items.
    func unorderedAndTermLists() -> [any RenderContent] {
        termListRuns(detectingTermsWith: RenderBlockContent.TermListItem.init).map { run in
            switch run {
            case .plainItems(let items):
                RenderBlockContent.unorderedList(.init(items: items))
            case .termItems(let items):
                RenderBlockContent.termList(.init(items: items))
            }
        }
    }
}

extension RenderBlockContent.TermListItem {
    /// Creates a term-list item from the given list item, or returns `nil` if the list item doesn't indicate a term-list item.
    init?(_ listItem: RenderBlockContent.ListItem) {
        guard case let .paragraph(firstParagraph) = listItem.content.first,
              let detected = firstParagraph.inlineContent.detectedTermListItem()
        else {
            return nil
        }
        
        let term = RenderBlockContent.TermListItem.Term(inlineContent: detected.term)
        let definition = RenderBlockContent.TermListItem.Definition(
            content: [.paragraph(.init(inlineContent: detected.definitionFirstParagraph))] + listItem.content.dropFirst()
        )
        self = RenderBlockContent.TermListItem(term: term, definition: definition)
    }
}
