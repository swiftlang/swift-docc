/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

struct String_CapitalizationTests {

    @Test
    func capitalizesFirstLetterOfLowercaseString() {
        #expect("hello world".capitalizingFirstWord() == "Hello world")
    }

    @Test
    func leavesWordsContainingBacktickUnchanged() {
        #expect("h`ello world".capitalizingFirstWord() == "h`ello world")
    }

    @Test
    func preservesWordsWithInternalCapitalization() {
        #expect("iPad iOS visionOS".capitalizingFirstWord() == "iPad iOS visionOS")
    }

    @Test(arguments: [
        ("hello, world", "Hello, world"),
        ("twenty-one", "Twenty-One"),
        ("hello! world", "Hello! world"),
        ("hello: world", "Hello: world"),
        ("l'ocean world", "L'ocean world"),
    ])
    func capitalizesEachWordSeparatedByPunctuation(input: String, expected: String) {
        #expect(input.capitalizingFirstWord() == expected)
    }

    @Test(arguments: [
        ("       has many spaces", "       Has many spaces"),
        ("     has a tab", "     Has a tab"),
        ("         has many spaces     ", "         Has many spaces     "),
    ])
    func preservesLeadingAndTrailingWhitespace(input: String, expected: String) {
        #expect(input.capitalizingFirstWord() == expected)
    }

    @Test(arguments: [
        ("l'amérique du nord", "L'amérique du nord"),
        ("ça va?", "Ça va?"),
        ("à", "À"),
        ("チーズ", "チーズ"),
        ("牛奶", "牛奶"),
        ("i don't like 牛奶", "I don't like 牛奶"),
        ("牛奶 is tasty", "牛奶 is tasty"),
    ])
    func capitalizesAcrossDifferentScripts(input: String, expected: String) {
        #expect(input.capitalizingFirstWord() == expected)
    }
}
