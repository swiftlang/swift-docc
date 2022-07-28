/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class TopicGraphHashTests: XCTestCase {
    func testTopicGraphSameHash() throws {
        let hashes: [String] = try (0...10).map { _ -> MetricValue? in
            let (_, context) = try testBundleAndContext(named: "TestBundle")
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.TopicGraphHash(context: context), benchmarkLog: testBenchmark)
            return testBenchmark.metrics[0].result
        }
        .compactMap { value -> String? in
            guard let value = value,
                case MetricValue.checksum(let hash) = value else { return nil }
            return hash
        }
        
        // Verify the produced topic graph hash is repeatedly the same
        XCTAssertTrue(hashes.allSatisfy({ $0 == hashes.first }))
    }
    
    func testTopicGraphChangedHash() throws {
        // Verify that the hash changes if we change the topic graph
        let initialHash: String
        let (_, context) = try testBundleAndContext(named: "TestBundle")
        
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
        let newNode = TopicGraph.Node(reference: .init(bundleIdentifier: #function, path: "/newSymbol", sourceLanguage: .swift), kind: .article, source: .external, title: "External Article")
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
    func testProducesTopicGraphHashWhenResolvedExternalReferencesInTaskGroups() throws {
        // Copy the test bundle and add external links to the MyKit Topics.
        let workspace = DocumentationWorkspace()
        let (tempURL, _, _) = try testBundleAndContext(copying: "TestBundle")
        
        try """
        # ``MyKit``
        MyKit module root symbol
        ## Topics
        ### Task Group
         - <doc:article>
         - <doc:article2>
         - <doc://com.external.testbundle/article>
         - <doc://com.external.testbundle/article2>
        """.write(to: tempURL.appendingPathComponent("documentation").appendingPathComponent("mykit.md"), atomically: true, encoding: .utf8)
        
        // Load the new test bundle
        let dataProvider = try LocalFileSystemDataProvider(rootURL: tempURL)
        guard let bundle = try dataProvider.bundles().first else {
            XCTFail("Failed to create a temporary test bundle")
            return
        }
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        
        // Add external resolver
        context.externalReferenceResolvers = ["com.external.testbundle" : ExternalReferenceResolverTests.TestExternalReferenceResolver()]
        
        // Get MyKit symbol
        let entity = try context.entity(with: .init(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        let taskGroupLinks = try XCTUnwrap((entity.semantic as? Symbol)?.topics?.taskGroups.first?.links.compactMap({ $0.destination }))
        
        // Verify the task group links have been resolved and are still present in the link list.
        XCTAssertEqual(taskGroupLinks, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
            "doc://com.external.testbundle/article",
            "doc://com.external.testbundle/article2",
        ])
        
        // Verify correct hierarchy under `MyKit` in the topic graph dump including external symbols.
        let myKitRef = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift)
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
