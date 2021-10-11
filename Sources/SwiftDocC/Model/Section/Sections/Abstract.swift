/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A one-paragraph section that represents a symbol's abstract description.
public struct AbstractSection: Section {
    public static var title: String? {
        return nil
    }
    public var content: [Markup] {
        return paragraph.children.compactMap { $0.detachedFromParent }
    }
    
    /// The section content as a paragraph.
    public var paragraph: Paragraph
    
    /// Creates a new section with the given paragraph.
    public init(paragraph: Paragraph) {
        self.paragraph = paragraph
    }
}
