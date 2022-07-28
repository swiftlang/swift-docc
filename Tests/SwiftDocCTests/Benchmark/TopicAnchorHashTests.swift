/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicAnchorHashTests: XCTestCase {
    func testAnchorSectionsHash() throws {
        let hashes: [String] = try (0...10).map { _ -> MetricValue? in
            let (_, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicAnchorHash(context: context), benchmarkLog: testBenchmark)
            return testBenchmark.metrics[0].result
        }
        .compactMap { value -> String? in
            guard case MetricValue.checksum(let hash)? = value else { return nil }
            return hash
        }
        
        // Verify the produced topic graph hash is repeatedly the same
        XCTAssertTrue(hashes.allSatisfy({ $0 == hashes.first }))
    }
    
    func testTopicAnchorsChangedHash() throws {
        // Verify that the hash changes if we change the topic graph
        let initialHash: String
        let (_, context) = try testBundleAndContext(named: "BundleWithLonelyDeprecationDirective")
        
        do {
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicAnchorHash(context: context), benchmarkLog: testBenchmark)
            guard let value = testBenchmark.metrics.first?.result,
                case MetricValue.checksum(let hash) = value else {
                XCTFail("Unexpected metric value")
                return
            }
            initialHash = hash
        }

        guard context.topicGraph.nodes.values.count > 2 else {
            XCTFail("Test bundle topic graph contains too few nodes")
            return
        }
        
        // Add a new section to verify that the hash will change
        let newReference = ResolvedTopicReference(bundleIdentifier: "com.bundle.id", path: "/documentation/new#section", sourceLanguage: .swift)
        context.nodeAnchorSections[newReference] = AnchorSection(reference: newReference, title: "New Sub-section")

        // Now verify that the topic anchor hash changed after the change
        let modifiedHash: String
        do {
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicAnchorHash(context: context), benchmarkLog: testBenchmark)
            guard let value = testBenchmark.metrics.first?.result,
                case MetricValue.checksum(let hash) = value else {
                XCTFail("Unexpected metric value")
                return
            }
            modifiedHash = hash
        }

        // Verify that the hash is not the same
        XCTAssertNotEqual(initialHash, modifiedHash)
    }

}
