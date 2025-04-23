/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC
import SwiftDocCTestUtilities
import XCTest

class DeprecatedDiagnosticsDigestWarningTests: XCTestCase {
    func testNoDeprecationWarningWhenThereAreNoOtherWarnings() throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: """
            # Root
            
            An empty root page
            """)
        ])
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        let outputConsumer = TestOutputConsumer()
        
        _ = try ConvertActionConverter.convert(
            bundle: bundle,
            context: context,
            outputConsumer: outputConsumer,
            sourceRepository: nil,
            emitDigest: true,
            documentationCoverageOptions: .noCoverage
        )
        
        XCTAssert(outputConsumer.problems.isEmpty, "Unexpected problems: \(outputConsumer.problems.map(\.diagnostic.summary).joined(separator: "\n"))")
    }
    
    func testDeprecationWarningWhenThereAreOtherWarnings() throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: """
            # Root
            
            An empty root page
            
            This link will result in a warning: ``NotFound``.
            """)
        ])
        let (bundle, context) = try loadBundle(catalog: catalog)
        
        let outputConsumer = TestOutputConsumer()
        
        _ = try ConvertActionConverter.convert(
            bundle: bundle,
            context: context,
            outputConsumer: outputConsumer,
            sourceRepository: nil,
            emitDigest: true,
            documentationCoverageOptions: .noCoverage
        )
        
        XCTAssertEqual(outputConsumer.problems.count, 2, "Unexpected problems: \(outputConsumer.problems.map(\.diagnostic.summary).joined(separator: "\n"))")
        
        let deprecationWarning = try XCTUnwrap(outputConsumer.problems.first?.diagnostic)
        
        XCTAssertEqual(deprecationWarning.identifier, "org.swift.docc.DeprecatedDiagnosticsDigets")
        XCTAssertEqual(deprecationWarning.summary, "The 'diagnostics.json' digest file is deprecated and will be removed after 6.2 is released. Pass a `--diagnostics-file <diagnostics-file>` to specify a custom location where DocC will write a diagnostics JSON file with more information.")
    }
}

private class TestOutputConsumer: ConvertOutputConsumer {
    var problems: [Problem] = []
    
    func consume(problems: [Problem]) throws {
        self.problems.append(contentsOf: problems)
    }
    
    func consume(renderNode: RenderNode) throws { }
    func consume(assetsInBundle bundle: DocumentationBundle) throws { }
    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws { }
    func consume(indexingRecords: [IndexingRecord]) throws { }
    func consume(assets: [RenderReferenceType: [any RenderReference]]) throws { }
    func consume(benchmarks: Benchmark) throws { }
    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws { }
    func consume(renderReferenceStore: RenderReferenceStore) throws { }
    func consume(buildMetadata: BuildMetadata) throws { }
    func consume(linkResolutionInformation: SerializableLinkResolutionInformation) throws { }
}
