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
}

extension AnyLink {
    var referenceBodySourceRange: SourceRange? {
        guard let destination, let range else {
            return nil
        }

        if self is SymbolLink {
            // Inset the range by 2 at the start and end to skip both "``".
            return SourceLocation(
                line: range.lowerBound.line,
                column: range.lowerBound.column + 2,
                source: range.lowerBound.source
            ) ..< SourceLocation(
                line: range.upperBound.line,
                column: range.upperBound.column - 2,
                source: range.upperBound.source
            )
        }

        guard let link = self as? Link else {
            return nil
        }

        let topicScheme = "\(ResolvedTopicReference.urlScheme):"
        guard destination.hasPrefix(topicScheme) else {
            return nil
        }

        let isAngleBracketAutolink = link.isAutolink
            && range.lowerBound.line == range.upperBound.line
            && range.upperBound.column - range.lowerBound.column == destination.count + 2
        if isAngleBracketAutolink {
            return SourceLocation(
                line: range.lowerBound.line,
                column: range.lowerBound.column + 1 + topicScheme.count,
                source: range.lowerBound.source
            ) ..< SourceLocation(
                line: range.upperBound.line,
                column: range.upperBound.column - 1,
                source: range.upperBound.source
            )
        }

        guard range.lowerBound.line == range.upperBound.line else {
            return nil
        }

        let titleSourceLength = link.title.map { $0.count + 3 } ?? 0
        let destinationEndColumn = range.upperBound.column - 1 - titleSourceLength
        let destinationStartColumn = destinationEndColumn - destination.count

        return SourceLocation(
            line: range.upperBound.line,
            column: destinationStartColumn + topicScheme.count,
            source: range.upperBound.source
        ) ..< SourceLocation(
            line: range.upperBound.line,
            column: destinationEndColumn,
            source: range.upperBound.source
        )
    }
}
