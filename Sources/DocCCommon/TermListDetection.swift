/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An inline element type that term-list detection can work with.
///
/// Term-list detection works on one list item at a time and only inspects the item's first paragraph:
///
/// 1. A renderer calls ``detectedTermListItem()`` on the inline elements of each list item's first paragraph.
///    If they start with the "term" keyword and contain a ":" separator, the result is the term and the start of the definition.
/// 2. The renderer completes the definition by appending the list item's remaining blocks, without inspecting them.
/// 3. The renderer calls ``termListRuns(detectingTermsWith:)`` to split the list's items into consecutive term lists and other lists.
///
/// For example, in this list item the term is "Foo", and the definition is "The start of the definition." followed by the second paragraph:
///
/// ```md
/// - term Foo: The start of the definition.
///
///   A second paragraph.
/// ```
///
/// Term-list detection only inspects plain text elements.
/// Other kinds of inline elements, such as code voice, emphasis, or links, become part of the term or the definition unmodified.
package protocol TermListDetectableInline {
    /// The element's plain text, or `nil` if the element is anything other than plain text.
    var termListPlainText: String? { get }
    
    /// Creates a plain text element with the given text.
    ///
    /// Term-list detection uses this to create the elements for the text before and after the ":" separator,
    /// and to combine contiguous plain text elements into one.
    ///
    /// - Parameter termListPlainText: The text of the new element.
    init(termListPlainText: String)
}

/// The term and the start of the definition of a term-list item, which both come from the list item's first paragraph.
package struct DetectedTermListItem<Inline: TermListDetectableInline> {
    /// The inline elements of the term, with the term keyword removed.
    package var term: [Inline]
    
    /// The inline elements that come after the separator in the list item's first paragraph.
    ///
    /// These elements are the start of the definition. The definition also includes any blocks that follow the first paragraph in the list item.
    package var definitionFirstParagraph: [Inline]
}

/// The keyword that a term-list item starts with, ignoring case. It's followed by a space in the markup.
private let termKeyword = "term"

extension Collection where Element: TermListDetectableInline {
    /// Splits the inline elements of a list item's first paragraph into a term and the start of a definition, if they indicate a term-list item.
    ///
    /// The first paragraph of a list item indicates a term-list item if it starts with the case-insensitive keyword "term ",
    /// ignoring any leading whitespace, and contains a ":" separator in a plain text element.
    /// The term is the content between the keyword and the separator, and the definition starts with the content after the separator.
    /// For example, the first paragraph of `- term Foo: A description of foo.` has the term "Foo" and the definition "A description of foo.".
    ///
    /// If the term or the start of the definition is empty, it consists of a single empty plain text element.
    ///
    /// - Returns: The term and the start of the definition, or `nil` if the inline elements don't indicate a term-list item.
    package func detectedTermListItem() -> DetectedTermListItem<Element>? {
        // Most list items aren't term-list items, so check the first element before combining any text.
        // If it has fewer non-whitespace characters than the keyword, the keyword could continue in the next element.
        guard let firstText = first?.termListPlainText else {
            return nil
        }
        let leadingCharacters = firstText.drop(while: \.isWhitespace).prefix(termKeyword.count)
        guard leadingCharacters.count < termKeyword.count || leadingCharacters.lowercased() == termKeyword else {
            return nil
        }
        
        // A run of text can be split across several plain text elements, for example by soft line breaks.
        var inlines = collapsingContiguousTextElements()
        guard let textAfterKeyword = inlines.first?.termListPlainText?.removingTermKeyword() else {
            return nil
        }
        if textAfterKeyword.isEmpty {
            inlines.removeFirst()
        } else {
            inlines[0] = Element(termListPlainText: textAfterKeyword)
        }
        
        let separator: Character = ":"
        for (index, inline) in zip(inlines.indices, inlines) {
            guard let text = inline.termListPlainText, let separatorIndex = text.firstIndex(of: separator) else {
                continue
            }
            let termText = String(text[..<separatorIndex]).removingTrailingWhitespace()
            let definitionText = String(text[text.index(after: separatorIndex)...]).removingLeadingWhitespace()
            
            var term = Array(inlines[..<index])
            if !termText.isEmpty {
                term.append(Element(termListPlainText: termText))
            }
            var definition = definitionText.isEmpty ? [] : [Element(termListPlainText: definitionText)]
            definition += inlines[(index + 1)...]
            
            return DetectedTermListItem(
                term: term.isEmpty ? [Element(termListPlainText: "")] : term,
                definitionFirstParagraph: definition.isEmpty ? [Element(termListPlainText: "")] : definition
            )
        }
        return nil
    }
    
    private func collapsingContiguousTextElements() -> [Element] {
        var result = [Element]()
        var pendingText = ""
        for inline in self {
            if let text = inline.termListPlainText {
                pendingText += text
                continue
            }
            if !pendingText.isEmpty {
                result.append(Element(termListPlainText: pendingText))
                pendingText = ""
            }
            result.append(inline)
        }
        if !pendingText.isEmpty {
            result.append(Element(termListPlainText: pendingText))
        }
        return result
    }
}

/// A run of consecutive list items of the same kind.
package enum TermListRun<PlainItem, TermItem> {
    /// A run of consecutive list items that aren't term items.
    case plainItems([PlainItem])
    
    /// A run of consecutive term items.
    case termItems([TermItem])
}

extension Sequence {
    /// Splits the elements into consecutive runs of term items and plain items, preserving order.
    ///
    /// - Parameter detect: A closure that returns the term item for an element, or `nil` if the element isn't a term item.
    /// - Returns: The runs of consecutive term items and plain items, in the order of the elements.
    package func termListRuns<TermItem>(detectingTermsWith detect: (Element) -> TermItem?) -> [TermListRun<Element, TermItem>] {
        var runs = [TermListRun<Element, TermItem>]()
        var runningPlainItems = [Element]()
        var runningTermItems = [TermItem]()
        
        for item in self {
            if let termItem = detect(item) {
                if !runningPlainItems.isEmpty {
                    runs.append(.plainItems(runningPlainItems))
                    runningPlainItems.removeAll()
                }
                runningTermItems.append(termItem)
            } else {
                if !runningTermItems.isEmpty {
                    runs.append(.termItems(runningTermItems))
                    runningTermItems.removeAll()
                }
                runningPlainItems.append(item)
            }
        }
        
        if !runningPlainItems.isEmpty {
            runs.append(.plainItems(runningPlainItems))
        }
        if !runningTermItems.isEmpty {
            runs.append(.termItems(runningTermItems))
        }
        return runs
    }
}

private extension String {
    /// Returns the string without a case-insensitive "term " keyword that follows any leading whitespace,
    /// an empty string if only spaces and tabs follow the keyword, or `nil` if the string doesn't start with the keyword.
    func removingTermKeyword() -> String? {
        let keyword = termKeyword + " "
        let keywordStart = firstIndex(where: { !$0.isWhitespace }) ?? endIndex
        guard let keywordEnd = index(keywordStart, offsetBy: keyword.count, limitedBy: endIndex),
              self[keywordStart ..< keywordEnd].lowercased() == keyword
        else {
            return nil
        }
        guard !self[keywordEnd...].unicodeScalars.allSatisfy({ $0 == "\t" || $0.properties.generalCategory == .spaceSeparator }) else {
            return ""
        }
        var text = self
        text.removeSubrange(keywordStart ..< keywordEnd)
        return text
    }
}
