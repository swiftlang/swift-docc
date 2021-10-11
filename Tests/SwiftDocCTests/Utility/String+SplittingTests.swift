/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class String_SplittingTests: XCTestCase {
    
    func testSplitsAStringWithNoTrailingNewlines() {
        XCTAssertEqual("hello\nworld".splitByNewlines, ["hello", "world"])
    }
    
    func testSplitsAStringWithOneTrailingNewline() {
        XCTAssertEqual("hello\nworld\n".splitByNewlines, ["hello", "world"])
    }
    
    func testSplitsAStringWithTwoTrailingNewlines() {
        XCTAssertEqual("hello\nworld\n\n".splitByNewlines, ["hello", "world", ""])
    }
}
