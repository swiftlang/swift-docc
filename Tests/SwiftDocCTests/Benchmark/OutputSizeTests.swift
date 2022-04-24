/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class OutputSizeTests: XCTestCase {
    func testOutputSize() throws {
        // Create a faux output folder
        let writeURL = try createTemporaryDirectory(named: "data")
        
        // Write a 2MB file
        let data = Data(repeating: 1, count: 2 * 1024 * 1024)
        try data.write(to: writeURL.appendingPathComponent("temp.bin"))
        
        // Benchmark the directory size
        let testBenchmark = Benchmark()
        benchmark(add: Benchmark.DataDirectoryOutputSize(dataDirectory: writeURL), benchmarkLog: testBenchmark)
        
        XCTAssertEqual(testBenchmark.metrics.count, 1)
        guard testBenchmark.metrics.count == 1 else { return }
        
        // Verify the logged size
        guard let metricValue = testBenchmark.metrics[0].result, case MetricValue.bytesOnDisk(let result) = metricValue else {
            XCTFail("Unexpected metric result type")
            return
        }
        
        XCTAssertEqual(result, 2 * 1024 * 1024)
    }
}
