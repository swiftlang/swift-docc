/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import benchmark

final class StatisticsTests: XCTestCase {
    
    func testStandardDeviation() throws {
        let values = [1.14, 4.08, 6.58, 9.54, 9.72]
        
        XCTAssertEqual(values.mean(), 6.212, accuracy: 0.000_001)
        XCTAssertEqual(values.standardDeviation(degreesOfFreedom: 1), 3.667_004_226, accuracy: 0.000_001)
        XCTAssertEqual(values.standardDeviation(degreesOfFreedom: 0), 3.279_868_290, accuracy: 0.000_001)
    }
    
    func testFitLinearRegression() throws {
        let xs = [10.91, 11.98, 14.36, 14.47, 14.70, 14.77, 15.33, 15.80, 16.01, 16.24, 17.26, 17.59, 17.93, 18.32, 19.25]
        let ys = [40.60, 42.70, 47.96, 50.21, 53.60, 54.17, 55.34, 56.75, 57.43, 60.75, 65.75, 67.65, 69.17, 72.46, 78.91]
        
        let points = Array(zip(xs, ys))
        
        let (constant, slope) = fitSimpleLinearRegression(points)
        XCTAssertEqual(constant, -14.996, accuracy: 0.001)
        XCTAssertEqual(slope, 4.676, accuracy: 0.001)
    }
    
    func testTTest() throws {
        // Two samples of 6 random numbers in the range [45, 55]
        let lhs = [48.58, 51.74, 49.59, 47.93, 48.80, 52.82]
        let rhs = [46.22, 48.53, 45.67, 52.88, 52.73, 47.24]
        
        do {
            let result = independentTTest(lhs, rhs)
            
            // Both series are from the same random distribution and should be considered the same.
            XCTAssertEqual(result.seriesAreProbablyTheSame, true)
            
            XCTAssertEqual(result.tStatistic, 0.676, accuracy: 0.001)
            XCTAssertEqual(result.criticalValue, 2.179, accuracy: 0.001)
            XCTAssertEqual(result.degreesOfFreedom, 10)
        }
        
        do {
            let result = independentTTest(lhs.dropLast(3), rhs.dropLast(3))
            
            // With too few values in each sample, we can no longer be confident that the samples are the same.
            XCTAssertEqual(result.seriesAreProbablyTheSame, false)
            
            XCTAssertEqual(result.tStatistic, 2.473, accuracy: 0.001)
            XCTAssertEqual(result.criticalValue, 2.447, accuracy: 0.001)
            XCTAssertEqual(result.degreesOfFreedom, 4)
        }
        
        do {
            let result = independentTTest(lhs.map { $0 + 5.0 }, rhs)
            
            // If we modify the value one of the sample's so that it represents a different random distribution,
            // then the samples are no longer the same.
            XCTAssertEqual(result.seriesAreProbablyTheSame, false)
            
            XCTAssertEqual(result.tStatistic, 3.952, accuracy: 0.001)
            XCTAssertEqual(result.criticalValue, 2.179, accuracy: 0.001)
            XCTAssertEqual(result.degreesOfFreedom, 10)
        }
    }
    
    func testIsProbablyReasonablyNonBiased() {
        // 6 random numbers in the range [45, 55]
        let values = [48.58, 51.74, 49.59, 47.93, 48.80, 52.82]
        
        // Random values should not show signs of a linear trend.
        XCTAssertEqual(values.looksReasonablyNonBiased(), true)
        
        // Sorting the values in either direction gives it a strong linear trend
        XCTAssertEqual(values.sorted(by: <).looksReasonablyNonBiased(), false)
        XCTAssertEqual(values.sorted(by: >).looksReasonablyNonBiased(), false)
        
    }
}
