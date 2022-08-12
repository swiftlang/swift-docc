/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class SymbolReferenceTests: XCTestCase {
    func testUsesIdentifierForUnresolvedSymbols() {
        let leafRef = SymbolReference("ID", interfaceLanguage: .swift, symbol: nil)
        XCTAssertEqual(leafRef.path, "ID")

        let leafRefHash = SymbolReference("ID", interfaceLanguage: .swift, symbol: nil, shouldAddHash: true)
        XCTAssertEqual(leafRefHash.path, "ID-4n23y")
    }

    func testEmptyPathForModules() {
        let symbol = SymbolGraph.Symbol(
            identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
            names: .init(title: "abcd", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["test", "abcd"],
            docComment: nil,
            accessLevel: .init(rawValue: "public"),
            kind: .init(parsedIdentifier: .module, displayName: "Framework"),
            mixins: [:])
        let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol)
        XCTAssertEqual(leafRef.path, "")
    }

    func testDoesntAddHash() {
        let symbol = SymbolGraph.Symbol(
            identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
            names: .init(title: "abcd", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["test", "abcd"],
            docComment: nil,
            accessLevel: .init(rawValue: "public"),
            kind: .init(parsedIdentifier: .var, displayName: "Variable"),
            mixins: [:])
        let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol)
        XCTAssertEqual(leafRef.path, "test/abcd")
    }

    func testAddsHash() {
        let symbol = SymbolGraph.Symbol(
            identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
            names: .init(title: "abcd", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["test", "abcd"],
            docComment: nil,
            accessLevel: .init(rawValue: "public"),
            kind: .init(parsedIdentifier: .var, displayName: "Variable"),
            mixins: [:])
        let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol, shouldAddHash: true)
        XCTAssertEqual(leafRef.path, "test/abcd-8ogy4")
    }
    
    func testTranslatesSymbolNameCorrectly() {
        // Method with no parameters
        do {
            let symbol = SymbolGraph.Symbol(
                identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
                names: .init(title: "abcd()", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["test", "abcd()"],
                docComment: nil,
                accessLevel: .init(rawValue: "public"),
                kind: .init(parsedIdentifier: .var, displayName: "Variable"),
                mixins: [:])
            let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol, shouldAddHash: false)
            XCTAssertEqual(leafRef.path, "test/abcd()")
        }

        // Method with unnamed parameter
        do {
            let symbol = SymbolGraph.Symbol(
                identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
                names: .init(title: "abcd(_:Int)", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["test", "abcd(_:Int)"],
                docComment: nil,
                accessLevel: .init(rawValue: "public"),
                kind: .init(parsedIdentifier: .var, displayName: "Variable"),
                mixins: [:])
            let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol, shouldAddHash: false)
            XCTAssertEqual(leafRef.path, "test/abcd(_:Int)")
        }

        // Method with named parameters
        do {
            let symbol = SymbolGraph.Symbol(
                identifier: .init(precise: "abcd", interfaceLanguage: SourceLanguage.swift.id),
                names: .init(title: "abcd(num: Int, text: String)", navigator: nil, subHeading: nil, prose: nil),
                pathComponents: ["test", "abcd(num:text:)"],
                docComment: nil,
                accessLevel: .init(rawValue: "public"),
                kind: .init(parsedIdentifier: .var, displayName: "Variable"),
                mixins: [:])
            let leafRef = SymbolReference(symbol.identifier.precise, interfaceLanguage: .swift, symbol: symbol, shouldAddHash: false)
            XCTAssertEqual(leafRef.path, "test/abcd(num:text:)")
        }
    }

    func testCreatesUniquePathsForOverloadSymbols() throws {
        let testBundle = Folder(name: "TestCreatesUniquePathsForOverloadSymbols.docc", content: [
            InfoPlist(displayName: "TestCreatesUniquePathsForOverloadSymbols", identifier: "com.example.documentation"),
            Folder(name: "Resources", content: [
            ]),
            Folder(name: "Symbols", content: [
                TextFile(name: "OverloadKit.symbols.json", utf8Content: """
                {
                  "metadata": {
                      "formatVersion" : { "major" : 1 },
                      "generator" : "app/1.0"
                  },
                  "module" : {
                    "name" : "OverloadKit",
                    "platform" : {
                      "architecture" : "x86_64",
                      "vendor" : "apple",
                      "operatingSystem" : {
                        "name" : "ios",
                        "minimumVersion" : {
                          "major" : 10,
                          "minor" : 15,
                          "patch" : 0
                        }
                      }
                    }
                  },
                  "symbols" : [
                    {
                      "accessLevel" : "public",
                      "kind" : {
                        "identifier" : "swift.function",
                        "displayName" : "Function"
                      },
                      "names" : {
                        "title" : "function(_:String)"
                      },
                      "pathComponents": [
                        "function(_:)"
                      ],
                      "identifier" : {
                        "precise" : "s:5OverloadKit0A5functionFSTRING",
                        "interfaceLanguage" : "swift"
                      },
                      "declarationFragments" : [
                      ]
                    },
                      {
                        "accessLevel" : "public",
                        "kind" : {
                          "identifier" : "swift.function",
                          "displayName" : "Function"
                        },
                        "names" : {
                          "title" : "function(_:Int)"
                        },
                        "pathComponents": [
                          "function(_:)"
                        ],
                        "identifier" : {
                          "precise" : "s:5OverloadKit0A5functionFINT",
                          "interfaceLanguage" : "swift"
                        },
                        "declarationFragments" : [
                        ]
                      },
                      {
                        "accessLevel" : "public",
                        "kind" : {
                          "identifier" : "swift.function",
                          "displayName" : "Function"
                        },
                        "names" : {
                          "title" : "function(_:Data)"
                        },
                        "pathComponents": [
                          "function(_:)"
                        ],
                        "identifier" : {
                          "precise" : "s:5OverloadKit0A5functionFDATA",
                          "interfaceLanguage" : "swift"
                        },
                        "declarationFragments" : [
                        ]
                      }
                  ],
                  "relationships" : [
                  ]
                }
                """),
            ]),
        ])
        
        let tempURL = try createTemporaryDirectory()
        let bundleURL = try testBundle.write(inside: tempURL)

        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        let dataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        try workspace.registerProvider(dataProvider)
        
        // The overloads are sorted and all dupes get a hash suffix.
        XCTAssertEqual(
            context.knownIdentifiers.map { $0.path }.filter { $0.contains("/function") }.sorted(),
            [
                "/documentation/OverloadKit/function(_:)-1echv",
                "/documentation/OverloadKit/function(_:)-4s9wl",
                "/documentation/OverloadKit/function(_:)-7kt4g",
            ]
        )
    }
    
    func testKnownSourceLanguagesOfUnifiedGraphSymbol() {
        let module = SymbolGraph.Module(
            name: "os",
            platform: SymbolGraph.Platform()
        )
        
        let unifiedSymbol = UnifiedSymbolGraph.Symbol(
            fromSingleSymbol: makeSymbol(interfaceLanguage: "swift"),
            module: module,
            isMainGraph: true
        )
        
        unifiedSymbol.mergeSymbol(
            symbol: makeSymbol(interfaceLanguage: "c"),
            module: module,
            isMainGraph: true
        )
        
        XCTAssertEqual(unifiedSymbol.sourceLanguages.map(\.id).sorted(), ["occ", "swift"])
    }
    
    func testUnknownSourceLanguagesOfUnifiedGraphSymbol() {
        let module = SymbolGraph.Module(
            name: "os",
            platform: SymbolGraph.Platform()
        )
        
        let unifiedSymbol = UnifiedSymbolGraph.Symbol(
            fromSingleSymbol: makeSymbol(interfaceLanguage: "unknown-language"),
            module: module,
            isMainGraph: true
        )
        
        XCTAssertEqual(unifiedSymbol.sourceLanguages.map(\.id).sorted(), ["unknown-language"])
    }
    
    private func makeSymbol(interfaceLanguage: String) -> SymbolGraph.Symbol {
        SymbolGraph.Symbol(
            identifier: .init(precise: "abcd", interfaceLanguage: interfaceLanguage),
            names: .init(title: "abcd", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["test", "abcd"],
            docComment: nil,
            accessLevel: .init(rawValue: "public"),
            kind: .init(parsedIdentifier: .module, displayName: "Framework"),
            mixins: [:]
        )
    }
}
