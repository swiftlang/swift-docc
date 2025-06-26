/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicGraphHashTests: XCTestCase {
    func testTopicGraphSameHash() async throws {
        func computeTopicHash(file: StaticString = #filePath, line: UInt = #line) async throws -> String {
            let (_, context) = try await self.testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicGraphHash(context: context), benchmarkLog: testBenchmark)
            
            return try TopicAnchorHashTests.extractChecksumHash(from: testBenchmark)
        }

        let expectedHash = try await computeTopicHash()
        
        // Verify the produced topic graph hash is repeatedly the same
        for _ in 0 ..< 10 {
            let hash = try await computeTopicHash()
            XCTAssertEqual(hash, expectedHash)
        }
    }
    
    func testTopicGraphChangedHash() async throws {
        // Verify that the hash changes if we change the topic graph
        let initialHash: String
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        do {
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicGraphHash(context: context), benchmarkLog: testBenchmark)
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
        
        // Here we'll add a completely new node and curated it in the topic graph
        let newNode = TopicGraph.Node(reference: .init(bundleID: #function, path: "/newSymbol", sourceLanguage: .swift), kind: .article, source: .external, title: "External Article")
        context.topicGraph.addNode(newNode)
        // We can force unwrap below because we're guaranteed to find at least one node which is not `newNode`
        context.topicGraph.addEdge(from: context.topicGraph.nodes.values.first(where: { existingNode -> Bool in
            // We need to do that to avoid adding an edge from the new node to itself.
            return existingNode != newNode
        })!, to: newNode)

        // Now verify that the topic hash changed after the change
        let modifiedHash: String
        do {
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicGraphHash(context: context), benchmarkLog: testBenchmark)
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
    
    /// Verify that we safely produce the topic graph hash when external symbols
    /// participate in the documentation hierarchy. rdar://76419740
    func testProducesTopicGraphHashWhenResolvedExternalReferencesInTaskGroups() async throws {
        let resolver = TestMultiResultExternalReferenceResolver()
        resolver.entitiesToReturn = [
            "/article": .success(.init(referencePath: "/externally/resolved/path/to/article")),
            "/article2": .success(.init(referencePath: "/externally/resolved/path/to/article2")),
            
            "/externally/resolved/path/to/article": .success(.init(referencePath: "/externally/resolved/path/to/article")),
            "/externally/resolved/path/to/article2": .success(.init(referencePath: "/externally/resolved/path/to/article2")),
        ]
        
        let (_, bundle, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", externalResolvers: [
            "com.external.testbundle" : resolver
        ]) { url in
            // Add external links to the MyKit Topics.
            try """
            # ``MyKit``
            MyKit module root symbol
            ## Topics
            ### Task Group
             - <doc:article>
             - <doc:article2>
             - <doc://com.external.testbundle/article>
             - <doc://com.external.testbundle/article2>
            """.write(to: url.appendingPathComponent("documentation").appendingPathComponent("mykit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get MyKit symbol
        let entity = try context.entity(with: .init(bundleID: bundle.id, path: "/documentation/MyKit", sourceLanguage: .swift))
        let taskGroupLinks = try XCTUnwrap((entity.semantic as? Symbol)?.topics?.taskGroups.first?.links.compactMap({ $0.destination }))
        
        // Verify the task group links have been resolved and are still present in the link list.
        XCTAssertEqual(taskGroupLinks, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
            "doc://com.external.testbundle/externally/resolved/path/to/article",
            "doc://com.external.testbundle/externally/resolved/path/to/article2",
        ])
        
        // Verify correct hierarchy under `MyKit` in the topic graph dump including external symbols.
        let myKitRef = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/MyKit", sourceLanguage: .swift)
        let myKitNode = try XCTUnwrap(context.topicGraph.nodeWithReference(myKitRef))
        
        let expectedHierarchyWithExternalSymbols = """
         MyKit
         ├ MyProtocol
         │ ╰ MyClass
         │   ├ init()
         │   ├ init()
         │   ╰ myFunction()
         ├ globalFunction(_:considering:)
         ├ My Cool Article
         │ ├ Article 2
         │ ├ Article 3
         │ ╰ Basic Augmented Reality App
         │   ├ Create a New AR Project 💻
         │   ├ Initiate ARKit Plane Detection
         │   ╰ Duplicate
         ╰ Article 2
        """.trimmingLines()
        
        XCTAssertEqual(expectedHierarchyWithExternalSymbols, context.topicGraph.dump(startingAt: myKitNode).trimmingLines())
        
        // Verify we safely create topic graph dump and its hash metric.
        let testBenchmark = Benchmark()
        benchmark(add: Benchmark.TopicGraphHash(context: context), benchmarkLog: testBenchmark)
        guard let value = testBenchmark.metrics.first?.result,
            case MetricValue.checksum = value else {
            XCTFail("Unexpected metric value")
            return
        }
    }
}
