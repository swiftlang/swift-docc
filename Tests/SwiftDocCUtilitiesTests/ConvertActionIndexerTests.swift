/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
        let (bundle, dataProvider) = try DocumentationContext.InputsProvider()
            .inputsAndDataProvider(startingPoint: testCatalogURL(named: "TestBundle"), options: .init())
        
        let context = try DocumentationContext(bundle: bundle, dataProvider: dataProvider)
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        // Add /documentation/MyKit to the index, verify the tree dump
        do {
            let reference = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let renderNode = try converter.convert(context.entity(with: reference))

            let tempIndexURL = try createTemporaryDirectory(named: "index")
            let indexer = try ConvertAction.Indexer(outputURL: tempIndexURL, bundleID: bundle.id)
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

        // Add two nodes /documentation/MyKit and /documentation/Test-Bundle/Default-Code-Listing-Syntax to the index
        // and verify the tree.
        do {
            let reference1 = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let renderNode1 = try converter.convert(context.entity(with: reference1))

            let reference2 = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/Test-Bundle/Default-Code-Listing-Syntax", sourceLanguage: .swift)
            let renderNode2 = try converter.convert(context.entity(with: reference2))

            let tempIndexURL = try createTemporaryDirectory(named: "index")
            let indexer = try ConvertAction.Indexer(outputURL: tempIndexURL, bundleID: bundle.id)
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
