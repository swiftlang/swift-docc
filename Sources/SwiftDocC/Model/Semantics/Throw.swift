/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// Documentation about a symbol's potential errors.
public struct Throw {
    /// The content that describe potential errors for a symbol.
    public var contents: [Markup]
    
    /// Initialize a value to describe documentation about a symbol's potential errors.
    /// - Parameter contents: The content that describe potential errors for this symbol.
    public init(contents: [Markup]) {
        self.contents = contents
    }
}
