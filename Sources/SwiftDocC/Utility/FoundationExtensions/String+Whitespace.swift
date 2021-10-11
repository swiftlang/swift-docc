/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    /// Returns a copy of the string with all whitespace and punctuation replaced with a given separator.
    ///
    /// Contiguous sequences of whitespace and punctuation is replaced with a single separator.
    ///
    /// - Parameter separator: The string to replace contiguous sequences of whitespace and punctuation with.
    /// - Returns: A new string with all whitespace and punctuation replaced with a given separator.
    func replacingWhitespaceAndPunctuation(with separator: String) -> String {
        let charactersToStrip = CharacterSet.whitespaces.union(.punctuationCharacters)
        return components(separatedBy: charactersToStrip).filter({ !$0.isEmpty }).joined(separator: separator)
    }
}
