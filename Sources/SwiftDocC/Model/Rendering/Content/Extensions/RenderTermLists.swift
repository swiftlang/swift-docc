/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import Foundation

protocol ListableItem {}
extension RenderBlockContent.ListItem: ListableItem {}
extension RenderBlockContent.TermListItem: ListableItem {}

extension Collection where Element == RenderBlockContent.ListItem {
    
    /// Detects term list items in a collection of list items and converts
    /// them to term list items for rendering while preserving non-term
    /// list items.
    ///
    /// - Returns: An array containing either a combination of `.unorderedList`
    ///   and `.termList` elements, entirely `.unorderedList` elements, or
    ///   entirely `.termList` elements. The order of the list items is
    ///   preserved from the order received.
    ///
    func unorderedAndTermLists() -> [RenderContent] {
        var contents = [RenderContent]()
        
        // Keep track of the recent list items that are of the same type
        var runningListItems = [ListableItem]()
        
        for item in self {
            
            // If this is a term list item
            if let termListItem = RenderBlockContent.TermListItem(item) {
                
                // If the previous list item was not a term list item
                if let previousItem = runningListItems.last, previousItem is RenderBlockContent.ListItem {
                    
                    // Create an unordered list with the previous unordered list items
                    // and clear out the list of recent items
                    contents.append(listWithItems(runningListItems))
                    runningListItems.removeAll()
                }
                runningListItems.append(termListItem)
            } else {
                
                // If the previous list item was a term list item
                if let previousItem = runningListItems.last, previousItem is RenderBlockContent.TermListItem {
                    
                    // Create a term list with the previous term list items
                    // and clear out the list of recent items
                    contents.append(listWithItems(runningListItems))
                    runningListItems.removeAll()
                }
                runningListItems.append(item)
            }
        }
        
        // Create a list with the items found at the end of the list
        if !runningListItems.isEmpty {
            contents.append(listWithItems(runningListItems))
        }
        return contents
    }
    
    /// Creates an unordered or term list from the given items.
    ///
    /// > Important: This will `fatalError` if the given items are not
    ///   list items.
    private func listWithItems(_ items: [ListableItem]) -> RenderContent {
        if let unorderedListItems = items as? [RenderBlockContent.ListItem] {
            return RenderBlockContent.unorderedList(.init(items: unorderedListItems))
        } else if let termListItems = items as? [RenderBlockContent.TermListItem] {
            return RenderBlockContent.termList(.init(items: termListItems))
        } else {
            fatalError()
        }
    }
}

extension RenderBlockContent.TermListItem {
    
    /// Creates a `TermListItem` from the given `ListItem` if
    /// the list item is deemed to be a term list item. If the
    /// given list item is not deemed to be a term list item, this
    /// returns `nil`.
    init?(_ listItem: RenderBlockContent.ListItem) {
        guard case let .paragraph(firstParagraph) = listItem.content.first else {
            // The first child of the list item wasn't a paragraph, so
            // don't continue checking to see if this is a term list item.
            return nil
        }
        let subsequentBlockContents = listItem.content.dropFirst()
        
        // Collapse any contiguous text elements before checking
        // for term indication
        let collapsedFirstParagraphInlines = firstParagraph.inlineContent.collapsingContiguousTextElements()
        
        let termDefinitionSeparator = ":"
        guard let (termInlines, firstDefinitionInlines) = collapsedFirstParagraphInlines.separatedForTermDefinition(separator: termDefinitionSeparator) else {
            // The inline elements in the first paragraph did not
            // contain term indicators
            return nil
        }
        
        let term = RenderBlockContent.TermListItem.Term(inlineContent: termInlines)
        
        // Use the definition contents from the first paragraph along
        // with the subsequent block elements in this list item as the
        // complete definition.
        let definition = RenderBlockContent.TermListItem.Definition(content: [RenderBlockContent.paragraph(.init(inlineContent: firstDefinitionInlines))] + subsequentBlockContents)

        self = RenderBlockContent.TermListItem(term: term, definition: definition)
    }
}

extension Collection where Element == RenderInlineContent {
    
