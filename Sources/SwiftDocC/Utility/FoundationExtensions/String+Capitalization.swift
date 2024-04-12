/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    
    /// Returns the string with the first letter capitalized.
    /// This auto-capitalization only occurs if the first word is all lowercase and contains only lowercase letters.
    /// The first word can also contain punctuation (e.g. a period, comma, hyphen, semi-colon, colon).
    func capitalizeFirstWord() -> String {
        
        guard !self.isEmpty else { return self }
        
        guard let firstWordStartIndex = self.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) else { return self }
        
        // Find where the first word starts: this is additional processing to handle white spaces before the first word.
        let firstWord = self[firstWordStartIndex...].prefix(while: { !$0.isWhitespace && !$0.isNewline})
        
        
        guard firstWord.count > 0 else { return self }
        let firstWordCharacters = CharacterSet.init(charactersIn: String(firstWord))
        let acceptableCharacters = CharacterSet.lowercaseLetters.union(CharacterSet.punctuationCharacters)
        guard firstWordCharacters.isSubset(of: acceptableCharacters) else {
            return self
        }
        
        // Create the result string and make sure it's big enough to contain all the characters
        var resultString = String()
        resultString.reserveCapacity(self.count)
        
        // Add the white spaces before the first word
        resultString.append(contentsOf: self[..<firstWordStartIndex])
        
        // Add the capitalized first word (based on the locale)
        resultString.append(contentsOf: String(firstWord).localizedCapitalized)
        
        // Add the rest of the string
        let restStartIndex = self.index(firstWordStartIndex, offsetBy: firstWord.count)
        resultString.append(contentsOf: self[restStartIndex...])
        
        return resultString
    }
}
