/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicAnchorHashTests: XCTestCase {
    func testAnchorSectionsHash() async throws {
        func computeTopicHash(file: StaticString = #filePath, line: UInt = #line) async throws -> String {
            let (_, context) = try await self.loadFromDisk(catalogName: "BundleWithLonelyDeprecationDirective")
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicAnchorHash(context: context), benchmarkLog: testBenchmark)
            
            return try Self.extractChecksumHash(from: testBenchmark)
        }

        let expectedHash = try await computeTopicHash()
        
        // Verify the produced topic graph hash is repeatedly the same
        for _ in 0 ..< 10 {
            let hash = try await computeTopicHash()
            XCTAssertEqual(hash, expectedHash)
        }
    }
    
    func testTopicAnchorsChangedHash() async throws {
        // Verify that the hash changes if we change the topic graph
        let initialHash: String
        let context = try await loadFromDisk(catalogName: "BundleWithLonelyDeprecationDirective")
        
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
        let newReference = ResolvedTopicReference(bundleID: "com.bundle.id", path: "/documentation/new#section", sourceLanguage: .swift)
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

    static func extractChecksumHash(
        from benchmark: Benchmark,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> String {
        let hash: String? = switch benchmark.metrics[0].result {
            case .checksum(let hash):
                hash
            default:
                nil
        }
        return try XCTUnwrap(hash, file: file, line: line)
    }
}
