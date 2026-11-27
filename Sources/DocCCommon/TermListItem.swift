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
/// A list item defines a term when its first block is a paragraph that starts with the case-insensitive keyword "term", followed by a space or a soft line break, and has a ":" in its text.
/// The term is the content between the keyword and the first ":", and the definition is the content after it, followed by the list item's other blocks.
/// For example, this list item defines the term "Foo":
///
/// ```md
/// - term Foo: The start of the definition.
///
///   A second paragraph of the definition.
/// ```
///
/// The keyword and the ":" only count when they're in text.
/// Other inline markup, such as code voice, emphasis, or links, becomes part of the term or the definition unmodified.
package struct TermListItem {
    /// A paragraph with the inline markup of the term.
    package var term: Paragraph
    
    /// The block markup of the definition.
    ///
    /// The first block is a paragraph with the inline markup after the ":", followed by the list item's other blocks.
    package var definition: [any BlockMarkup]
    
    private static let keyword = "term"
    
    /// Creates a term-list item from a markdown list item.
    ///
    /// Returns `nil` if the list item doesn't define a term.
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
        
        // The keyword is separated from the term by a space or by a soft line break.
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
        
        guard let separatorIndex = inlines.firstIndex(where: { ($0 as? Text)?.string.contains(":") == true }),
              let text = (inlines[separatorIndex] as? Text)?.string,
              let separator = text.firstIndex(of: ":")
        else {
            return nil
        }
        
        // Whitespace around the ":" isn't part of the term or the definition.
        let termText = text[..<separator].droppingTrailingWhitespace()
        let definitionText = text[text.index(after: separator)...].drop(while: \.isWhitespace)
        
        var term = Array(inlines[..<separatorIndex])
        if termText.isEmpty {
            // The ":" can be on the line after the term.
            while let last = term.last, last.isLineBreak {
                term.removeLast()
            }
        } else {
            term.append(Text(String(termText)))
        }
        
        var definitionInlines = inlines[(separatorIndex + 1)...]
        if definitionText.isEmpty {
            // The definition can start on the line after the ":".
            definitionInlines = definitionInlines.drop(while: \.isLineBreak)
        } else {
            definitionInlines.insert(Text(String(definitionText)), at: definitionInlines.startIndex)
        }
        
        self.term = Paragraph(term)
        self.definition = [Paragraph(definitionInlines)] + listItem.blockChildren.dropFirst()
    }
}

/// A run of consecutive list items that either all define terms or all don't.
package enum TermListRun {
    /// A run of consecutive list items that don't define terms.
    case otherItems([ListItem])
    
    /// A run of consecutive list items that define terms.
    case termItems([TermListItem])
}

extension UnorderedList {
    /// Splits the list's items into runs of term-list items and runs of other items.
    ///
    /// The runs keep the list's items in their original order.
    /// A non-empty list where every item defines a term, or where no item does, is a single run.
    package func termListRuns() -> [TermListRun] {
        var runs: [TermListRun] = []
        var otherItems: [ListItem] = []
        var termItems: [TermListItem] = []
        
        for listItem in listItems {
            if let termItem = TermListItem(listItem) {
                if !otherItems.isEmpty {
                    runs.append(.otherItems(otherItems))
                    otherItems.removeAll()
                }
                termItems.append(termItem)
            } else {
                if !termItems.isEmpty {
                    runs.append(.termItems(termItems))
                    termItems.removeAll()
                }
                otherItems.append(listItem)
            }
        }
        
        if !otherItems.isEmpty {
            runs.append(.otherItems(otherItems))
        }
        if !termItems.isEmpty {
            runs.append(.termItems(termItems))
        }
        return runs
    }
}

private extension Markup {
    /// A Boolean value that indicates whether this markup is a soft or hard line break.
    var isLineBreak: Bool {
        self is SoftBreak || self is LineBreak
    }
}

private extension Substring {
    /// Returns this substring without its trailing whitespace.
    func droppingTrailingWhitespace() -> Substring {
        guard let lastNonWhitespace = lastIndex(where: { !$0.isWhitespace }) else {
            return self[startIndex..<startIndex]
        }
        return self[...lastNonWhitespace]
    }
}
