/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Markdown

/// An item in a markdown unordered list that defines a term.
///
/// A list item defines a term when its first block is a paragraph that starts with the case-insensitive keyword "term", followed by a space or the end of the line, and has a ":" in its text.
/// The term is the content between the keyword and the first ":", and the definition is the content after it, followed by the list item's other blocks.
/// For example, this list item defines the term "Foo":
///
/// ```md
/// - term Foo: The start of the definition.
///
///   A second paragraph of the definition.
/// ```
///
/// Only text is searched for the keyword and the ":".
/// Other inline markup, such as code voice, emphasis, or links, becomes part of the term or the definition unmodified.
package struct TermListItem {
    /// The inline markup of the term.
    package var term: [any InlineMarkup]
    
    /// The block markup of the definition.
    ///
    /// The first block is a paragraph with the inline markup after the ":", followed by the list item's other blocks.
    package var definition: [any BlockMarkup]
    
    private static let keyword = "term"
    
    /// Creates a term-list item from a markdown list item, or returns `nil` if the list item doesn't define a term.
    init?(_ listItem: ListItem) {
        guard let paragraph = listItem.child(at: 0) as? Paragraph,
              let firstText = paragraph.child(at: 0) as? Text
        else {
            return nil
        }
        
        // Most list items don't define a term, so check for the keyword before creating new markup.
        let textFromKeyword = firstText.string.drop(while: \.isWhitespace)
        guard textFromKeyword.prefix(Self.keyword.count).lowercased() == Self.keyword else {
            return nil
        }
        var textAfterKeyword = textFromKeyword.dropFirst(Self.keyword.count)
        
        // The keyword is separated from the term by a space or by the end of the line.
        var inlines = Array(paragraph.inlineChildren.dropFirst())
        if textAfterKeyword.first == " " {
            textAfterKeyword.removeFirst()
        } else if textAfterKeyword.isEmpty, inlines.first is SoftBreak {
            inlines.removeFirst()
        } else {
            return nil
        }
        
        // Whitespace between the keyword and other inline markup, like code voice, isn't part of the term.
        if !textAfterKeyword.allSatisfy(\.isWhitespace) {
            inlines.insert(Text(String(textAfterKeyword)), at: 0)
        }
        
        for (index, inline) in inlines.enumerated() {
            guard let text = (inline as? Text)?.string, let separator = text.firstIndex(of: ":") else {
                continue
            }
            // Whitespace around the ":" isn't part of the term or the definition.
            let termText = text[..<separator].lastIndex(where: { !$0.isWhitespace }).map { text[...$0] } ?? ""
            let definitionText = text[text.index(after: separator)...].drop(while: \.isWhitespace)
            
            var term = Array(inlines[..<index])
            if termText.isEmpty {
                // The ":" can be on the line after the term.
                while let last = term.last, last is SoftBreak || last is LineBreak {
                    term.removeLast()
                }
            } else {
                term.append(Text(String(termText)))
            }
            
            var definitionInlines = inlines[(index + 1)...]
            if definitionText.isEmpty {
                // The definition can start on the line after the ":".
                definitionInlines = definitionInlines.drop(while: { $0 is SoftBreak || $0 is LineBreak })
            } else {
                definitionInlines.insert(Text(String(definitionText)), at: definitionInlines.startIndex)
            }
            
            self.term = term
            self.definition = [Paragraph(definitionInlines)]
            self.definition.append(contentsOf: listItem.blockChildren.dropFirst())
            return
        }
        return nil
    }
}

extension UnorderedList {
    /// Returns the list's items as term-list items, or `nil` if the list is empty or any of its items doesn't define a term.
    package func termListItems() -> [TermListItem]? {
        var termListItems = [TermListItem]()
        termListItems.reserveCapacity(childCount)
        for listItem in listItems {
            guard let termListItem = TermListItem(listItem) else {
                return nil
            }
            termListItems.append(termListItem)
        }
        return termListItems.isEmpty ? nil : termListItems
    }
}
