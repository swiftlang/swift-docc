/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 The line and column of a position in text.
 */
public struct PrintCursor: Comparable, Hashable, CustomDebugStringConvertible {
    /// The line of this position in text, starting at `1`.
    public let line: Int
    
    /// The column of this position in text, starting at `1`.
    public let column: Int
    
    public init(line: Int, column: Int) {
        precondition(line > 0, "Line numbers must be > 0")
        precondition(column > 0, "Column numbers must be > 0")
        self.line = line
        self.column = column
    }
    
    public init?(offset: Int, in source: String) {
        precondition(offset >= 0, "Source offsets must be >= 0")
        var currentLine = 1
        var currentColumn = 1
        guard let targetIndex = source.index(source.startIndex, offsetBy: offset, limitedBy: source.endIndex) else {
            return nil
        }
        var index = source.startIndex
        while index != targetIndex {
            let c = source[index]
            if c == "\n" {
                currentLine += 1
                currentColumn = 1
            } else {
                currentColumn += 1
            }
            index = source.index(after: index)
        }
        self.init(line: currentLine, column: currentColumn)
    }
    
    public static func < (lhs: PrintCursor, rhs: PrintCursor) -> Bool {
        guard lhs.line >= rhs.line else {
            return true
        }
        guard lhs.line == rhs.line else {
            return false
        }
        return lhs.column < rhs.column
    }
    
    public var debugDescription: String {
        return "\(line):\(column)"
    }
}

/**
 A range in a document represented by a pair of line-column pairs.
 */
public struct CursorRange: Hashable, CustomDebugStringConvertible {
    /// The start of the range.
    public let start: PrintCursor
    
    /// The end of the range.
    public let end: PrintCursor
    
    /// The original source from which this range was established.
    var source: String
    
    public init(start: PrintCursor, end: PrintCursor, in source: String) {
        self.start = start
        self.end = end
        self.source = source
    }
    
    public var debugDescription: String {
        return "\(start)-\(end)"
    }
}

// A new-line character.
fileprivate let newLineASCII = UInt8(UTF8.CodeUnit(ascii: "\n"))

extension Int {
    /**
     Initialize an absolute source offset using a line and column.
     
     The `SourceRange`'s offset and length are calculated by scanning through `source` and tallying a running line and column along the way.
     
     - Throws: `SourceRange.Error`
     */
    init?<Source: StringProtocol>(cursor: PrintCursor, in source: Source) {
        var line = 1
        var column = 1
        var index = source.utf8.startIndex
        while line < cursor.line || column < cursor.column {
            guard index != source.utf8.endIndex else {
                return nil
            }

            let c = source.utf8[index]
            if c == newLineASCII {
                line += 1
                column = 1
            } else {
                column += 1
            }
            index = source.utf8.index(after: index)
        }
        
        self = source.utf8.distance(from: source.utf8.startIndex, to: index)
    }
}
