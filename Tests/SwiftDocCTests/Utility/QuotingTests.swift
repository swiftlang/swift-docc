/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class QuotingTests: XCTestCase {
    func testSingleQuoted() {
        XCTAssertEqual("''", "".singleQuoted)
        XCTAssertEqual("'Hello, world'", "Hello, world".singleQuoted)
        XCTAssertEqual("'1'", 1.description.singleQuoted)
    }
    
    func testListEmpty() {
        XCTAssertEqual("", [Int]().list(finalConjunction: .or))
        XCTAssertEqual("", [String]().list(finalConjunction: .or))
        XCTAssertEqual("", [""].list(finalConjunction: .or))
    }
    
    func testListOne() {
        XCTAssertEqual("1", [1].list(finalConjunction: .or))
        XCTAssertEqual("Hello", ["Hello"].list(finalConjunction: .or))
    }
    
    func testListTwo() {
        XCTAssertEqual("1 or 2", [1, 2].list(finalConjunction: .or))
        XCTAssertEqual("naughty or nice", ["naughty", "nice"].list(finalConjunction: .or))
    }
    
    func testListMoreThanTwo() {
        XCTAssertEqual("1, 2, or 3", [1, 2, 3].list(finalConjunction: .or))
        XCTAssertEqual("me, myself, and I", ["me", "myself", "I"].list(finalConjunction: .and))
        XCTAssertEqual("A, B, C, or D", ["A", "B", "C", "D"].list(finalConjunction: .or))
    }
}
