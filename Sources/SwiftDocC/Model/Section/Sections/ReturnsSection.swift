/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A section that contains return value information for a function.
public struct ReturnsSection: Section {
    public static var title: String? {
        return "Return Value"
    }
    public var content: [Markup]
}
