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
public struct Replacement {
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
    
    /// Returns a copy of the replacement but offset using a certain `SourceRange`.
    /// Useful when validating a doc comment that needs to be projected in its containing file "space".
    func offsetedWithRange(_ docRange: SymbolGraph.LineList.SourceRange) -> Replacement {
        var result = self
        result.range = range.offsetedWithRange(docRange)
        return result
    }
}

extension SourceRange {
    /// Returns a copy of the `SourceRange` offset using a certain  SymbolKit `SourceRange`.
    func offsetedWithRange(_ docRange: SymbolGraph.LineList.SourceRange) -> SourceRange {
        let start = SourceLocation(line: lowerBound.line + docRange.start.line, column: lowerBound.column + docRange.start.character, source: nil)
        let end = SourceLocation(line: upperBound.line + docRange.start.line, column: upperBound.column + docRange.start.character, source: nil)
        
        return start..<end
    }
}
