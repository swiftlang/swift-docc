/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class RatioStatisticTests: XCTestCase {
    func testPercentageStringZeroOverZero() throws {
        let expected = "(0/0)"
        let result = RatioStatistic.percentageString(numerator: 0, denominator: 0)
        XCTAssertEqual(result, expected)
    }

    func testInvalidDocumentedThrows() {
        XCTAssertThrowsError(try RatioStatistic(documented: -1, total: 10))
    }

    func testInvalidTotalThrows() {
        XCTAssertThrowsError(try RatioStatistic(documented: 0, total: -10))
    }

    func testOneOverTwo() {
        try XCTAssertEqual(RatioStatistic(documented: 1, total: 2).description, ratio(1, 2))
    }

    func testNoneOverTen() {
        try XCTAssertEqual(RatioStatistic(documented: 0, total: 10).description, ratio(0, 10))
    }

    func testThreeOverThree() {
        try XCTAssertEqual(RatioStatistic(documented: 3, total: 3).description, ratio(3, 3))
    }

    func testThirteenThousandFiveHundredOverNineThousand() {
        try XCTAssertEqual(RatioStatistic(documented: 13500, total: 9000).description, ratio(13500, 9000))
    }
}
