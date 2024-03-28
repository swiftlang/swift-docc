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
    /// The first word can also contain punctuation at the end of the word (e.g. a period, comma, semi-colon, or colon).
    var capitalizeFirstWord: String {
        let firstWord = self.components(separatedBy: " ").first ?? ""
        
        print("firstWord: \(firstWord)")
        
        guard firstWord.contains("/^[a-z]+[,.;:]*$/g") else {
            return "\(self)"
        }
        
         return (self.first?.uppercased() ?? "") + self.dropFirst()
    }
}
