/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

extension Heading {
    /// A Boolean value that indicates if this heading contains any link as its first element.
    ///
    /// A first level heading with a link is used to associate a documentation extension file with a symbol.
    var startsWithAnyLink: Bool {
        child(at: 0) is (any AnyLink)
    }
}
