/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@_spi(ExternalLinks) @testable import SwiftDocC
import Markdown
import DocCCommon
import DocCTestUtilities

class ExternalTopicsGraphHashTests: XCTestCase {
    
    let externalResolver = ExternalReferenceResolverTests.TestExternalReferenceResolver()
    let externalSymbolResolver = TestSymbolResolver()
    
    /// A resolver returning mock symbols.
    class TestSymbolResolver: GlobalExternalSymbolResolver {
        func symbolReferenceAndEntity(withPreciseIdentifier preciseIdentifier: String) -> (ResolvedTopicReference, LinkResolver.ExternalEntity)? {
            let reference = ResolvedTopicReference(bundleID: "com.test.symbols", path: "/\(preciseIdentifier)", sourceLanguage: SourceLanguage.swift)
            let entity = LinkResolver.ExternalEntity(
                kind: .class,
                language: .swift,
                relativePresentationURL: URL(string: "/\(preciseIdentifier)")!,
                referenceURL: reference.url,
                title: preciseIdentifier,
                availableLanguages: [.swift],
                variants: []
            )
            return (reference, entity)
        }
    }
    
    /// A catalog with one symbol whose in-source documentation is the provided markdown.
    private func makeExampleCatalog(markdown: String) -> Folder {
        Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something", symbols: [
                makeSymbol(id: "some-class-id", kind: .class, pathComponents: ["SomeClass"], docComment: markdown),
            ]))
        }
    }
    
    func testNoMetricAddedIfNoExternalTopicsAreResolved() async throws {
        // Load bundle without using external resolvers
        let (_, context) = try await loadBundle(catalog: Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "Something"))
        })
        XCTAssertTrue(context.externallyResolvedLinks.isEmpty)
        
        // Try adding external topics metrics
        let testBenchmark = Benchmark()
        benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
        
        // Verify the metric has no value
        XCTAssertNil(testBenchmark.metrics.first?.result, "Metric was added but there was no external links or symbols")
    }
    
    func testExternalLinksSameHash() async throws {
        let externalResolver = self.externalResolver
        
        // Add external links and verify the checksum is always the same
        func computeTopicHash() async throws -> String {
            let catalog = self.makeExampleCatalog(markdown: """
            Curate some external links.

            ## Topics
                
            ### External references
            - <doc://\(externalResolver.bundleID)/path/to/external/symbol1>
            - <doc://\(externalResolver.bundleID)/path/to/external/symbol2>
            """)
            var configuration = DocumentationContext.Configuration()
            configuration.externalDocumentationConfiguration.sources = [externalResolver.bundleID: externalResolver]
            let (_, context) = try await self.loadBundle(catalog: catalog, configuration: configuration)
            
            // Verify that links were resolved
            XCTAssertFalse(context.externallyResolvedLinks.isEmpty)
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
            
            return try TopicAnchorHashTests.extractChecksumHash(from: testBenchmark)
        }
        
        let expectedHash = try await computeTopicHash()
        
        // Verify the produced topic graph hash is repeatedly the same
        for _ in 0 ..< 10 {
            let hash = try await computeTopicHash()
            XCTAssertEqual(hash, expectedHash)
        }
    }

    func testLinksAndSymbolsSameHash() async throws {
        let externalResolver = self.externalResolver
        
        // Add external links and verify the checksum is always the same
        func computeTopicHash() async throws -> String {
            let catalog = self.makeExampleCatalog(markdown: """
            Curate some external links.

            ## Topics
                
            ### External references
            - <doc://\(externalResolver.bundleID)/path/to/external/symbol1>
            - <doc://\(externalResolver.bundleID)/path/to/external/symbol2>
            """)
            var configuration = DocumentationContext.Configuration()
            configuration.externalDocumentationConfiguration.sources = [externalResolver.bundleID: externalResolver]
            configuration.externalDocumentationConfiguration.globalSymbolResolver = self.externalSymbolResolver
            let (_, context) = try await self.loadBundle(catalog: catalog, configuration: configuration)
            
            // Verify that links and symbols were resolved
            XCTAssertFalse(context.externallyResolvedLinks.isEmpty)
            
            let testBenchmark = Benchmark()
            benchmark(add: Benchmark.ExternalTopicsHash(context: context), benchmarkLog: testBenchmark)
            
            return try TopicAnchorHashTests.extractChecksumHash(from: testBenchmark)
        }
        
        let expectedHash = try await computeTopicHash()
        
        // Verify the produced topic graph hash is repeatedly the same
        for _ in 0 ..< 10 {
            let hash = try await computeTopicHash()
            XCTAssertEqual(hash, expectedHash)
        }
    }
    
    func testExternalTopicsDetectsChanges() async throws {
        let externalResolver = self.externalResolver

        // Load a bundle with external links
        let catalog = makeExampleCatalog(markdown: """
        Curate some external links.

        ## Topics
            
        ### External references
        - <doc://\(externalResolver.bundleID)/path/to/external/symbol1>
        - <doc://\(externalResolver.bundleID)/path/to/external/symbol2>
        """)
        var configuration = DocumentationContext.Configuration()
        configuration.externalDocumentationConfiguration.sources = [externalResolver.bundleID: externalResolver]
        let (_, context) = try await loadBundle(catalog: catalog, configuration: configuration)
    
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
