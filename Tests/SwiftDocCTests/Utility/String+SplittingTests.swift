/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
@testable import SwiftDocC

struct String_SplittingTests {
    
    @Test(arguments: [
        ("hello\nworld", ["hello", "world"]),
        ("hello\nworld\n", ["hello", "world"]),
        ("hello\nworld\n\n", ["hello", "world", ""]),
    ])
    func splitsByNewlinesAndDropsSingleTrailingNewline(input: String, expected: [String]) {
        #expect(input.splitByNewlines == expected)
    }
}
