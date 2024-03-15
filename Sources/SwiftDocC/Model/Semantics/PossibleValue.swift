/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/// Documentation about the possible values for a symbol.
public struct PossibleValue {
    /// The string representation of the value.
    public var value: String
    /// The content that describe the value.
    public var contents: [Markup]
}
