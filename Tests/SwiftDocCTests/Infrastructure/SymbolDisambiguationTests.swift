/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC

class SymbolDisambiguationTests: XCTestCase {
    
    func testPathCollisionWithDifferentTypesInSameLanguage() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "first"], kind: .property),
                TestSymbolData(preciseID: "second", pathComponents: ["Something", "First"], kind: .struct),
            ],
            objectiveC: []
        )
        
        XCTAssertEqual(references.count, 2)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first-swift.property",
        ])
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First-swift.struct",
        ])
    }
    
    func testPathCollisionWithDifferentArgumentTypesInSameLanguage() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                // The argument type isn't represented in the symbol name in the path components
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "first(_:)"], kind: .method),
                TestSymbolData(preciseID: "second", pathComponents: ["Something", "first(_:)"], kind: .method),
            ],
            objectiveC: []
        )
        
        XCTAssertEqual(references.count, 2)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(_:)-\("first".stableHashString)",
        ])
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(_:)-\("second".stableHashString)",
        ])
    }
    
    func testSameSymbolWithDifferentKindsInDifferentLanguages() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "First"], kind: .enum),
            ],
            objectiveC: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "First"], kind: .protocol),
            ]
        )
        
        XCTAssertEqual(references.count, 1)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First", // Same symbol doesn't require disambiguation
        ])
    }
    
    func testDifferentSymbolsWithDifferentKindsInDifferentLanguages() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "First"], kind: .struct),
            ],
            objectiveC: [
                TestSymbolData(preciseID: "second", pathComponents: ["Something", "First"], kind: .protocol),
            ]
        )
        
        XCTAssertEqual(references.count, 2)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First-swift.struct",
        ])
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "objective-c")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First-c.protocol",
        ])
    }
    
    func testSameSymbolWithDifferentNamesInDifferentLanguages() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "first(one:two:)"], kind: .method),
            ],
            objectiveC: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "firstWithOne:two:"], kind: .method),
            ]
        )
        
        XCTAssertEqual(references.count, 1)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)",
            "/documentation/SymbolDisambiguationTests/Something/firstWithOne:two:",
        ])
    }
    
    func testOneVariantOfMultiLanguageSymbolCollidesWithDifferentTypeSymbol() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "instance-method", pathComponents: ["Something", "first(one:two:)"], kind: .method),
                TestSymbolData(preciseID: "type-method", pathComponents: ["Something", "first(one:two:)"], kind: .typeMethod),
            ],
            objectiveC: [
                TestSymbolData(preciseID: "type-method", pathComponents: ["Something", "firstWithOne:two:"], kind: .typeMethod),
            ]
        )
        
        XCTAssertEqual(references.count, 2)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "instance-method", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)-swift.method",
        ])
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "type-method", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)-swift.type.method",
            "/documentation/SymbolDisambiguationTests/Something/firstWithOne:two:", // This path doesn't have any collisions
        ])
    }
    
    func testStructAndEnumAndTypeAliasCollisionOfSameSymbol() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "First"], kind: .struct),
            ],
            objectiveC: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "First"], kind: .enum),
                TestSymbolData(preciseID: "second", pathComponents: ["Something", "First"], kind: .typealias),
            ]
        )
        
        XCTAssertEqual(references.count, 2)
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First-swift.struct",
            "/documentation/SymbolDisambiguationTests/Something/First-c.enum",
        ])
        
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "objective-c")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/First-c.typealias",
        ])
    }
    
    func testTripleCollisionWithBothSameTypeAndDifferentType() throws {
        let references = try disambiguatedReferencesForSymbols(
            swift: [
                TestSymbolData(preciseID: "first", pathComponents: ["Something", "first(_:_:)"], kind: .method),
                TestSymbolData(preciseID: "second", pathComponents: ["Something", "first(_:_:)"], kind: .typeMethod),
                TestSymbolData(preciseID: "third", pathComponents: ["Something", "first(_:_:)"], kind: .typeMethod),
            ],
            objectiveC: []
        )
        
        XCTAssertEqual(references.count, 3)
        
        // The first collision can be disambiguated with its kind information
        XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
            "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-swift.method",
        ])
        
        if LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
            XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
                "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-\("second".stableHashString)",
            ])
            XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "third", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
                "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-\("third".stableHashString)",
            ])
        } else {
            // The cache-based resolver redundantly disambiguates with both kind and usr when another overload has a different kind.
            XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
                "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-swift.type.method-\("second".stableHashString)",
            ])
            XCTAssertEqual((references[SymbolGraph.Symbol.Identifier(precise: "third", interfaceLanguage: "swift")] ?? []).map { $0.path }, [
                "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-swift.type.method-\("third".stableHashString)",
            ])
        }
    }
    
    func testMixedLanguageFramework() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        if !LinkResolutionMigrationConfiguration.shouldUseHierarchyBasedLinkResolver {
            let aliases = [String: [String]](uniqueKeysWithValues: context.documentationCacheBasedLinkResolver.referenceAliases.map({ ($0.key.path, $0.value.map(\.path).sorted()) }))
            XCTAssertEqual(aliases, [
                "/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)": [
                    "/documentation/MixedLanguageFramework/Bar/myStringFunction:error:",
                ],
                "/documentation/MixedLanguageFramework/Foo-swift.struct": [
                    "/documentation/MixedLanguageFramework/Foo-c.enum",
                ],
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()": [
                    "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init",
                ],
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod()": [
                    "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod",
                ],
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod()": [
                    "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod",
                ],
            ])
        }
        
        var loader = SymbolGraphLoader(bundle: bundle, dataProvider: context.dataProvider)
        try loader.loadAll()
        
        let references = context.documentationCacheBasedLinkResolver.referencesForSymbols(in: loader.unifiedGraphs, bundle: bundle, context: context).mapValues({ $0.map(\.path) })
        XCTAssertEqual(references, [
            .init(precise: "c:@CM@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)mixedLanguageMethod", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod()",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod",
            ],
            .init(precise: "c:@E@Foo", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
                "/documentation/MixedLanguageFramework/Foo-c.enum",
            ],
            .init(precise: "c:@E@Foo@first", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo/first",
            ],
            .init(precise: "c:@E@Foo@fourth", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo/fourth",
            ],
            .init(precise: "c:@E@Foo@second", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo/second",
            ],
            .init(precise: "c:@E@Foo@third", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo/third",
            ],
            .init(precise: "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
            ],
            .init(precise: "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)init", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init",
            ],
            .init(precise: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
            ],
            .init(precise: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod()",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod",
            ],
            .init(precise: "c:@MixedLanguageFrameworkVersionNumber", interfaceLanguage: "occ"): [
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber",
            ],
            .init(precise: "c:@MixedLanguageFrameworkVersionString", interfaceLanguage: "occ"): [
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
            ],
            .init(precise: "c:MixedLanguageFramework.h@T@Foo", interfaceLanguage: "occ"): [
                "/documentation/MixedLanguageFramework/Foo-c.typealias",
            ],
            .init(precise: "c:objc(cs)Bar", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Bar",
            ],
            .init(precise: "c:objc(cs)Bar(cm)myStringFunction:error:", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)",
                "/documentation/MixedLanguageFramework/Bar/myStringFunction:error:",
            ],
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyClassV", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/SwiftOnlyClass",
            ],
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyStructV", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/SwiftOnlyStruct",
            ],
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyStructV4tadayyF", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/SwiftOnlyStruct/tada()",
            ],
            .init(precise: "s:So3FooV8rawValueABSu_tcfc", interfaceLanguage: "swift"): [
                "/documentation/MixedLanguageFramework/Foo/init(rawValue:)",
            ],
        ])
        
    }
    
    // MARK: - Test Helpers
    
    private struct TestSymbolData {
        let preciseID: String
        let pathComponents: [String]
        let kind: SymbolGraph.Symbol.KindIdentifier
    }
    
    
    private func disambiguatedReferencesForSymbols(swift swiftSymbols: [TestSymbolData], objectiveC objectiveCSymbols: [TestSymbolData]) throws -> [SymbolGraph.Symbol.Identifier : [ResolvedTopicReference]] {
        let graph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 1, minor: 1, patch: 1),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "SymbolDisambiguationTests",
                platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: nil)
            ),
            symbols: swiftSymbols.map {
                SymbolGraph.Symbol(
                    identifier: SymbolGraph.Symbol.Identifier(precise: $0.preciseID, interfaceLanguage: "swift"),
                    names: SymbolGraph.Symbol.Names(title: "Title", navigator: nil, subHeading: nil, prose: nil), // names doesn't matter for path disambiguation
                    pathComponents: $0.pathComponents,
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: $0.kind, displayName: "Kind Display Name"), // kind display names doesn't matter for path disambiguation
                    mixins: [:]
                )
            },
            relationships: []
        )
        
        let unified = try XCTUnwrap(UnifiedSymbolGraph(fromSingleGraph: graph, at: URL(fileURLWithPath: "fake-path-for-swift-symbol-graph")))
        
        let graph2 = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.SemanticVersion(major: 1, minor: 1, patch: 1),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "SymbolDisambiguationTests",
                platform: SymbolGraph.Platform(architecture: nil, vendor: nil, operatingSystem: nil)
            ),
            symbols: objectiveCSymbols.map {
                SymbolGraph.Symbol(
                    identifier: SymbolGraph.Symbol.Identifier(precise: $0.preciseID, interfaceLanguage: "objective-c"),
                    names: SymbolGraph.Symbol.Names(title: "Title", navigator: nil, subHeading: nil, prose: nil), // names doesn't matter for path disambiguation
                    pathComponents: $0.pathComponents,
                    docComment: nil,
                    accessLevel: SymbolGraph.Symbol.AccessControl(rawValue: "public"),
                    kind: SymbolGraph.Symbol.Kind(parsedIdentifier: $0.kind, displayName: "Kind Display Name"), // kind display names doesn't matter for path disambiguation
                    mixins: [:]
                )
            },
            relationships: []
        )
        
        unified.mergeGraph(graph: graph2, at: URL(fileURLWithPath: "fake-path-for-swift-objc-graph"))
        
        let uniqueSymbolCount = Set(swiftSymbols.map(\.preciseID) + objectiveCSymbols.map(\.preciseID)).count
        XCTAssertEqual(unified.symbols.count, uniqueSymbolCount)
        
        let bundle = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: "SymbolDisambiguationTests",
                identifier: "com.test.SymbolDisambiguationTests"),
            symbolGraphURLs: [],
            markupURLs: [],
            miscResourceURLs: []
        )
        
        class TestProvider: DocumentationContextDataProvider {
            var delegate: DocumentationContextDataProviderDelegate? = nil
            var bundles: [SwiftDocC.BundleIdentifier : SwiftDocC.DocumentationBundle] = [:]
            
            func contentsOfURL(_ url: URL, in bundle: SwiftDocC.DocumentationBundle) throws -> Data {
                fatalError("No content will be loaded from the bundle in this test")
            }
        }
        
        let provider = TestProvider()
        provider.bundles[bundle.identifier] = bundle
        
        let context = try DocumentationContext(dataProvider: provider)
        
        
        return context.documentationCacheBasedLinkResolver.referencesForSymbols(in: ["SymbolDisambiguationTests": unified], bundle: bundle, context: context)
    }
}
