/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit

extension SourceRange {
    /// Offsets the `SourceRange` using a SymbolKit `SourceRange`.
    mutating func offsetWithRange(_ range: SymbolGraph.LineList.SourceRange) {
        self.offsetWithRange(SourceRange(from: range))
    }
    
    /// Initialize a `SourceRange` from a SymbolKit `SourceRange`.
    init(from symbolGrapSourceRange: SymbolGraph.LineList.SourceRange) {
        self = SourceLocation(line: symbolGrapSourceRange.start.line,
                              column: symbolGrapSourceRange.start.character,
                              source: nil)..<SourceLocation(line: symbolGrapSourceRange.end.line,
                                                            column: symbolGrapSourceRange.end.character,
                                                            source: nil)
    }
}

extension SourceRange {
    /// Offsets the `SourceRange` using another `SourceRange`.
    ///
    /// - Warning: Absolute `SourceRange`s index line and column from 1. Thus, at least one
    /// of `self` or `range` must be a relative range indexed from 0.
    mutating func offsetWithRange(_ range: SourceRange) {
        let start = SourceLocation(line: lowerBound.line + range.lowerBound.line, column: lowerBound.column + range.lowerBound.column, source: nil)
        let end = SourceLocation(line: upperBound.line + range.lowerBound.line, column: upperBound.column + range.lowerBound.column, source: nil)
        
        self = start..<end
    }
}
