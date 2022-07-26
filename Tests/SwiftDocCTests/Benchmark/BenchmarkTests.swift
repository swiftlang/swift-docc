/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

/// A test metric to use for tests.
class TestMetric: BenchmarkMetric, BenchmarkBlockMetric, DynamicallyIdentifiableMetric {
    let identifier = "com.tests.DynamicMetric"
    let displayName = "Dynamic Metric"
    
    static let identifier = "com.tests.TestMetric"
    static let displayName = "Test Metric"
    let result: MetricValue? = .checksum("Result")
    
    var didBegin = false
    var didEnd = false

    init() { }

    init(didInit: inout Bool) {
        didInit = true
    }
    
    func begin() { didBegin = true }
    func end() { didEnd = true }
}

class BenchmarkTests: XCTestCase {
    func testInitialState() {
        let testBenchmark = Benchmark()
        XCTAssertTrue(testBenchmark.metrics.isEmpty)
    }
    
    func testOneOffMetric() {
        let testBenchmark = Benchmark()
        
        // Add a one-off metric
        benchmark(add: TestMetric(), benchmarkLog: testBenchmark)
        
        XCTAssertEqual(testBenchmark.metrics.count, 1)
        guard testBenchmark.metrics.count == 1 else { return }
        
        // Verify the metric details
        XCTAssertEqual(type(of: testBenchmark.metrics[0]).identifier, "com.tests.TestMetric")
    }

    func testRangeMetric() {
        let testBenchmark = Benchmark()
        
        // Test metric initial state
        let metric = TestMetric()
        XCTAssertFalse(metric.didBegin)
        XCTAssertFalse(metric.didEnd)
        
        // Test metric has begun
        _ = benchmark(begin: metric, benchmarkLog: testBenchmark)
        XCTAssertTrue(metric.didBegin)
        XCTAssertFalse(metric.didEnd)
        
        // Test metric has ended
        benchmark(end: metric, benchmarkLog: testBenchmark)
        XCTAssertTrue(metric.didBegin)
        XCTAssertTrue(metric.didEnd)
    }
    
    func testFilteredMetric() {
        // Verify exact filter query
        do {
            let testBenchmark = Benchmark(metricsFilter: "com.tests.TestMetric")
            benchmark(add: TestMetric(), benchmarkLog: testBenchmark)
            benchmark(end: benchmark(begin: TestMetric(), benchmarkLog: testBenchmark), benchmarkLog: testBenchmark)
            XCTAssertEqual(testBenchmark.metrics.count, 2)
        }
        
        // Verify partial filter query
        do {
            let testBenchmark = Benchmark(metricsFilter: "com.tests")
            benchmark(add: TestMetric(), benchmarkLog: testBenchmark)
            benchmark(end: benchmark(begin: TestMetric(), benchmarkLog: testBenchmark), benchmarkLog: testBenchmark)
            XCTAssertEqual(testBenchmark.metrics.count, 2)
        }
        
        // Verify non-matching filter query
        do {
            let testBenchmark = Benchmark(metricsFilter: "com.mests")
            benchmark(add: TestMetric(), benchmarkLog: testBenchmark)
            benchmark(end: benchmark(begin: TestMetric(), benchmarkLog: testBenchmark), benchmarkLog: testBenchmark)
            XCTAssertEqual(testBenchmark.metrics.count, 0)
            
            // Verify filtered range metric returns nil
            XCTAssertNil(benchmark(begin: TestMetric(), benchmarkLog: testBenchmark))
        }
    }
    
    func testFilteredMetricInit() {
        // Verify exact filter query
        do {
            var didInitializeTheMetric = false

            let testBenchmark = Benchmark(metricsFilter: "com.tests.TestMetric")
            benchmark(add: TestMetric(didInit: &didInitializeTheMetric), benchmarkLog: testBenchmark)
            XCTAssertTrue(didInitializeTheMetric)

            // Verify exact filter query
            didInitializeTheMetric = false
            _ = benchmark(begin: TestMetric(didInit: &didInitializeTheMetric), benchmarkLog: testBenchmark)
            XCTAssertTrue(didInitializeTheMetric)
        }
        
        // Verify with non-matching query
        do {
            var didInitializeTheMetric = false

            let testBenchmark = Benchmark(metricsFilter: "com.mests")
            benchmark(add: TestMetric(didInit: &didInitializeTheMetric), benchmarkLog: testBenchmark)
            XCTAssertFalse(didInitializeTheMetric)

            // Verify with non-matching query
            didInitializeTheMetric = false
            _ = benchmark(begin: TestMetric(didInit: &didInitializeTheMetric), benchmarkLog: testBenchmark)
            XCTAssertFalse(didInitializeTheMetric)
        }
    }
    
    func testDynamicMetrics() throws {
        // Encode a dynamic metric
        let testBenchmark = Benchmark()
        benchmark(add: TestMetric(), benchmarkLog: testBenchmark)
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(testBenchmark)
        
        // Verify the dynamic id and name were encoded
        let result = try JSONDecoder().decode(BenchmarkResults.self, from: data)
        let metric = try XCTUnwrap(result.metrics.first)
        
        XCTAssertEqual(metric.id, "com.tests.DynamicMetric")
        XCTAssertEqual(metric.displayName, "Dynamic Metric")
    }
    
    func testRangeMetricWithBlock() {
        let testBenchmark = Benchmark()
        
        // Test metric initial state
        let metric = TestMetric()
        XCTAssertFalse(metric.didBegin)
        XCTAssertFalse(metric.didEnd)
        
        // Test metric has begun
        benchmark(wrap: metric, benchmarkLog: testBenchmark) {
            XCTAssertTrue(metric.didBegin)
            XCTAssertFalse(metric.didEnd)
        }
        
        // Test metric has ended
        XCTAssertTrue(metric.didBegin)
        XCTAssertTrue(metric.didEnd)
    }

    func testRangeMetricWithBlockReturns() {
        // Test with enabled benchmark
        do {
            let testBenchmark = Benchmark(isEnabled: true)
            let result = benchmark(wrap: TestMetric(), benchmarkLog: testBenchmark) {
                return "12345"
            }
            XCTAssertEqual("12345", result)
        }
        
        // Test with disabled benchmark
        do {
            let testBenchmark = Benchmark(isEnabled: false)
            let result = benchmark(wrap: TestMetric(), benchmarkLog: testBenchmark) {
                return "12345"
            }
            XCTAssertEqual("12345", result)
        }
    }
}
