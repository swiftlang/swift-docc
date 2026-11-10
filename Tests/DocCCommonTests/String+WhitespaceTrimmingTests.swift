/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import DocCCommon
import Testing

struct String_WhitespaceTrimmingTests {
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
