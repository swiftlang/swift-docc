/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A section that contains groups of related symbols or external links.
public struct SeeAlsoSection: GroupedSection {
    public private(set) static var title: String? = "See Also"
    
    public var content: [Markup]

    /// The list of groups for the section.
    public var taskGroups: [TaskGroup] {
        return [TaskGroup(heading: Heading(level: 3, Text("Related Documentation")), content: Array(content))]
    }
}
