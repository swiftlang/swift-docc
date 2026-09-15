/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

struct String_WhitespaceTests {
    
    @Test(arguments: [
        ("Words separated by spaces", "Words-separated-by-spaces"),
        ("Words_separated_by_underscores", "Words-separated-by-underscores"),
        ("Words'separated'by'single'quotes", "Words-separated-by-single-quotes"),
        ("Words:separated:by:colons", "Words-separated-by-colons"),
        ("Words/separated/by/forward/slashes", "Words-separated-by-forward-slashes"),
        ("Mixig various'separator_characters:between/words", "Mixig-various-separator-characters-between-words"),
    ])
    func replacesEachSeparatorCharacterWithGivenString(input: String, expected: String) {
        #expect(input.replacingWhitespaceAndPunctuation(with: "-") == expected)
    }
    
    @Test(arguments: [
        ("Words   separated by    multiple  spaces", "Words-separated-by-multiple-spaces"),
        ("Words___separated_by____multiple__underscrores", "Words-separated-by-multiple-underscrores"),
        ("Words: with, various. punctuation! as - separators", "Words-with-various-punctuation-as-separators"),
    ])
    func collapsesConsecutiveSeparators(input: String, expected: String) {
        #expect(input.replacingWhitespaceAndPunctuation(with: "-") == expected)
    }
    
    @Test(arguments: [
        ("", "", ""),
        ("ABC", "ABC", "ABC"),
        ("\t ABC\t ", "ABC\t ", "\t ABC"),
        ("\t ", "", ""),
        ("\n ABC \n", "ABC \n", "\n ABC"),
        ("start ABC end", "start ABC end", "start ABC end"),
    ])
    func trimsLeadingAndTrailingWhitespaceIndependently(input: String, expectedLeading: String, expectedTrailing: String) {
        #expect(input.removingLeadingWhitespace() == expectedLeading)
        #expect(input.removingTrailingWhitespace() == expectedTrailing)
    }
}
