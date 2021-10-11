/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

public struct DiscussionSection: Section {
    public static var title: String? {
        return "Discussion"
    }
    public var content: [Markup]
    
    /// Creates a new discussion section with the given markup content.
    public init(content: [Markup]) {
        self.content = content
    }
}
