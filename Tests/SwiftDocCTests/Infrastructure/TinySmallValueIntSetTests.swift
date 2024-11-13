/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
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
        
        tiny.formUnion([11,29])
        real.formUnion([11,29])
        XCTAssertEqual(tiny.contains(11), real.contains(11))
        XCTAssertEqual(tiny.contains(29), real.contains(29))
        XCTAssertEqual(tiny.count, real.count)
        
        XCTAssertEqual(tiny.isSuperset(of: tiny), real.isSuperset(of: real))
        XCTAssertEqual(tiny.isSuperset(of: []),   real.isSuperset(of: []))
        XCTAssertEqual(tiny.isSuperset(of: .init(tiny.dropFirst())), real.isSuperset(of: .init(real.dropFirst())))
        XCTAssertEqual(tiny.isSuperset(of: .init(tiny.dropLast())),  real.isSuperset(of: .init(real.dropLast())))
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
            
            let expected: [[Int]] = [
                // 1 elements
                [3], [4], [7], [11], [15], [16],
                // 2 elements
                [3,4], [3,7], [3,11], [3,15], [3,16],
                [4,7], [4,11], [4,15], [4,16],
                [7,11], [7,15], [7,16],
                [11,15], [11,16],
                [15,16],
                // 3 elements
                [3,4,7], [3,4,11], [3,4,15], [3,4,16], [3,7,11], [3,7,15], [3,7,16], [3,11,15], [3,11,16], [3,15,16],
                [4,7,11], [4,7,15], [4,7,16], [4,11,15], [4,11,16], [4,15,16],
                [7,11,15], [7,11,16], [7,15,16],
                [11,15,16],
                // 4 elements
                [3,4,7,11], [3,4,7,15], [3,4,7,16], [3,4,11,15], [3,4,11,16], [3,4,15,16], [3,7,11,15], [3,7,11,16], [3,7,15,16], [3,11,15,16],
                [4,7,11,15], [4,7,11,16], [4,7,15,16], [4,11,15,16],
                [7,11,15,16],
                // 5 elements
                [3,4,7,11,15], [3,4,7,11,16], [3,4,7,15,16], [3,4,11,15,16], [3,7,11,15,16],
                [4,7,11,15,16],
                // 6 elements
                [3,4,7,11,15,16],
            ]
            let actual = tiny.combinationsToCheck().map { Array($0) }
            
            XCTAssertEqual(expected.count, actual.count)
            
            // The order of combinations within a given size doesn't matter.
            // It's only important that all combinations of a given size exist and that the sizes are in order.
            let expectedBySize = [Int: [[Int]]](grouping: expected, by: \.count).sorted(by: \.key).map(\.value)
            let actualBySize   = [Int: [[Int]]](grouping: actual,   by: \.count).sorted(by: \.key).map(\.value)
            
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
