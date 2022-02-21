/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import SymbolKit

class GeneratedDataProviderTests: XCTestCase {

    func testGeneratingBundles() throws {
        let firstSymbolGraph = SymbolGraph(
            metadata: .init(
                formatVersion: .init(major: 0, minor: 0, patch: 1),
                generator: "unit-test"
            ),
            module: .init(
                name: "FirstModuleName",
                platform: .init()
            ),
            symbols: [],
            relationships: []
        )
        var secondSymbolGraph = firstSymbolGraph
        secondSymbolGraph.module.name = "SecondModuleName"
        
        let thirdSymbolGraph = firstSymbolGraph // Another symbol graph with the same module name
        
        let dataProvider = GeneratedDataProvider(
            symbolGraphDataLoader: {
                switch $0.lastPathComponent {
                case "first.symbols.json":
                    return try? JSONEncoder().encode(firstSymbolGraph)
                case "second.symbols.json":
                    return try? JSONEncoder().encode(secondSymbolGraph)
                case "third.symbols.json":
                    return try? JSONEncoder().encode(thirdSymbolGraph)
                default:
                    return nil
                }
            }
        )
        
        let options = BundleDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Custom Display Name",
                "CFBundleIdentifier": "com.test.example",
            ],
            additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "first.symbols.json"),
                URL(fileURLWithPath: "second.symbols.json"),
                URL(fileURLWithPath: "third.symbols.json"),
            ]
        )
        let bundles = try dataProvider.bundles(options: options)
        XCTAssertEqual(bundles.count, 1)
        let bundle = try XCTUnwrap(bundles.first)
        
        XCTAssertEqual(bundle.displayName, "Custom Display Name")
        XCTAssertEqual(bundle.symbolGraphURLs.map { $0.lastPathComponent }.sorted(), [
            "first.symbols.json",
            "second.symbols.json",
            "third.symbols.json",
            
        ])
        XCTAssertEqual(bundle.markupURLs.map { $0.path }.sorted(), [
            "FirstModuleName.md",
            "SecondModuleName.md",
            // No third file since that symbol graph has the same module name as the first
        ])

        XCTAssertEqual(
            try String(data: dataProvider.contentsOfURL(URL(fileURLWithPath: "FirstModuleName.md")), encoding: .utf8),
            "# ``FirstModuleName``"
        )
        XCTAssertEqual(
            try String(data: dataProvider.contentsOfURL(URL(fileURLWithPath: "SecondModuleName.md")), encoding: .utf8),
            "# ``SecondModuleName``"
        )
    }
    
    func testGeneratingSingleModuleBundle() throws {
        let firstSymbolGraph = SymbolGraph(
            metadata: .init(
                formatVersion: .init(major: 0, minor: 0, patch: 1),
                generator: "unit-test"
            ),
            module: .init(
                name: "FirstModuleName",
                platform: .init()
            ),
            symbols: [],
            relationships: []
        )
        
        let secondSymbolGraph = firstSymbolGraph // Another symbol graph with the same module name
        
        let dataProvider = GeneratedDataProvider(
            symbolGraphDataLoader: {
                switch $0.lastPathComponent {
                case "first.symbols.json":
                    return try? JSONEncoder().encode(firstSymbolGraph)
                case "second.symbols.json":
                    return try? JSONEncoder().encode(secondSymbolGraph)
                default:
                    return nil
                }
            }
        )
        
        let options = BundleDiscoveryOptions(
            infoPlistFallbacks: [
                "CFBundleDisplayName": "Custom Display Name",
                "CFBundleIdentifier": "com.test.example",
            ],
            additionalSymbolGraphFiles: [
                URL(fileURLWithPath: "first.symbols.json"),
                URL(fileURLWithPath: "second.symbols.json"),
            ]
        )
        let bundles = try dataProvider.bundles(options: options)
        XCTAssertEqual(bundles.count, 1)
        let bundle = try XCTUnwrap(bundles.first)
        
        XCTAssertEqual(bundle.displayName, "Custom Display Name")
        XCTAssertEqual(bundle.symbolGraphURLs.map { $0.lastPathComponent }.sorted(), [
            "first.symbols.json",
            "second.symbols.json",
        ])
        XCTAssertEqual(bundle.markupURLs.map { $0.path }.sorted(), [
            "FirstModuleName.md",
            // No second file since that symbol graph has the same module name as the first
        ])

        XCTAssertEqual(
            try String(data: dataProvider.contentsOfURL(URL(fileURLWithPath: "FirstModuleName.md")), encoding: .utf8), """
            # ``FirstModuleName``
            
            @Metadata {
              @DisplayName("Custom Display Name")
            }
            """
        )
    }
}
