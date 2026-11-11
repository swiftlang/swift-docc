/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension Collection<RenderInlineContent> {
    
    /// Returns the inline content of a term, or of the start of a term's definition, with contiguous text elements combined into one.
    ///
    /// If there's no inline content, this returns a single empty text element instead.
    func termListInlineContent() -> [RenderInlineContent] {
        let inlines = collapsingContiguousTextElements()
        return inlines.isEmpty ? [.text("")] : inlines
    }
    
    /// Collapse all inline elements that are of `text` type and are contiguous.
    /// This works around the issue of multiple inline elements in a row that are all
    /// `text` but rendered separately due to newline separation in the parsed markdown.
    private func collapsingContiguousTextElements() -> [RenderInlineContent] {
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

extension String {
    /// Returns a new string made by removing whitespace from the beginning of the string.
    func removingLeadingWhitespace() -> String {
        guard let index = self.firstIndex(where: { !$0.isWhitespace }) else { return "" }
        if index == startIndex {
            // Avoid a potential copy if the string doesn't have any leading whitespace.
            return self
        }
        return String(self[index...])
    }
    
    /// Returns a new string made by removing whitespace from the end of the string.
    func removingTrailingWhitespace() -> String {
        guard let index = self.lastIndex(where: { !$0.isWhitespace }) else { return "" }
        // It's not worth checking if the index is at the end because `index(before: endIndex)` is slower than not checking.
        return String(self[...index])
    }
}
