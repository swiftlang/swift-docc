/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DurationTests: XCTestCase {
    func testDuration() {
        let testBenchmark = Benchmark()
        let metric = benchmark(begin: Benchmark.Duration(id: "test"), benchmarkLog: testBenchmark)
        Thread.sleep(forTimeInterval: 2)
        benchmark(end: metric, benchmarkLog: testBenchmark)
        
        XCTAssertNotNil(metric)
        XCTAssertEqual(metric?.identifier, "duration-test")
        guard let metricResult = metric?.result, case MetricValue.duration(let result) = metricResult else {
            XCTFail("Metric result wasn't the expected type")
            return
        }
        
        // We're very forgiving with the accuracy (±10%) of this comparison to avoid flaky tests.
        // Thread.sleep can vary small amounts and we only need to know that time measuring functionality worked.
        XCTAssertEqual(result, 2, accuracy: 0.2) 
    }
}
