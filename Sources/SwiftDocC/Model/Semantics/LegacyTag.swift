/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A generic documentation tag.
///
/// Write a documentation tag by prepending a line of prose with something like a "- seeAlso:" or "- todo:".
public struct SimpleTag {
    /// The name of the tag.
    public var tag: String
    
    /// The tagged content.
    public var contents: [Markup]
    
    /// Creates a new tagged piece of documentation from the given name and content.
    /// 
    /// - Parameters:
    ///   - tag: The name of the tag.
    ///   - contents: The tagged content.
    public init(tag: String, contents: [Markup]) {
        self.tag = tag
        self.contents = contents
    }
}
