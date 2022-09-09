/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension Sequence where Element == RenderBlockContent {
    /// The contents of the first paragraph in this sequence of block content.
    ///
    /// This property is an empty array if the sequence doesn't contain a paragraph.
    var firstParagraph: [RenderInlineContent] {
        return mapFirst { blockContent in
            guard case let .paragraph(p) = blockContent else {
                return nil
            }
            return p.inlineContent
        } ?? []
    }
}
