/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class ExternalTopicsGraphHashTests: XCTestCase {
    
    let externalResolver = ExternalReferenceResolverTests.TestExternalReferenceResolver()
    let externalSymbolResolver = TestSymbolResolver()
    
    /// A resolver returning mock symbols.
    class TestSymbolResolver: ExternalSymbolResolver {
        func symbolEntity(withPreciseIdentifier preciseIdentifier: String) throws -> DocumentationNode {
            return DocumentationNode(reference: .init(bundleIdentifier: "com.test.symbols", path: "/\(preciseIdentifier)", sourceLanguage: SourceLanguage.swift), kind: .class, sourceLanguage: .swift, name: DocumentationNode.Name.conceptual(title: preciseIdentifier), markup: Paragraph([Text("Docs")]), semantic: nil)
        }
        
        func urlForResolvedSymbol(reference: ResolvedTopicReference) -> URL? {
            return URL(string: "https://host\(reference.path)")!
        }
        
        func preciseIdentifier(forExternalSymbolReference reference: TopicReference) -> String? {
            return nil
        }
    }
    
    func testNoMetricAddedIfNoExternalTopicsAreResolved() throws {
        // Load bundle without using external resolvers
        let (_, context) = try testBundleAndContext(named: "TestBundle")
        XCTAssertTrue(context.externallyResolvedSymbols.isEmpty)
        XCTAssertTrue(context.externallyResolvedLinks.isEmpty)
        
        // Try adding external topics metrics
        let testBenchmark = Benchmark()
        benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
        
        // Verify the metric has no value
        XCTAssertNil(testBenchmark.metrics.first?.result, "Metric was added but there was no external links or symbols")
    }
    
    func testExternalLinksSameHash() throws {
        let externalResolver = self.externalResolver
        
        // Add external links and verify the checksum is always the same
        let hashes: [String] = try (0...10).map { _ -> MetricValue? in
            let (_, _, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # ``SideKit/SideClass``

            Curate some of the children and leave the rest for automatic curation.

            ## Topics
                
            ### External references
            - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol1>
            - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol2>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
            }
            
            // Verify that links were resolved
            XCTAssertFalse(context.externallyResolvedLinks.isEmpty)
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
            
            // Verify that a metric was added
            XCTAssertNotNil(testBenchmark.metrics[0].result)
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

    func testLinksAndSymbolsSameHash() throws {
        let externalResolver = self.externalResolver
        
        // Add external links and verify the checksum is always the same
        let hashes: [String] = try (0...10).map { _ -> MetricValue? in
            let (_, _, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver], externalSymbolResolver: externalSymbolResolver) { url in
            try """
            # ``SideKit/SideClass``

            Curate some of the children and leave the rest for automatic curation.

            ## Topics
                
            ### External references
            - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol1>
            - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol2>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
            }
            
            // Verify that links and symbols were resolved
            XCTAssertFalse(context.externallyResolvedLinks.isEmpty)
            XCTAssertFalse(context.externallyResolvedSymbols.isEmpty)
            
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
            
            // Verify that a metric was added
            XCTAssertNotNil(testBenchmark.metrics[0].result)
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
    
    func testExternalTopicsDetectsChanges() throws {
        let externalResolver = self.externalResolver

        // Load a bundle with external links
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
        try """
        # ``SideKit/SideClass``

        Curate some of the children and leave the rest for automatic curation.

        ## Topics
            
        ### External references
        - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol1>
        - <doc://\(externalResolver.bundleIdentifier)/path/to/external/symbol2>
        """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
    
        XCTAssertFalse(context.externallyResolvedLinks.isEmpty)
        guard !context.externallyResolvedLinks.isEmpty else { return }
        
        // Produce checksum #1
        let testBenchmark = Benchmark()
        benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)

        let result1 = try XCTUnwrap(testBenchmark.metrics.last?.result)
        guard case MetricValue.checksum(let checksum1) = result1 else {
            XCTFail("Didn't produce string checksum #1")
            return
        }
        
        // Remove one external link
        let linkURL = context.externallyResolvedLinks.keys.first!
        let linkReference = context.externallyResolvedLinks[linkURL]!
        context.externallyResolvedLinks.removeValue(forKey: linkURL)
        
        // Produce checksum #2
        benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)

        let result2 = try XCTUnwrap(testBenchmark.metrics.last?.result)
        guard case MetricValue.checksum(let checksum2) = result2 else {
            XCTFail("Didn't produce string checksum #2")
            return
        }
        
        XCTAssertNotEqual(checksum1, checksum2, "The checksum didn't change when a link was removed")
        
        // Add back the same external link
        context.externallyResolvedLinks[linkURL] = linkReference
        
        // Produce checksum #3
        benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)

        let result3 = try XCTUnwrap(testBenchmark.metrics.last?.result)
        guard case MetricValue.checksum(let checksum3) = result3 else {
            XCTFail("Didn't produce string checksum #3")
            return
        }
        
        XCTAssertNotEqual(checksum2, checksum3, "The checksum didn't change when a link was added back")
        XCTAssertEqual(checksum1, checksum3, "The checksum wasn't identical for identical sources")
    }
}
