/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension Markup {
    @available(*, deprecated, message: "Use DocumentationMarkup(markup:) to parse structured markup")
    public var seeAlso: SeeAlsoSection? {
        guard let headingIndex = sectionHeadingIndex(level: 2, named: SeeAlsoSection.title) else {
            return nil
        }

        let startIndex = headingIndex + 1
        let endIndex = indexToNextHeading(from: startIndex, level: 2) ?? childCount
        let content = Array(children.dropFirst(startIndex).prefix(endIndex - startIndex))

        guard !content.isEmpty else {
            return nil
        }

        return SeeAlsoSection(content: content)
    }
    
    /// Returns the first available child range.
    ///
    /// In case a block-level element is rewritten and its range is lost
    /// this method would return the first intact, inner range.
    /// For example a link might be rewritten and its own range will be lost
    /// but the range of the first, nested text element will be preserved
    /// so we could still use that to pin a diagnostic.
    func firstChildRange() -> Range<SourceLocation>? {
        for child in children {
            if let range = child.range { return range }
            if !child.hasChildren { return nil }
            return child.firstChildRange()
        }
        return nil
    }
    
    /// Returns true if the directive contains any children.
    var hasChildren: Bool {
        return childCount > 0
    }
}
