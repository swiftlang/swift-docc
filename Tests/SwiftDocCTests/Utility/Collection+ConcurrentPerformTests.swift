/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class CollectionConcurrentPerformTests: XCTestCase {
    let digits = Array(0..<103)
    
    typealias TimedResult = (start: TimeInterval, end: TimeInterval)
    
    // MARK: - `Collection.concurrentPerform()`
    
    func testNoResultForEmptyCollection() {
        let results: [Int] = [Int]().concurrentPerform { (_, results) in
            results.append(1)
        }
        
        // Verify no results were produced when input is empty
        XCTAssertTrue(results.isEmpty, "Run the block but no elements in collection")
    }
    
    func testAllBlocksRun() {
        for limit in [0, 1, 3, 10, 24, 64, 100] {
            let values = digits.prefix(limit)
            let results: [Int] = values.concurrentPerform { (value, results) in
                results.append(value)
            }
            // Verify all elements were processed for the given amount of elements
            XCTAssertEqual(values.sorted(), results.sorted(), "Didn't process all elements for \(values.count) elements.")
        }
    }

    func testAllBlocksHighConcurrencyRun() {
        let digits = Array(0..<10000)
        let results: [Int] = digits.concurrentPerform(batches: 100) { (value, results) in
            results.append(value)
        }
        
        // Verify all elements were processed with high concurrency
        XCTAssertEqual(digits.sorted(), results.sorted(), "Didn't process all elements for 10000 elements.")
    }

    func testSerialConcurrentPerform() {
        let results: [TimedResult] = digits.concurrentPerform(batches: 1) { value, results in
            let begin = ProcessInfo.processInfo.systemUptime
            Thread.sleep(forTimeInterval: 0.01)
            let end = ProcessInfo.processInfo.systemUptime
            results.append((begin, end))
        }
        
        // Verify that each next block has started after the previous block has finished.
        for (result, next) in zip(results, results.dropFirst()) {
            XCTAssertTrue(next.start >= result.end,
                          "Blocks didn't run serially; \(result.end) not before \(next.start)")
        }
    }

    func testConcurrentPerform() {
        let results: [TimedResult] = digits.prefix(4).concurrentPerform(batches: 10) { value, results in
            let begin = ProcessInfo.processInfo.systemUptime
            Thread.sleep(forTimeInterval: 0.5)
            let end = ProcessInfo.processInfo.systemUptime
            results.append((begin, end))
        }
        
        let didBlocksExecuteConcurrently = zip(results, results.dropFirst())
            .allSatisfy({ result, next -> Bool in
                return next.start < result.end
            })

        #if os(macOS) || os(iOS)
        // Expect all blocks ran concurrently on supported platforms.
        XCTAssertTrue(didBlocksExecuteConcurrently, "Blocks didn't run concurrently")
        #else
        // Expect all blocks ran serially on other platforms.
        XCTAssertFalse(didBlocksExecuteConcurrently, "Blocks didn't run serially")
        #endif
    }
    
    // MARK: - `Collection.concurrentMap()`
    
    func testNoResultForEmptyCollectionMap() {
        let results: [String] = [Int]().concurrentMap { "\($0)" }
        
        // Verify no results were produced when input is empty
        XCTAssertTrue(results.isEmpty, "Run the block but no elements in collection")
    }
    
    func testMapsAllElementsInOrder() {
        // Makes multiple runs of various sizes to verify concurrent map is always identical to serial map.
        for _ in 0 ... 100 {
            for limit in [0, 1, 3, 10, 24, 64, 100] {
                let values = digits.prefix(limit)
                let results: [String] = values.concurrentMap { "\($0)" }
                
                let expectedResult = values.map({ "\($0)" })
                
                // Verify the results of map and concurrentMap are identical
                XCTAssertEqual(expectedResult, results, "Didn't process all elements for \(values.count) elements.")
            }
        }
    }
    
    func testConcurrentMap() {
        let results: [TimedResult] = digits.prefix(4).concurrentMap(batches: 10) { value in
            let begin = ProcessInfo.processInfo.systemUptime
            Thread.sleep(forTimeInterval: 0.5)
            let end = ProcessInfo.processInfo.systemUptime
            return (begin, end)
        }
        
        let didBlocksExecuteConcurrently = zip(results, results.dropFirst())
            .allSatisfy({ result, next -> Bool in
                return next.start < result.end
            })
        
        #if os(macOS) || os(iOS)
        // Expect all blocks ran concurrently on supported platforms.
        XCTAssertTrue(didBlocksExecuteConcurrently, "Blocks didn't run concurrently")
        #else
        // Expect all blocks ran serially on other platforms.
        XCTAssertFalse(didBlocksExecuteConcurrently, "Blocks didn't run serially")
        #endif
    }
}
