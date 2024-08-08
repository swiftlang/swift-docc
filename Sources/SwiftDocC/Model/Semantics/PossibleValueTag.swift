/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/// A possible value tag.
///
/// Documentation about a  possible value of a symbol.
/// Write a possible value tag by prepending a line of prose with "- PossibleValue:"  or  "- PossibleValues:".
public struct PossibleValueTag {
    /// The string representation of the value.
    public var value: String
    /// The content that describes the value.
    public var contents: [Markup]
    /// The text range where the parameter name was parsed.
    var nameRange: SourceRange?
    /// The text range where this parameter was parsed.
    var range: SourceRange?
    
}