    /// Separate the inline contents into the contents that should be used for the
    /// term and the contents that should be used for the definition.
    ///
    /// - Returns: A tuple contain the inline elements for the term and (first
    ///   set of inlines for) the definition, or `nil` if the inline elements
    ///   aren't indicated as a term definition pair.
    func separatedForTermDefinition(separator: String) -> (termInlines: [RenderInlineContent], definitionInlines: [RenderInlineContent])? {
        let termKeyword = "term "
        
        // Make sure this collection of inline contents starts with the
        // term keyword, ignoring any extra whitespace before the keyword
        guard case let .text(text) = first, text.lowercased().removingLeadingWhitespace().hasPrefix(termKeyword) else {
            return nil
        }
        
        var termInlines = [RenderInlineContent]()
        var definitionInlines = [RenderInlineContent]()
        var foundSeparator = false
        
        for inline in self {
            if foundSeparator {
                // All content after the separator should be considered
                // part of the definition
                definitionInlines.append(inline)
            } else if let (termInline, definitionInline) = inline.separatedForTermDefinition(separator: separator) {
                // Only accept the returned term and definition inline elements
                // if they are not empty
                if termInline != nil {
                    termInlines.append(termInline!)
                }
                if definitionInline != nil {
                    definitionInlines.append(definitionInline!)
                }
                foundSeparator = true
            } else {
                // All content before the separator and not including the
                // separator should be part of the term
                termInlines.append(inline)
            }
        }
        
        guard foundSeparator else {
            // Term indicators weren't found
            return nil
        }
        
        // Remove the keyword from the term inlines and drop the first inline if
        // removing the keyword produced an empty inline in its place
        let termInlinesKeywordRemoved: [RenderInlineContent]
        if let firstInlineRemovingKeyword = termInlines.first?.removingTermKeyword(termKeyword) {
            termInlinesKeywordRemoved = [firstInlineRemovingKeyword] + termInlines.dropFirst()
        } else {
            if termInlines.count == 1 {
                // Don't allow a term with no contents to have an empty
                // array of inline elements
                termInlinesKeywordRemoved = [RenderInlineContent.text("")]
            } else {
                termInlinesKeywordRemoved = Array(termInlines.dropFirst())
            }
        }
        
        if definitionInlines.isEmpty {
            // Don't allow a definition with no contents to have an empty
            // array of inline elements
            definitionInlines = [RenderInlineContent.text("")]
        }
        
        return (termInlines: termInlinesKeywordRemoved, definitionInlines: definitionInlines)
    }
    
    /// Collapse all inline elements that are of `text` type and are contiguous.
    /// This works around the issue of multiple inline elements in a row that are all
    /// `text` but rendered separately due to newline separation in the parsed markdown.
    func collapsingContiguousTextElements() -> [RenderInlineContent] {
        // Keep track of all inline contents which may include a combination of
        // plain text and other kinds of inline content.
        var inlines = [RenderInlineContent]()
        
        // Keep track of the recent contiguous plain text content
        var previousText = ""
        for inline in self {
            switch inline {
            case .text(let text):
                previousText += text
            default:
                // If this is not a text element but there was plain text content
                // before this element
                if !previousText.isEmpty {
                    // Create a plain text element with the recent plain text content
                    inlines.append(RenderInlineContent.text(previousText))
                    previousText = ""
                }
                inlines.append(inline)
            }
        }
        if !previousText.isEmpty {
            // Create a plain text element with the ending plain text content
            inlines.append(RenderInlineContent.text(previousText))
        }
        return inlines
    }
}

extension RenderInlineContent {
    
    /// Split an individual inline content into the content that should be included
    /// in the term and the content that should be included in the definition.
    ///
    /// - Returns: If this inline content contained the separator, a tuple is
    ///   returned. If there is non-empty content before the separator, the tuple
    ///   will contain a `termInline` content. If there is non-empty content after
    ///   the separator, the tuple will contain a `definitionInline` content. If
    ///   the inline content doesn't contain the separator, this returns `nil` instead
    ///   of a tuple.
    func separatedForTermDefinition(separator: String) -> (termInline: RenderInlineContent?, definitionInline: RenderInlineContent?)? {
        guard case .text(let text) = self, text.contains(separator) else {
            return nil
        }
        let components = text.components(separatedBy: separator)
        guard components.count > 1 else {
            return nil
        }
        
        // Use the content before the separator as part of the term, removing
        // any whitespace between the content and the separator
        let trimmedTermInline = RenderInlineContent.text(components.first!.removingTrailingWhitespace())
        
        // Use the content after the separator as part of the definition,
        // removing any whitespace between the content and the separator
        let trimmedDefinitionInline = RenderInlineContent.text(components.dropFirst().joined(separator: separator).removingLeadingWhitespace())
        
        // Only return content for the term if it is not empty
        let termInline = trimmedTermInline.plainText.isEmpty ? nil : trimmedTermInline
        
        // Only return content for the definition if it is not empty
        let definitionInline = trimmedDefinitionInline.plainText.isEmpty ? nil : trimmedDefinitionInline
        
        return (termInline: termInline, definitionInline: definitionInline)
    }
    
    /// A non-empty result of removing the first instance of the given
    /// keyword from the content's string, or `nil` if the result of removing the
    /// given keyword produced an empty string.
    func removingTermKeyword(_ keyword: String) -> Self? {
        guard case .text(let text) = self else {
            return self
        }
        guard text.trimmingCharacters(in: .whitespaces) != keyword.trimmingCharacters(in: .whitespaces) else {
            // The inline content is just the keyword so consider the result empty
            // so that it is ignored
            return nil
        }
        guard let keywordRange = text.lowercased().range(of: keyword.lowercased()) else {
            return self
        }
        // Remove the first occurrence of the keyword
        let newText = text.replacingCharacters(in: keywordRange, with: "")
        if newText.isEmpty {
            return nil
        } else {
            return RenderInlineContent.text(newText)
        }
    }
}

extension String {
    
    /// The result of removing whitespace from the beginning of the string.
    func removingLeadingWhitespace() -> String {
        var trimmedString = self
        while trimmedString.first?.isWhitespace == true {
            trimmedString = String(trimmedString.dropFirst())
        }
        return trimmedString
    }
    
    /// The result of removing whitespace from the end of the string.
    func removingTrailingWhitespace() -> String {
        var trimmedString = self
        while trimmedString.last?.isWhitespace == true {
            trimmedString = String(trimmedString.dropLast())
        }
        return trimmedString
    }
}
