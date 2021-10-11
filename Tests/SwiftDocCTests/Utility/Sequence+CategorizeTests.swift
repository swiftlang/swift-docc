/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

fileprivate func isEven(_ x: Int) -> Int? {
    guard x % 2 == 0 else {
        return nil
    }
    return x
}

class Sequence_CategorizeTests: XCTestCase {
    func testEmpty() {
        let orig = [Int]()
        let (matches, remainder) = orig.categorize(where: isEven)
        XCTAssertTrue(matches.isEmpty)
        XCTAssertTrue(remainder.isEmpty)
    }
    
    func testOneMatch() {
        let orig = [2]
        let (matches, remainder) = orig.categorize(where: isEven)
        XCTAssertEqual(1, matches.count)
        XCTAssertTrue(remainder.isEmpty)
        matches.first.map { x in
            XCTAssertEqual(2, x)
        }
    }
    
    func testOneNonMatch() {
        let orig = [1]
        let (matches, remainder) = orig.categorize(where: isEven)
        XCTAssertTrue(matches.isEmpty)
        XCTAssertEqual(1, remainder.count)
        remainder.first.map { x in
            XCTAssertEqual(1, x)
        }
    }
    
    func testMany() {
        let orig = [1, 2, 3, 4]
        let (matches, remainder) = orig.categorize(where: isEven)
        XCTAssertEqual(2, matches.count)
        XCTAssertEqual(2, remainder.count)
        XCTAssertEqual([2, 4], matches)
        XCTAssertEqual([1, 3], remainder)
    }
}
