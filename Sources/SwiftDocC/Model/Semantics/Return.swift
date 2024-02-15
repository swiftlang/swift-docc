/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// Documentation about a symbol's return value.
public struct Return {
    /// The content that describe the return value for a symbol.
    public var contents: [Markup]
    /// The text range where this return value was parsed.
    var range: SourceRange?
    
    /// Initialize a value to describe documentation about a symbol's return value.
    /// - Parameter contents: The content that describe the return value for this symbol.
    public init(contents: [Markup], range: SourceRange? = nil) {
        self.contents = contents
        self.range = range
    }

    /// Initialize a value to describe documentation about a symbol's return value.
    ///
    /// - Parameter doxygenReturns: A parsed Doxygen `\returns` command.
    public init(_ doxygenReturns: DoxygenReturns) {
        self.contents = Array(doxygenReturns.children)
        self.range = doxygenReturns.range
    }
}
