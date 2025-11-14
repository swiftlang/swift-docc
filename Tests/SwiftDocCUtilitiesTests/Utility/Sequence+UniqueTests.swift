/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import XCTest
@testable import SwiftDocCUtilities

class Sequence_UniqueTests: XCTestCase {
    func testEmpty() {
        let empty = [Int]()
        XCTAssert(empty.uniqueElements(by: { $0 }).isEmpty)
    }
    
    func testOrderIsPreserved() {
        let original = 0..<10
        XCTAssertEqual(original.uniqueElements(by: { $0 }), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9])
        
        let shuffled = (0..<10).shuffled()
        XCTAssertEqual(shuffled.uniqueElements(by: { $0 }), shuffled)
    }
    
    func testRemovesDuplicated() {
        let original = [1, 2, 1, 3, 2, 1, 4, 3, 2, 1]
        XCTAssertEqual(original.uniqueElements(by: { $0 }), [1, 2, 3, 4])
    }
    
    func testKeyPath() {
        struct Pair: Equatable { // Equatable for the test assertion below
            let number: Int
            let letter: Character
            init(_ number: Int, _ letter: Character) {
                self.number = number
                self.letter = letter
            }
        }
        
        let original = [Pair(1, "a"), Pair(1, "b"),
                        Pair(2, "a"), Pair(2, "b")]
        XCTAssertEqual(original.uniqueElements(by: { $0.number }), [Pair(1, "a"), Pair(2, "a")])
        
        XCTAssertEqual(original.uniqueElements(by: { $0.letter }), [Pair(1, "a"), Pair(1, "b")])
    }
}
