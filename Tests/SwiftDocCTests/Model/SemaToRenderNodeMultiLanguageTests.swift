/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import XCTest

class SemaToRenderNodeMixedLanguageTests: XCTestCase {
    func testBaseRenderNodeFromMixedLanguageFramework() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        for documentationNode in context.documentationCache.values where documentationNode.kind.isSymbol {
            let symbolUSR = try XCTUnwrap((documentationNode.semantic as? Symbol)?.externalID)
            
            let expectedSwiftOnlyUSRs: Set<String> = [
                // Swift-only struct - ``SwiftOnlyStruct``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV",
                
                // Swift-only class - ``SwiftOnlyClass``:
                "s:22MixedLanguageFramework15SwiftOnlyClassV",
                
                // Member of Swift-only struct - ``SwiftOnlyStruct/tada()``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV4tadayyF",
                
                // Swift-only synthesized struct initializer - ``Foo/init(rawValue:)``:
                "s:So3FooV8rawValueABSu_tcfc",
            ]
            
            let expectedObjectiveCOnlyUSRs: Set<String> = [
                // Objective-C only variable - ``_MixedLanguageFrameworkVersionNumber``:
                "c:@MixedLanguageFrameworkVersionNumber",
                
                // Objective-C only variable - ``_MixedLanguageFrameworkVersionString``:
                "c:@MixedLanguageFrameworkVersionString",
                
                // Objective-C only typealias - ``Foo-c.typealias``
                "c:MixedLanguageFramework.h@T@Foo",
            ]
            
            if expectedSwiftOnlyUSRs.contains(symbolUSR) {
                XCTAssertEqual(
                    documentationNode.availableSourceLanguages,
                    [.swift],
                    "Swift-only node should be only available in Swift: '\(symbolUSR)'"
                )
            } else if expectedObjectiveCOnlyUSRs.contains(symbolUSR) {
                XCTAssertEqual(
                    documentationNode.availableSourceLanguages,
                    [.objectiveC],
                    "Objective-C-only node should be only available in Objective-C: '\(symbolUSR)'"
                )
            } else {
                XCTAssertEqual(
                    documentationNode.availableSourceLanguages,
                    [.swift, .objectiveC],
                    "Multi-language node should be available in Swift and Objective-C: '\(symbolUSR)'"
                )
            }
        }
        
