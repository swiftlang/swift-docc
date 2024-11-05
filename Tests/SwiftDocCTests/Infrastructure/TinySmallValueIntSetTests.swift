/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Algorithms
@testable import SwiftDocC

class TinySmallValueIntSetTests: XCTestCase {
    func testBehavesSameAsSet() {
        var tiny = _TinySmallValueIntSet()
        var real = Set<Int>()
        
        func AssertEqual(_ lhs: (inserted: Bool, memberAfterInsert: Int), _ rhs: (inserted: Bool, memberAfterInsert: Int), file: StaticString = #filePath, line: UInt = #line) {
            XCTAssertEqual(lhs.inserted, rhs.inserted, file: file, line: line)
            XCTAssertEqual(lhs.memberAfterInsert, rhs.memberAfterInsert, file: file, line: line)
        }
        
        XCTAssertEqual(tiny.contains(4), real.contains(4))
        AssertEqual(tiny.insert(4), real.insert(4))
        XCTAssertEqual(tiny.contains(4), real.contains(4))
        XCTAssertEqual(tiny.count, real.count)
        
        AssertEqual(tiny.insert(4), real.insert(4))
        XCTAssertEqual(tiny.contains(4), real.contains(4))
        XCTAssertEqual(tiny.count, real.count)
        
        AssertEqual(tiny.insert(7), real.insert(7))
        XCTAssertEqual(tiny.contains(7), real.contains(7))
        XCTAssertEqual(tiny.count, real.count)
        
        XCTAssertEqual(tiny.update(with: 2), real.update(with: 2))
        XCTAssertEqual(tiny.contains(2), real.contains(2))
        XCTAssertEqual(tiny.count, real.count)
        
        XCTAssertEqual(tiny.remove(9), real.remove(9))
        XCTAssertEqual(tiny.contains(9), real.contains(9))
        XCTAssertEqual(tiny.count, real.count)
        
        XCTAssertEqual(tiny.remove(4), real.remove(4))
        XCTAssertEqual(tiny.contains(4), real.contains(4))
        XCTAssertEqual(tiny.count, real.count)
        
        tiny.formUnion([19])
        real.formUnion([19])
        XCTAssertEqual(tiny.contains(19), real.contains(19))
        XCTAssertEqual(tiny.count, real.count)
        
        tiny.formSymmetricDifference([9])
        real.formSymmetricDifference([9])
        XCTAssertEqual(tiny.contains(7), real.contains(7))
        XCTAssertEqual(tiny.contains(9), real.contains(9))
        XCTAssertEqual(tiny.count, real.count)
        
        tiny.formIntersection([5,6,7])
        real.formIntersection([5,6,7])
        XCTAssertEqual(tiny.contains(4), real.contains(4))
        XCTAssertEqual(tiny.contains(5), real.contains(5))
        XCTAssertEqual(tiny.contains(6), real.contains(6))
        XCTAssertEqual(tiny.contains(7), real.contains(7))
        XCTAssertEqual(tiny.contains(8), real.contains(8))
        XCTAssertEqual(tiny.contains(9), real.contains(9))
        XCTAssertEqual(tiny.count, real.count)
    }
    
    func testCombinations() {
        do {
            let tiny: _TinySmallValueIntSet = [0,1,2]
            XCTAssertEqual(tiny.combinationsToCheck().map { $0.sorted() }, [
                [0], [1], [2],
                [0,1], [0,2], [1,2],
                [0,1,2]
            ])
        }
        
        do {
            let tiny: _TinySmallValueIntSet = [2,5,9]
            XCTAssertEqual(tiny.combinationsToCheck().map { $0.sorted() }, [
                [2], [5], [9],
                [2,5], [2,9], [5,9],
                [2,5,9]
            ])
        }
        
        do {
            let tiny: _TinySmallValueIntSet = [3,4,7,11,15,16]
            
            let expected = Array(tiny).combinations(ofCount: 1...)
            let actual   = tiny.combinationsToCheck().map { Array($0) }
            
            XCTAssertEqual(expected.count, actual.count)
            
            // The two implementations doesn't need to provide combinations in the same order within a size
            let expectedBySize: [[[Int]]] = expected.grouped(by: \.count).sorted(by: \.key).map(\.value)
            let actualBySize:   [[[Int]]] = actual  .grouped(by: \.count).sorted(by: \.key).map(\.value)
            
            for (expectedForSize, actualForSize) in zip(expectedBySize, actualBySize) {
                XCTAssertEqual(expectedForSize.count, actualForSize.count)
                
                // Comparing [Int] descriptions to allow each same-size combination list to have different orders.
                // For example, these two lists of combinations (with the last 2 elements swapped) are considered equivalent:
                // [1, 2, 3], [1, 2, 4], [1, 3, 4], [2, 3, 4]
                // [1, 2, 3], [1, 2, 4], [2, 3, 4], [1, 3, 4]
                XCTAssertEqual(expectedForSize.map(\.description).sorted(),
                               actualForSize  .map(\.description).sorted())
                
            }
        }
    }
}
