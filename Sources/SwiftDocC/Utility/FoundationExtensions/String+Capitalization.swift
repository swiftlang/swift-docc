/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

extension String {
    
    // Precomputes the CharacterSet to use in capitalizeFirstWord().
    private static let charactersPreventingWordCapitalization = CharacterSet.lowercaseLetters.union(.punctuationCharacters).inverted
    
    /// Returns the string with the first letter capitalized.
    /// This auto-capitalization only occurs if the first word is all lowercase and contains only lowercase letters.
    /// The first word can also contain punctuation (e.g. a period, comma, hyphen, semi-colon, colon).
    func capitalizeFirstWord() -> String {
        guard let firstWordStartIndex = self.firstIndex(where: { !$0.isWhitespace && !$0.isNewline }) else { return self }
        let firstWord = self[firstWordStartIndex...].prefix(while: { !$0.isWhitespace && !$0.isNewline})
        
        guard firstWord.rangeOfCharacter(from: Self.charactersPreventingWordCapitalization) == nil else {
            return self
        }
        
        var resultString = self
        
        resultString.replaceSubrange(firstWordStartIndex..<firstWord.endIndex, with: firstWord.localizedCapitalized)
        
        return resultString
    }
}
