/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC
@testable import SwiftDocCUtilities

class ConvertActionIndexerTests: XCTestCase {
    
    // Tests the standalone indexer
    func testConvertActionIndexer() throws {
        let originalURL = Bundle.module.url(
            forResource: "TestCatalog", withExtension: "docc", subdirectory: "Test Catalogs")!
        
        // Create temo folder.
        let url = try createTemporaryDirectory()
        
        // Copy TestCatalog into a temp folder
        let testCatalogURL = url.appendingPathComponent("TestCatalog.docc")
        try FileManager.default.copyItem(at: originalURL, to: testCatalogURL)
        
        // Load the test catalog
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: testCatalogURL)
        try workspace.registerProvider(dataProvider)

        guard !context.registeredCatalogs.isEmpty else {
            XCTFail("Didn't load test catalog in test.")
            return
        }

        let converter = DocumentationNodeConverter(catalog: context.registeredCatalogs.first!, context: context)
        
        // Add /documentation/MyKit to the index, verify the tree dump
        do {
            let reference = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let renderNode = try converter.convert(context.entity(with: reference), at: nil)

            try FileManager.default.createDirectory(at: testCatalogURL.appendingPathComponent("index1"), withIntermediateDirectories: false, attributes: nil)
            let indexer = try ConvertAction.Indexer(outputURL: testCatalogURL.appendingPathComponent("index1"), catalogIdentifier: context.registeredCatalogs.first!.identifier)
            indexer.index(renderNode)
            XCTAssertTrue(indexer.finalize(emitJSON: false, emitLMDB: false).isEmpty)
            let treeDump = try XCTUnwrap(indexer.dumpTree())
            XCTAssertEqual(treeDump, """
            [Root]
            ┗╸Swift
              ┗╸MyKit
                ┣╸Basics
                ┣╸MyKit in Practice
                ┣╸Global symbols
                ┗╸Extensions to other frameworks
            """)
        }

        // Add two nodes /documentation/MyKit and /documentation/Test-Catalog/Default-Code-Listing-Syntax to the index
        // and verify the tree.
        do {
            let reference1 = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let renderNode1 = try converter.convert(context.entity(with: reference1), at: nil)

            let reference2 = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: "/documentation/Test-Catalog/Default-Code-Listing-Syntax", sourceLanguage: .swift)
            let renderNode2 = try converter.convert(context.entity(with: reference2), at: nil)

            try FileManager.default.createDirectory(at: testCatalogURL.appendingPathComponent("index2"), withIntermediateDirectories: false, attributes: nil)
            let indexer = try ConvertAction.Indexer(outputURL: testCatalogURL.appendingPathComponent("index2"), catalogIdentifier: context.registeredCatalogs.first!.identifier)
            indexer.index(renderNode1)
            indexer.index(renderNode2)
            XCTAssertTrue(indexer.finalize(emitJSON: false, emitLMDB: false).isEmpty)
            
            let treeDump = try XCTUnwrap(indexer.dumpTree())
            XCTAssertEqual(treeDump, """
            [Root]
            ┗╸Swift
              ┗╸MyKit
                ┣╸Basics
                ┣╸MyKit in Practice
                ┣╸Default Code Listing Syntax
                ┣╸Global symbols
                ┗╸Extensions to other frameworks
            """)
        }
    }
}
