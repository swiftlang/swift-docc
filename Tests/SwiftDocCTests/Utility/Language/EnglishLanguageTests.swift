/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class EnglishLanguageTests: XCTestCase {
    func testEnglishListOptions() throws {
        XCTAssertEqual([], NativeLanguage.english.listSeparators(itemsCount: 0, listType: .options), "Didn't return empty separator list for empty input list.")
        XCTAssertEqual([], NativeLanguage.english.listSeparators(itemsCount: 1, listType: .options), "Didn't return empty separator list for 1 items input list.")
        XCTAssertEqual([" or "], NativeLanguage.english.listSeparators(itemsCount: 2, listType: .options), "Didn't return single separator for 2 items input list.")
        XCTAssertEqual([", ", ", or "], NativeLanguage.english.listSeparators(itemsCount: 3, listType: .options), "Didn't return expected separators for 3 items input list.")
    }

    func testEnglishListUnion() throws {
        XCTAssertEqual([], NativeLanguage.english.listSeparators(itemsCount: 0, listType: .union), "Didn't return empty separator list for empty input list.")
        XCTAssertEqual([], NativeLanguage.english.listSeparators(itemsCount: 1, listType: .union), "Didn't return empty separator list for 1 items input list.")
        XCTAssertEqual([" and "], NativeLanguage.english.listSeparators(itemsCount: 2, listType: .union), "Didn't return single separator for 2 items input list.")
        XCTAssertEqual([", ", ", and "], NativeLanguage.english.listSeparators(itemsCount: 3, listType: .union), "Didn't return expected separators for 3 items input list.")
    }
}
