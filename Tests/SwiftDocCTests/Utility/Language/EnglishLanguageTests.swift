/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct EnglishLanguageTests {
    @Test(arguments: [
        (0, []),
        (1, []),
        (2, [" or "]),
        (3, [", ", ", or "]),
    ])
    func usesOrSeparatorForOptionsLists(itemsCount: Int, expected: [String]) {
        #expect(NativeLanguage.english.listSeparators(itemsCount: itemsCount, listType: .options) == expected)
    }
    
    @Test(arguments: [
        (0, []),
        (1, []),
        (2, [" and "]),
        (3, [", ", ", and "]),
    ])
    func usesAndSeparatorForUnionLists(itemsCount: Int, expected: [String]) {
        #expect(NativeLanguage.english.listSeparators(itemsCount: itemsCount, listType: .union) == expected)
    }
}
