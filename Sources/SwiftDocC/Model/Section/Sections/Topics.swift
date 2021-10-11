/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// Grouped source ranges.
typealias GroupedLinkRanges = [[SourceRange?]]

/// A section that contains groups of symbols.
public struct TopicsSection: GroupedSection {
    public static var title: String? {
        return "Topics"
    }
    public var content: [Markup]
    
    /// Creates a new topics section with the given content.
    /// - Parameters:
    ///   - content: The markup content elements for this section.
    ///   - originalLinkRangesByGroup: Any original link ranges, if links were modified.
    init(content: [Markup], originalLinkRangesByGroup: GroupedLinkRanges = []) {
        self.content = content
        self.originalLinkRangesByGroup = originalLinkRangesByGroup.isEmpty ? linkRanges() : originalLinkRangesByGroup
    }
    
    /// Contains the original ranges of the links in this section, in case they were modified.
    var originalLinkRangesByGroup = GroupedLinkRanges()
    
    /// Extracts a list of link ranges from this section grouped by task group.
    private func linkRanges() -> GroupedLinkRanges {
        return taskGroups.map { group -> [SourceRange?] in
            return group.links.map { link -> SourceRange? in
                return link.range
            }
        }
    }
}
