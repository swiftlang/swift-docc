/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension String {
    /// Returns a new string made by removing whitespace from the beginning of the string.
    package func removingLeadingWhitespace() -> String {
        guard let index = self.firstIndex(where: { !$0.isWhitespace }) else { return "" }
        if index == startIndex {
            // Avoid a potential copy if the string doesn't have any leading whitespace.
            return self
        }
        return String(self[index...])
    }
    
    /// Returns a new string made by removing whitespace from the end of the string.
    package func removingTrailingWhitespace() -> String {
        guard let index = self.lastIndex(where: { !$0.isWhitespace }) else { return "" }
        // It's not worth checking if the index is at the end because `index(before: endIndex)` is slower than not checking.
        return String(self[...index])
    }
}
