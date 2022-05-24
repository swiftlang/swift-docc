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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first-property"
        )
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-struct"
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(_:)-\("first".stableHashString)"
        )
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(_:)-\("second".stableHashString)"
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-enum" // Same symbol doesn't require disambiguation
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-struct"
        )
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "objective-c")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-protocol"
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)"
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "instance-method", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)-method"
        )
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "type-method", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(one:two:)-type.method"
        )
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
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-struct"
       )
        
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "objective-c")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/First-typealias"
        )
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
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "first", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-method"
        )
        
        // These don't include the kind information because information doesn't help disambiguate these two references.
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "second", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-\("second".stableHashString)"
        )
        XCTAssertEqual(references[SymbolGraph.Symbol.Identifier(precise: "third", interfaceLanguage: "swift")]?.path,
            "/documentation/SymbolDisambiguationTests/Something/first(_:_:)-\("third".stableHashString)"
        )
    }
    
    func testMixedLanguageFramework() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        var loader = SymbolGraphLoader(bundle: bundle, dataProvider: context.dataProvider)
        try loader.loadAll()
        
        let references = context.referencesForSymbols(in: loader.unifiedGraphs, symbolHierarchy: context.symbolPathTree, bundle: bundle).mapValues({ $0.path })
        XCTAssertEqual(references, [
            .init(precise: "c:@CM@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)mixedLanguageMethod", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod()",
            .init(precise: "c:@E@Foo", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo-struct",
            .init(precise: "c:@E@Foo@first", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo/first",
            .init(precise: "c:@E@Foo@fourth", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo/fourth",
            .init(precise: "c:@E@Foo@second", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo/second",
            .init(precise: "c:@E@Foo@third", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo/third",
            .init(precise: "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
            .init(precise: "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)init", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
            .init(precise: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
            .init(precise: "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod()",
            .init(precise: "c:@MixedLanguageFrameworkVersionNumber", interfaceLanguage: "occ"):
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber",
            .init(precise: "c:@MixedLanguageFrameworkVersionString", interfaceLanguage: "occ"):
                "/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
            .init(precise: "c:MixedLanguageFramework.h@T@Foo", interfaceLanguage: "occ"):
                "/documentation/MixedLanguageFramework/Foo-typealias",
            .init(precise: "c:objc(cs)Bar", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Bar",
            .init(precise: "c:objc(cs)Bar(cm)myStringFunction:error:", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)",
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyClassV", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/SwiftOnlyClass",
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyStructV", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/SwiftOnlyStruct",
            .init(precise: "s:22MixedLanguageFramework15SwiftOnlyStructV4tadayyF", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/SwiftOnlyStruct/tada()",
            .init(precise: "s:So3FooV8rawValueABSu_tcfc", interfaceLanguage: "swift"):
                "/documentation/MixedLanguageFramework/Foo/init(rawValue:)",
        ])
    }
    
    // MARK: - Test Helpers
    
    private struct TestSymbolData {
        let preciseID: String
        let pathComponents: [String]
        let kind: SymbolGraph.Symbol.KindIdentifier
    }
    
    private func disambiguatedReferencesForSymbols(swift swiftSymbols: [TestSymbolData], objectiveC objectiveCSymbols: [TestSymbolData]) throws -> [SymbolGraph.Symbol.Identifier : ResolvedTopicReference] {
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
        let swiftSymbolGraphPath = URL(fileURLWithPath:"fake-path-for-swift-symbol-graph.symbols.json")
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
        let objcSymbolGraphPath = URL(fileURLWithPath: "fake-path-for-objc-symbol-graph.symbols.json")
        unified.mergeGraph(graph: graph2, at: URL(fileURLWithPath: "fake-path-for-swift-objc-graph"))
        
        let uniqueSymbolCount = Set(swiftSymbols.map(\.preciseID) + objectiveCSymbols.map(\.preciseID)).count
        XCTAssertEqual(unified.symbols.count, uniqueSymbolCount)
        
        let bundle = DocumentationBundle(
            info: DocumentationBundle.Info(
                displayName: "SymbolDisambiguationTests",
                identifier: "com.test.SymbolDisambiguationTests"),
            symbolGraphURLs: [
                swiftSymbolGraphPath,
                objcSymbolGraphPath
            ],
            markupURLs: [],
            miscResourceURLs: []
        )
        
        class TestProvider: DocumentationContextDataProvider {
            var delegate: DocumentationContextDataProviderDelegate? = nil
            var bundles: [SwiftDocC.BundleIdentifier : SwiftDocC.DocumentationBundle] = [:]
            
            var files: [URL: Data]
            init(files: [URL: Data]) {
                self.files = files
            }
            
            func contentsOfURL(_ url: URL, in bundle: SwiftDocC.DocumentationBundle) throws -> Data {
                guard let data = files[url] else {
                    fatalError("TestProvider doesn't have a file for \(url)")
                }
                return data
            }
        }
        
        let provider = try TestProvider(files: [
            swiftSymbolGraphPath: JSONEncoder().encode(graph),
            objcSymbolGraphPath: JSONEncoder().encode(graph2),
        ])
        provider.bundles[bundle.identifier] = bundle
        
        let context = try DocumentationContext(dataProvider: provider)
        
        print(context.symbolPathTree.dump())
        
        var references = context.referencesForSymbols(in: ["SymbolDisambiguationTests": unified], symbolHierarchy: context.symbolPathTree, bundle: bundle)
        references[SymbolGraph.Symbol.Identifier(precise: "common-parent-symbol", interfaceLanguage: "swift")] = nil
        return references
    }
}
