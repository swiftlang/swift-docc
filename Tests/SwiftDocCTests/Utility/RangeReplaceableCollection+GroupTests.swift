/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RangeReplaceableCollection_GroupTests: XCTestCase {

    func testGroupingEverythingIndividual() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        XCTAssertEqual(numbers.group(asLongAs: { _, _ in false }),
                       [[1], [2], [3], [4], [5], [6], [7], [8], [9]])
    }
    
    func testGroupingEverythingGrouped() {
        let numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]
        XCTAssertEqual(numbers.group(asLongAs: { _, _ in true }),
                       [[1, 2, 3, 4, 5, 6, 7, 8, 9]])
    }

    func testGroupingEqualElementsGrouped() {
        let numbers = [0, 1, 1, 0, 1, 0, 0, 0, 1, 0, 0]
        XCTAssertEqual(numbers.group(asLongAs: { previous, current in previous == current }),
                       [[0], [1, 1], [0], [1], [0, 0, 0], [1], [0, 0]])
    }
}
