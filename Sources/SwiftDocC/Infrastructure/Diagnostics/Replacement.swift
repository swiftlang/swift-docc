/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

/**
 A textual replacement.
 */
public struct Replacement: Hashable {
    /// The range to replace.
    public var range: SourceRange
    
    /// The replacement text.
    public var replacement: String
    
    public init(range: SourceRange, replacement: String) {
        self.range = range
        self.replacement = replacement
    }
}

extension Replacement {
    /// Offsets the replacement using a certain `SourceRange`.
    ///
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    ///
    /// - Warning: Absolute `SourceRange`s index line and column from 1. Thus, at least one
    /// of `self` or `range` must be a relative range indexed from 0.
    mutating func offsetWithRange(_ range: SourceRange) {
        self.range.offsetWithRange(range)
    }
    
    /// Offsets the replacement using a certain SymbolKit `SourceRange`.
    /// 
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    mutating func offsetWithRange(_ docRange: SymbolGraph.LineList.SourceRange) {
        self.offsetWithRange(SourceRange(from: docRange))
    }
}
