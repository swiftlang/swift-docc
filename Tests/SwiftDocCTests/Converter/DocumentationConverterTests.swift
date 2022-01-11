/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


import XCTest
@testable import SwiftDocC

class DocumentationConverterTests: XCTestCase {
    /// An empty implementation of `ConvertOutputConsumer` that purposefully does nothing.
    struct EmptyConvertOutputConsumer: ConvertOutputConsumer {
        func consume(renderNode: RenderNode) throws { }
        func consume(problems: [Problem]) throws { }
        func consume(assetsInBundle bundle: DocumentationBundle) throws {}
        func consume(linkableElementSummaries: [LinkDestinationSummary]) throws {}
        func consume(indexingRecords: [IndexingRecord]) throws {}
        func consume(assets: [RenderReferenceType: [RenderReference]]) throws {}
        func consume(benchmarks: Benchmark) throws {}
        func consume(documentationCoverageInfo: [CoverageDataEntry]) throws {}
    }

    func testThrowsErrorOnConvertingNoBundles() throws {
        let rootURL = try createTemporaryDirectory()

        let dataProvider = try LocalFileSystemDataProvider(rootURL: rootURL)
        let workspace = DocumentationWorkspace()
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        var converter = DocumentationConverter(documentationBundleURL: rootURL, emitDigest: false, documentationCoverageOptions: .noCoverage, currentPlatforms: nil, workspace: workspace, context: context, dataProvider: dataProvider, bundleDiscoveryOptions: BundleDiscoveryOptions())
        XCTAssertThrowsError(try converter.convert(outputConsumer: EmptyConvertOutputConsumer())) { error in
            let converterError = try? XCTUnwrap(error as? DocumentationConverter.Error)
            XCTAssertEqual(converterError?.errorDescription, """
            The directory at '\(rootURL)' and its subdirectories do not contain at least one \
            valid documentation bundle. A documentation bundle is a directory ending in \
            `.docc`.
            """)
        }
    }
}
