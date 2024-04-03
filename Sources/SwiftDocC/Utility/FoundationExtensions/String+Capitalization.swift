/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension StringProtocol {
    
    /// Returns the string with the first letter capitalized.
    /// This auto-capitalization only occurs if the first word is all lowercase and contains only characters A-Z.
    /// The first word can also contain punctuation (e.g. a period, comma, hyphen, semi-colon, colon).
    var capitalizeFirstWord: String {
        let firstWord = self.components(separatedBy: " ").first ?? ""
        
        let firstWordNoPunctuation = firstWord.components(separatedBy: CharacterSet.punctuationCharacters).joined()
        let firstWordNoLowerCaseOrPunctuation = firstWordNoPunctuation.components(separatedBy: CharacterSet.lowercaseLetters).joined()
        
        guard firstWordNoLowerCaseOrPunctuation.isEmpty else {
            return "\(self)"
        }
        
        return (self.first?.uppercased() ?? "") + self.dropFirst()
    }
}
