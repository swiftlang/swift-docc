/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import SymbolKit

extension SymbolGraph.Symbol {

    /// Return the offset of this symbol's doc comment in the original source code file,
    /// adjusted for the interface language as follows:
    ///
    /// - Objective-C: subtract one from the start/end lines, and the start/end characters
    /// - Swift and other languages: return the original offset
    ///
    /// - Returns: A ``SourceRange`` or nil if this symbol has no doc comment.
    func offsetAdjustedForInterfaceLanguage() -> SymbolGraph.LineList.SourceRange? {
        guard let range = docComment?.lines.first?.range else {
            return nil
        }
        // Return the original range for Swift and other languages
        guard SourceLanguage(knownLanguageIdentifier: identifier.interfaceLanguage) == .objectiveC else {
            return range
        }
        // Decrement the line and character indexes for Objective-C
        let start = range.start
        let end = range.end
        return SymbolGraph.LineList.SourceRange(
            start: .init(line: start.line-1, character: start.character-1),
            end: .init(line: end.line-1, character: end.character-1)
        )
    }
}
