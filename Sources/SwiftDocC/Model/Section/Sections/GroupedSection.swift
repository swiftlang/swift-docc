/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A generic section that contains groups of links.
public protocol GroupedSection: Section {
    var taskGroups: [TaskGroup] { get }
}

extension GroupedSection {
    /// This section's content split into groups by third-level headings.
    public var taskGroups: [TaskGroup] {
        // Get the child indices of any level-3 headings
        let h3Indices = content.indices.compactMap { index -> Int? in
            guard let heading = content[index] as? Heading,
                heading.level == 3 else {
                    return nil
            }
            return index
        }
        
        // Task groups are delimited by headings with level 3 so, if there are none, there can be no task groups, despite otherwise matching expected structure.
        guard !h3Indices.isEmpty else {
            return []
        }
        
        // Get the ranges of each task group in terms of child indices of the containing document.
        let ranges = zip(h3Indices, Array(h3Indices[1...]) + [content.endIndex]).map { pair in
            return (pair.0)..<pair.1
        }
        
        // Create a `TaskGroup` for each range. If a task group doesn't have any content underneath it, drop it.
        return ranges.compactMap { range in
            let heading = self.content[range.startIndex] as! Heading
            let content = self.content[range.dropFirst()]
            guard !content.isEmpty else {
                return nil
            }
            return TaskGroup(heading: heading, content: Array(content))
        }
    }
}