        for documentationNode in context.documentationCache.values
            where !documentationNode.kind.isSymbol && documentationNode.kind.isPage
        {
            XCTAssertEqual(
                documentationNode.availableSourceLanguages,
                [.swift, .objectiveC],
                "Expected non-symbol page to be available in both Swift and Objective-C: \(documentationNode.name)"
            )
        }
    }

    func assertOutputsMultiLanguageRenderNodes(variantInterfaceLanguage: String) throws {
        let outputConsumer = try renderNodeConsumer(
            for: "MixedLanguageFramework",
            configureBundle: { bundleURL in
                // Update the clang symbol graph with the Objective-C identifier given in variantInterfaceLanguage.
                
                let clangSymbolGraphLocation = bundleURL
                    .appendingPathComponent("symbol-graphs")
                    .appendingPathComponent("clang")
                    .appendingPathComponent("MixedLanguageFramework.symbols.json")
                
                var clangSymbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: clangSymbolGraphLocation))
                
                clangSymbolGraph.symbols = clangSymbolGraph.symbols.mapValues { symbol in
                    var symbol = symbol
                    symbol.identifier.interfaceLanguage = variantInterfaceLanguage
                    return symbol
                }
                
                try JSONEncoder().encode(clangSymbolGraph).write(to: clangSymbolGraphLocation)
            }
        )
        
        XCTAssertEqual(
            Set(
                outputConsumer.renderNodes(withInterfaceLanguages: ["swift"])
                    .map { $0.metadata.externalID }
            ),
            [
                // Swift-only struct - ``SwiftOnlyStruct``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV",
                
                // Swift-only class - ``SwiftOnlyClass``:
                "s:22MixedLanguageFramework15SwiftOnlyClassV",
                
                // Member of Swift-only struct - ``SwiftOnlyStruct/tada()``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV4tadayyF",
                
                // Swift-only synthesized struct initializer - ``Foo/init(rawValue:)``:
                "s:So3FooV8rawValueABSu_tcfc",
            ]
        )
        
        XCTAssertEqual(
            Set(
                outputConsumer.renderNodes(withInterfaceLanguages: ["occ"])
                    .map { $0.metadata.externalID }
            ),
            [
                // Objective-C only variable - ``_MixedLanguageFrameworkVersionNumber``:
                "c:@MixedLanguageFrameworkVersionNumber",
                
                // Objective-C only variable - ``_MixedLanguageFrameworkVersionString``:
                "c:@MixedLanguageFrameworkVersionString",
                
                // Objective-C only typealias - ``Foo-c.typealias``
                "c:MixedLanguageFramework.h@T@Foo",
            ]
        )
        
        XCTAssertEqual(
            Set(
                outputConsumer.renderNodes(withInterfaceLanguages: ["swift", "occ"])
                    .map { $0.metadata.externalID ?? $0.metadata.title }
            ),
            [
                "MixedLanguageFramework",
                "c:@E@Foo",
                "c:@E@Foo@first",
                "c:@E@Foo@fourth",
                "c:@E@Foo@second",
                "c:@E@Foo@third",
                "c:objc(cs)Bar",
                "c:objc(cs)Bar(cm)myStringFunction:error:",
                "c:@M@TestFramework@objc(pl)MixedLanguageProtocol",
                "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol",
                "c:@M@TestFramework@objc(pl)MixedLanguageProtocol(im)mixedLanguageMethod",
                "c:@M@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)init",
                "c:@CM@TestFramework@objc(cs)MixedLanguageClassConformingToProtocol(im)mixedLanguageMethod",
                
                "MixedLanguageProtocol Implementations",
                "Article",
                "Article curated in a single-language page",
                "APICollection",
                "MixedLanguageFramework Tutorials",
                "Tutorial Article",
                "Tutorial",
            ]
        )

        XCTAssertEqual(
            Set(
                outputConsumer.renderNodes(withInterfaceLanguages: ["swift", "occ"])
                    .map { $0.identifier.path }
            ),
            [
                "/tutorials/TutorialOverview",
                "/documentation/MixedLanguageFramework",
                "/documentation/MixedLanguageFramework/Bar",
                "/tutorials/MixedLanguageFramework/Tutorial",
                "/documentation/MixedLanguageFramework/Article",
                "/tutorials/MixedLanguageFramework/TutorialArticle",
                "/documentation/MixedLanguageFramework/APICollection",
                "/documentation/MixedLanguageFramework/Foo-swift.struct",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol",
                "/documentation/MixedLanguageFramework/Foo-swift.struct/first",
                "/documentation/MixedLanguageFramework/Foo-swift.struct/second",
                "/documentation/MixedLanguageFramework/Foo-swift.struct/third",
                "/documentation/MixedLanguageFramework/Foo-swift.struct/fourth",
                "/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)",
                "/documentation/MixedLanguageFramework/ArticleCuratedInASingleLanguagePage",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
                "/documentation/MixedLanguageFramework/MixedLanguageProtocol/mixedLanguageMethod()",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/mixedLanguageMethod()",
                "/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/MixedLanguageProtocol-Implementations",
            ]
        )
    }

    func testOutputsMultiLanguageRenderNodesWithOccIdentifier() throws {
        try assertOutputsMultiLanguageRenderNodes(variantInterfaceLanguage: "occ")
    }

    func testOutputsMultiLanguageRenderNodesWithObjectiveCIdentifier() throws {
        try assertOutputsMultiLanguageRenderNodes(variantInterfaceLanguage: "objective-c")
    }

    func testOutputsMultiLanguageRenderNodesWithCIdentifier() throws {
        try assertOutputsMultiLanguageRenderNodes(variantInterfaceLanguage: "c")
    }

    func testFrameworkRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework")
        let mixedLanguageFrameworkRenderNode = try outputConsumer.renderNode(
            withIdentifier: "MixedLanguageFramework"
        )
        
        assertExpectedContent(
            mixedLanguageFrameworkRenderNode,
            sourceLanguage: "swift",
            symbolKind: "module",
            title: "MixedLanguageFramework",
            navigatorTitle: nil,
            abstract: "This framework is available to both Swift and Objective-C clients.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyStruct",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyClass",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/tutorials/TutorialOverview",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/TutorialArticle",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/Tutorial",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/APICollection",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageProtocol",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
            ],
            referenceTitles: [
                "APICollection",
                "Article",
                "Bar",
                "Foo",
                "MixedLanguageClassConformingToProtocol",
                "MixedLanguageFramework",
                "MixedLanguageFramework Tutorials",
                "MixedLanguageProtocol",
                "SwiftOnlyClass",
                "SwiftOnlyStruct",
                "Tutorial",
                "Tutorial Article",
                "_MixedLanguageFrameworkVersionNumber",
                "_MixedLanguageFrameworkVersionString"
            ],
            referenceFragments: [
                "class Bar",
                "class MixedLanguageClassConformingToProtocol",
                "class SwiftOnlyClass",
                "protocol MixedLanguageProtocol",
                "struct Foo",
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Swift variant of 'MixedLanguageFramework' module has unexpected content for '\(fieldName)'."
            }
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(
            to: mixedLanguageFrameworkRenderNode
        )
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            symbolKind: "module",
            title: "MixedLanguageFramework",
            navigatorTitle: nil,
            abstract: "This framework is available to both Swift and Objective-C clients.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/tutorials/TutorialOverview",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/TutorialArticle",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/Tutorial",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/APICollection",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageProtocol",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
            ],
            referenceTitles: [
                "APICollection",
                "Article",
                "Bar",
                "Foo",
                "MixedLanguageClassConformingToProtocol",
                "MixedLanguageFramework",
                "MixedLanguageFramework Tutorials",
                "MixedLanguageProtocol",
                "SwiftOnlyClass",
                "SwiftOnlyStruct",
                "Tutorial",
                "Tutorial Article",
                "_MixedLanguageFrameworkVersionNumber",
                "_MixedLanguageFrameworkVersionString"
            ],
            referenceFragments: [
                "@interface Bar : NSObject",
                "MixedLanguageClassConformingToProtocol",
                "MixedLanguageProtocol",
                "class SwiftOnlyClass",
                "struct Foo",
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'MixedLanguageFramework' module has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testObjectiveCAuthoredRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework")
        let fooRenderNode = try outputConsumer.renderNode(withIdentifier: "c:@E@Foo")
        
        assertExpectedContent(
            fooRenderNode,
            sourceLanguage: "swift",
            symbolKind: "struct",
            title: "Foo",
            navigatorTitle: "Foo",
            abstract: "A foo.",
            declarationTokens: [
                "struct",
                " ",
                "Foo",
            ],
            discussionSection: [
                "This is the foo’s description.",
            ],
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/init(rawValue:)",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/first",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/fourth",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/second",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/third",
            ],
            referenceTitles: [
                "Foo",
                "MixedLanguageFramework",
                "first",
                "fourth",
                "init(rawValue:)",
                "second",
                "third",
            ],
            referenceFragments: [
                "init(rawValue: UInt)",
                "static var first: Foo",
                "static var fourth: Foo",
                "static var second: Foo",
                "static var third: Foo",
                "struct Foo",
            ],
            failureMessage: { fieldName in
                "Swift variant of 'Foo' symbol has unexpected content for '\(fieldName)'."
            }
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(to: fooRenderNode)
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            symbolKind: "enum",
            title: "Foo",
            navigatorTitle: "Foo",
            abstract: "A foo.",
            declarationTokens: [
                "typedef",
                " ",
                "enum",
                " ",
                "Foo",
                " : ",
                "NSString",
                " {\n    ...\n} ",
                "Foo",
                ";",
            ],
            discussionSection: [
                "This is the foo’s description.",
            ],
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/first",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/fourth",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/second",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct/third",
            ],
            referenceTitles: [
                "Foo",
                "MixedLanguageFramework",
                "first",
                "fourth",
                "init(rawValue:)",
                "second",
                "third",
            ],
            referenceFragments: [
                "init(rawValue: UInt)",
                "static var first: Foo",
                "static var fourth: Foo",
                "static var second: Foo",
                "static var third: Foo",
                "struct Foo",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'Foo' symbol has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testSymbolLinkWorkInMultipleLanguages() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "MixedLanguageFramework") { url in
            try """
            # ``MixedLanguageFramework/Bar``
            
            Test that symbol references using multi source language spellings all resolve successfully.
            
            ## Topics
            
            ### Symbol links in multiple source languages
            
            - ``MixedLanguageFramework/Bar/myStringFunction(_:)``
            - ``myStringFunction(_:)``
            - ``MixedLanguageFramework/Bar/myStringFunction:error:``
            - ``myStringFunction:error:``
            """.write(to: url.appendingPathComponent("bar.md"), atomically: true, encoding: .utf8)
        }
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MixedLanguageFramework/Bar", sourceLanguage: .swift))
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        
        XCTAssert(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems)")
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = try XCTUnwrap(translator.visit(symbol) as? RenderNode)
        
        XCTAssert(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems)")
        
        // These two references are equivalent and depending on the order that the symbols are processed, either one of them could be considered the canonical reference.
        let referenceAliases = [
            "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar/myStringFunction(_:)",
            "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar/myStringFunction:error:",
        ]
        
        // Find which alias is the canonical reference and which is the other
        let canonicalReference = try XCTUnwrap(referenceAliases.first(where: { renderNode.references.keys.contains($0) }))
        let nonCanonicalReference = try XCTUnwrap(referenceAliases.filter { $0 != canonicalReference }.first)
        
        XCTAssertNotNil(renderNode.references[canonicalReference])
        XCTAssertNil(renderNode.references[nonCanonicalReference], "The non canonical reference shouldn't have its own entry in the render node's references.")
        
        XCTAssertEqual(renderNode.topicSections.count, 1)
        let topicGroup = try XCTUnwrap(renderNode.topicSections.first)
        
        XCTAssertEqual(topicGroup.identifiers.count, 4)
        XCTAssertEqual(topicGroup.identifiers, [
            canonicalReference,
            canonicalReference,
            canonicalReference,
            canonicalReference,
        ], "Both spellings of the symbol link should resolve to the canonical reference.")
    }
    
    func testObjectiveCOnlySymbolCuratedInSwiftOnlySymbolIsNotFilteredOut() throws {
         let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFrameworkSingleLanguageCuration")
         let fooRenderNode = try outputConsumer.renderNode(
             withIdentifier: "s:22MixedLanguageFramework15SwiftOnlyStruct1V"
         )

         assertExpectedContent(
             fooRenderNode,
             sourceLanguage: "swift",
             symbolKind: "struct",
             title: "SwiftOnlyStruct1",
             navigatorTitle: nil,
             abstract: "This is an awesome, Swift-only symbol.",
             declarationTokens: nil,
             discussionSection: nil,
             topicSectionIdentifiers: [
                 "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MultiCuratedObjectiveCOnlyClass1",
             ],
             referenceTitles: [
                "MixedLanguageFramework",
                "MultiCuratedObjectiveCOnlyClass1",
                "MultiCuratedObjectiveCOnlyClass2",
                "SwiftOnlyStruct1",
                "SwiftOnlyStruct2",
             ],
             referenceFragments: [],
             failureMessage: { fieldName in
                 "Swift variant of 'SwiftOnlySymbol1' symbol has unexpected content for '\(fieldName)'."
             }
         )
     }
    
    func testArticleInMixedLanguageFramework() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework") { url in
            try """
            # MyArticle
            
            An article in a mixed-language framework. This symbol link should display the correct title depending on \
            the language we're browsing this article in: ``MixedLanguageFramework/Bar/myStringFunction(_:)``.
            """.write(to: url.appendingPathComponent("bar.md"), atomically: true, encoding: .utf8)
        }
        
        let articleRenderNode = try outputConsumer.renderNode(withTitle: "MyArticle")
        
        assertExpectedContent(
            articleRenderNode,
            sourceLanguage: "swift",
            title: "MyArticle",
            navigatorTitle: nil,
            abstract: """
            An article in a mixed-language framework. This symbol link should display the correct title depending on \
            the language we’re browsing this article in: .
            """,
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [],
            referenceTitles: [
                "MixedLanguageFramework",
                "myStringFunction(_:)",
            ],
            referenceFragments: [
                "class func myStringFunction(String) throws -> String",
            ],
            failureMessage: { fieldName in
                "Swift variant of 'MyArticle' article has unexpected content for '\(fieldName)'."
            }
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(to: articleRenderNode)
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            title: "MyArticle",
            navigatorTitle: nil,
            abstract: """
            An article in a mixed-language framework. This symbol link should display the correct title depending on \
            the language we’re browsing this article in: .
            """,
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [],
            referenceTitles: [
                "MixedLanguageFramework",
                "myStringFunction:error:",
            ],
            referenceFragments: [
                "typedef enum Foo : NSString {\n    ...\n} Foo;",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'MyArticle' article has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testAPICollectionInMixedLanguageFramework() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework")
        
        let articleRenderNode = try outputConsumer.renderNode(withTitle: "APICollection")
        
        assertExpectedContent(
            articleRenderNode,
            sourceLanguage: "swift",
            title: "APICollection",
            navigatorTitle: nil,
            abstract: "This is an API collection.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyStruct"
            ],
            seeAlsoSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyStruct",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ],
            referenceTitles: [
                "Article",
                "MixedLanguageFramework",
                "SwiftOnlyStruct",
                "_MixedLanguageFrameworkVersionNumber",
            ],
            referenceFragments: [
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Swift variant of 'APICollection' article has unexpected content for '\(fieldName)'."
            }
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(to: articleRenderNode)
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            title: "APICollection",
            navigatorTitle: nil,
            abstract: "This is an API collection.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber"
            ],
            seeAlsoSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ],
            referenceTitles: [
                "Article",
                "MixedLanguageFramework",
                "SwiftOnlyStruct",
                "_MixedLanguageFrameworkVersionNumber",
            ],
            referenceFragments: [
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'MyArticle' article has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testGeneratedImplementationsCollectionIsCuratedInAllAvailableLanguages() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework")
        
        let protocolRenderNode = try outputConsumer.renderNode(withTitle: "MixedLanguageClassConformingToProtocol")
        
        XCTAssertEqual(
            protocolRenderNode.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/MixedLanguageProtocol-Implementations",
            ]
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(to: protocolRenderNode)
        
        XCTAssertEqual(
            objectiveCVariantNode.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/MixedLanguageProtocol-Implementations",
            ]
        )
    }
    
    func testGeneratedImplementationsCollectionDoesNotCurateInAllUnavailableLanguages() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "MixedLanguageFramework",
            configureBundle: { bundleURL in
                // Update the clang symbol graph to remove the protocol method requirement, so that it's effectively
                // available in Swift only.
                
                let clangSymbolGraphLocation = bundleURL
                    .appendingPathComponent("symbol-graphs")
                    .appendingPathComponent("clang")
                    .appendingPathComponent("MixedLanguageFramework.symbols.json")
                
                var clangSymbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: clangSymbolGraphLocation))
                
                clangSymbolGraph.symbols = clangSymbolGraph.symbols.filter { preciseIdentifier, _ in
                    !preciseIdentifier.contains("mixedLanguageMethod")
                }
                
                try JSONEncoder().encode(clangSymbolGraph).write(to: clangSymbolGraphLocation)
            }
        )
        
        let protocolRenderNode = try outputConsumer.renderNode(withTitle: "MixedLanguageClassConformingToProtocol")
        
        XCTAssertEqual(
            protocolRenderNode.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/MixedLanguageProtocol-Implementations",
            ]
        )
        
        let objectiveCVariantNode = try renderNodeApplyingObjectiveCVariantOverrides(to: protocolRenderNode)
        
        XCTAssertEqual(
            objectiveCVariantNode.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MixedLanguageClassConformingToProtocol/init()",
                // Not the "MixedLanguageProtocol Implementations" page, because it only contains Swift-only symbols.
            ]
        )
    }

    func testAutomaticSeeAlsoOnlyShowsAPIsAvailableInParentsLanguageForSymbol() throws {
        let outputConsumer = try renderNodeConsumer(for: "MixedLanguageFramework")
        
        // Swift-only symbol.
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "SwiftOnlyClass")
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ]
        )
        
        // Objective-C–only symbol.
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "_MixedLanguageFrameworkVersionString")
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ]
        )
        
        // Swift variant of mixed-language symbol.
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "Bar")
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyClass",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ]
        )
        
        // Objective-C variant of mixed-language symbol.
        XCTAssertEqual(
            try renderNodeApplyingObjectiveCVariantOverrides(to: outputConsumer.renderNode(withTitle: "Bar"))
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
            ]
        )
        
        // Swift variant of mixed-language article.
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "Article")
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyClass",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
            ]
        )
        
        // Objective-C variant of mixed-language article.
        XCTAssertEqual(
            try renderNodeApplyingObjectiveCVariantOverrides(to: outputConsumer.renderNode(withTitle: "Article"))
                .seeAlsoSections
                .flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
            ]
        )
    }
    
    func testMultiLanguageChildOfSingleParentSymbolIsCuratedInMultiLanguage() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "MixedLanguageFrameworkSingleLanguageParent"
        )
        
        let topLevelFrameworkPage = try outputConsumer.renderNode(withTitle: "MixedLanguageFramework")
        
        XCTAssertEqual(
            topLevelFrameworkPage.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MyError-swift.struct/Code",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MyError-swift.struct",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MyErrorDomain",
            ]
        )
        
        let objectiveCTopLevelFrameworkPage = try renderNodeApplyingObjectiveCVariantOverrides(to: topLevelFrameworkPage)
        
        XCTAssertEqual(
            objectiveCTopLevelFrameworkPage.topicSections.flatMap(\.identifiers),
            [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MyError-swift.struct/Code",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/MyErrorDomain",
            ]
        )
    }
    
    func testMultiLanguageSymbolWithLanguageSpecificRelationships() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "MixedLanguageFrameworkWithLanguageSpecificRelationships"
        )
        
        let symbol = try outputConsumer.renderNode(withTitle: "SymbolWithLanguageSpecificRelationships")
        
        XCTAssertEqual(
            symbol.relationshipSections.flatMap { [$0.title] + $0.identifiers },
            [
                "Inherits From",
                "doc://org.swift.MixedLanguageFramework/objc(cs)NSObject",
                "Conforms To",
                "doc://org.swift.MixedLanguageFramework/SH"
            ]
        )
        
        let objectiveCSymbol = try renderNodeApplyingObjectiveCVariantOverrides(to: symbol)
        
        XCTAssertEqual(
            objectiveCSymbol.relationshipSections.flatMap { [$0.title] + $0.identifiers },
            [
                "Inherits From",
                "doc://org.swift.MixedLanguageFramework/objc(cs)NSObject"
            ]
        )
    }
    
    func testMultiLanguageSymbolWithLanguageSpecificProtocolRequirements() throws {
        let outputConsumer = try renderNodeConsumer(
            for: "MixedLanguageFrameworkWithLanguageSpecificRelationships"
        )
        
        let symbol = try outputConsumer.renderNode(withTitle: "myMethod")
        
        XCTAssertEqual(
            symbol.defaultImplementationsSections.flatMap { [$0.title] + $0.identifiers },
            [
                "SymbolWithLanguageSpecificRelationships Implementations",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SymbolWithLanguageSpecificRelationships/myMethodDefaultImplementation",
            ]
        )
        
        let objectiveCSymbol = try renderNodeApplyingObjectiveCVariantOverrides(to: symbol)
        
        XCTAssert(objectiveCSymbol.relationshipSections.isEmpty)
    }
    
    func assertExpectedContent(
        _ renderNode: RenderNode,
        sourceLanguage expectedSourceLanguage: String,
        symbolKind expectedSymbolKind: String? = nil,
        title expectedTitle: String,
        navigatorTitle expectedNavigatorTitle: String?,
        abstract expectedAbstract: String,
        declarationTokens expectedDeclarationTokens: [String]?,
        discussionSection expectedDiscussionSection: [String]?,
        topicSectionIdentifiers expectedTopicSectionIdentifiers: [String],
        seeAlsoSectionIdentifiers expectedSeeAlsoSectionIdentifiers: [String]? = nil,
        referenceTitles expectedReferenceTitles: [String],
        referenceFragments expectedReferenceFragments: [String],
        failureMessage failureMessageForField: (_ field: String) -> String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            renderNode.abstract?.plainText,
            expectedAbstract,
            failureMessageForField("abstract"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            (renderNode.primaryContentSections.last as? ContentRenderSection)?.content.paragraphText,
            expectedDiscussionSection,
            failureMessageForField("discussion section"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.identifier.sourceLanguage.id,
            expectedSourceLanguage,
            failureMessageForField("source language id"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            (renderNode.primaryContentSections.first as? DeclarationsRenderSection)?
                .declarations
                .flatMap(\.tokens)
                .map(\.text),
            expectedDeclarationTokens,
            failureMessageForField("declaration tokens"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.navigatorTitle?.map(\.text).joined(),
            expectedNavigatorTitle,
            failureMessageForField("navigator title"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.title,
            expectedTitle,
            failureMessageForField("title"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.metadata.symbolKind,
            expectedSymbolKind,
            failureMessageForField("symbol kind"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.topicSections.flatMap(\.identifiers),
            expectedTopicSectionIdentifiers,
            failureMessageForField("topic sections identifiers"),
            file: file,
            line: line
        )
        
        if let expectedSeeAlsoSectionIdentifiers = expectedSeeAlsoSectionIdentifiers {
            XCTAssertEqual(
                renderNode.seeAlsoSections.flatMap(\.identifiers),
                expectedSeeAlsoSectionIdentifiers,
                failureMessageForField("see also sections identifiers"),
                file: file,
                line: line
            )
        }
        
        XCTAssertEqual(
            renderNode.references.map(\.value).compactMap { reference in
                (reference as? TopicRenderReference)?.title
            }.sorted(),
            expectedReferenceTitles,
            failureMessageForField("reference titles"),
            file: file,
            line: line
        )
        
        XCTAssertEqual(
            renderNode.references.map(\.value).compactMap { reference in
                (reference as? TopicRenderReference)?.fragments?.map(\.text).joined()
            }.sorted(),
            expectedReferenceFragments,
            failureMessageForField("reference fragments"),
            file: file,
            line: line
        )
    }
    
    func renderNodeApplyingObjectiveCVariantOverrides(to renderNode: RenderNode) throws -> RenderNode {
        let objectiveCVariantData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: RenderJSONEncoder.makeEncoder().encode(renderNode),
            for: [.interfaceLanguage("occ")]
        )
        
        return try RenderJSONDecoder.makeDecoder().decode(
            RenderNode.self,
            from: objectiveCVariantData
        )
    }
}
