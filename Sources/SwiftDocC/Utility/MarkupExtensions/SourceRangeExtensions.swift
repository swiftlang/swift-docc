/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
import SymbolKit
import Foundation

extension SourceRange {
    /// Offsets the `SourceRange` using a SymbolKit `SourceRange`.
    mutating func offsetWithRange(_ range: SymbolGraph.LineList.SourceRange) {
        self.offsetWithRange(SourceRange(from: range))
    }
    
    /// Initialize a `SourceRange` from a SymbolKit `SourceRange`.
    init(from symbolGraphRange: SymbolGraph.LineList.SourceRange) {
        let start = SourceLocation(line: symbolGraphRange.start.line, column: symbolGraphRange.start.character, source: nil)
        let end =   SourceLocation(line: symbolGraphRange.end.line,   column: symbolGraphRange.end.character,   source: nil)
        
        self = start ..< end
    }

    /// Offsets the `SourceRange` using another `SourceRange`.
    ///
    /// - Warning: Absolute `SourceRange`s index line and column from 1. Thus, at least one
    /// of `self` or `range` must be a relative range indexed from 0.
    mutating func offsetWithRange(_ range: SourceRange) {
        let start = SourceLocation(line: lowerBound.line + range.lowerBound.line, column: lowerBound.column + range.lowerBound.column, source: lowerBound.source)
        let end   = SourceLocation(line: upperBound.line + range.lowerBound.line, column: upperBound.column + range.lowerBound.column, source: upperBound.source)
        
        self = start ..< end
    }
    
    /// The source file for which this range applies, if it came from an accessible location.
    var source: URL? {
        lowerBound.source ?? upperBound.source
    }
    
    /// Creates an empty range a the start of the file
    static func makeEmptyStartOfFileRangeWhenSpecificInformationIsUnavailable(source: URL?) -> SourceRange {
        let location = SourceLocation(line: 1, column: 1, source: source)
        return location ..< location
    }

    /// Returns a copy of the range moved inward by a number of columns at the start and at the end.
    ///
    /// This is meant for ranges that start and end on the same line, where the inset trims a fixed number of leading
    /// and trailing characters (for example the surrounding link syntax).
    ///
    /// - Parameters:
    ///   - startColumns: The number of columns to move the lower bound forward by.
    ///   - endColumns: The number of columns to move the upper bound backward by.
    /// - Returns: A new range inset by the given number of columns.
    func inset(startColumns: Int, endColumns: Int) -> SourceRange {
        return SourceLocation(line: lowerBound.line, column: lowerBound.column + startColumns, source: lowerBound.source)
            ..< SourceLocation(line: upperBound.line, column: upperBound.column - endColumns, source: upperBound.source)
    }
}

extension AnyLink {
    /// The source range that suggested replacements for an unresolved topic reference should be anchored to, or `nil`
    /// when the link's range is unknown.
    ///
    /// Suggested replacements from link resolution (for example a disambiguation suffix to append) use columns relative
    /// to the start of the reference's path, so this is the range of the reference body with any link syntax and
    /// `doc:` scheme removed:
    ///
    /// - For a symbol link (`` ``my/reference`` ``) it's the range inside the double backticks.
    /// - For a `<doc:my/reference>` autolink it's the range after `<doc:` and before `>`.
    /// - For a `[link text](doc:my/reference)` markdown link it's the range after `(doc:` and before `)`.
    ///
    /// Swift-Markdown doesn't expose the destination's range directly, so for markdown links it's computed from the
    /// link's range and the length of its destination (see https://github.com/swiftlang/swift-markdown/issues/109).
    var referenceBodySourceRange: SourceRange? {
        guard let range = self.range, destination != nil else {
            return nil
        }

        if self is SymbolLink {
            // A symbol link is written as "``my/reference``". Inset the range by 2 at both ends to skip the "``".
            return range.inset(startColumns: 2, endColumns: 2)
        }

        guard let link = self as? Link, let destination = link.destination else {
            return nil
        }

        if link.isAutolink {
            // An autolink is written as "<doc:my/reference>". Inset the range by 5 at the start and by 1 at the end to
            // skip "<doc:" at the start and ">" at the end.
            return range.inset(startColumns: 5, endColumns: 1)
        }

        // A markdown link is written as "[link text](doc:my/reference)". The destination ("doc:my/reference") ends just
        // before the closing parenthesis, so it starts `destination.count` columns before that parenthesis. This places
        // the range correctly regardless of the length of the link's display text. The reference's path follows the
        // "doc:" scheme, so skip that to match where the suggested replacements are anchored.
        //
        // A link title ("[link text](doc:my/reference \"title\")") would offset the destination away from the closing
        // parenthesis. Rather than risk an incorrectly placed replacement, don't compute a range in that case. The
        // diagnostic is still emitted, just without a suggested replacement.
        let schemePrefix = "\(ResolvedTopicReference.urlScheme):"
        guard link.title == nil, destination.hasPrefix(schemePrefix) else {
            return nil
        }
        let bodyEndColumn = range.upperBound.column - 1
        let bodyStartColumn = bodyEndColumn - destination.count + schemePrefix.count
        return SourceLocation(line: range.upperBound.line, column: bodyStartColumn, source: range.upperBound.source)
            ..< SourceLocation(line: range.upperBound.line, column: bodyEndColumn, source: range.upperBound.source)
    }
}
