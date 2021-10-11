/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension Document {
    /// The extracted `plainText` of a document's initial level-1 heading if present.
    var title: String? {
        let titleHeading = children.first {
            guard let heading = $0 as? Heading,
                  heading.level == 1 else {
                return false
            }
            return true
        } as? Heading
        return titleHeading?.plainText
    }
}
