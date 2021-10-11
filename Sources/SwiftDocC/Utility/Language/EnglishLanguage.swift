/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Functions providing tools for generating English language.
public struct EnglishLanguage: LanguageConstructible {
    private static let vowels = "aeiou"
    
    /// A list of separators to insert between a given number of list items. For example for a list with 3 items,
    /// the result is `[", ", ", ", ", or "]`. These can be use to convert this array of strings `["one", "two", "three"]` into
    /// a human readable sentence: `"one, two, or three"`
    func listSeparators(itemsCount: Int, listType: NativeLanguage.ListType) -> [String] {
        let separator: String
        switch listType {
            case .options: separator = "or"
            case .union: separator = "and"
        }
        
        switch itemsCount {
            case 2:
                // Two alternatives.
                return [" \(separator) "]
            case 3...:
                // A list with an Oxford comma.
                var separators = Array<String>(repeating: ", ", count: itemsCount-2)
                separators.append(", \(separator) ")
                return separators
            default:
                // 1 or less items don't need separators.
                return []
        }
    }
} 
