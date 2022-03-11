/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import XCTest

class SemaToRenderNodeMixedLanguageTests: ExperimentalObjectiveCTestCase {
    func testBaseRenderNodeFromMixedLanguageFramework() throws {
        let (_, context) = try testBundleAndContext(named: "MixedLanguageFramework")
        
        for documentationNode in context.documentationCache.values where documentationNode.kind.isSymbol {
            let symbolUSR = try XCTUnwrap((documentationNode.semantic as? Symbol)?.externalID)
            
            let expectedSwiftOnlyUSRs: Set<String> = [
                // Swift-only struct - ``SwiftOnlyStruct``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV",
                
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
                
                // Objective-C only typealias - ``Foo-occ.typealias``
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
    
    func testOutputsMultiLanguageRenderNodes() throws {
        let outputConsumer = try mixedLanguageFrameworkConsumer()
        
        XCTAssertEqual(
            Set(
                outputConsumer.renderNodes(withInterfaceLanguages: ["swift"])
                    .map { $0.metadata.externalID }
            ),
            [
                // Swift-only struct - ``SwiftOnlyStruct``:
                "s:22MixedLanguageFramework15SwiftOnlyStructV",
                
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
                
                // Objective-C only typealias - ``Foo-occ.typealias``
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
                "Article",
                "APICollection",
                "MixedLanguageFramework Tutorials",
                "Tutorial Article",
                "Tutorial",
            ]
        )
    }
    
    func testFrameworkRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try mixedLanguageFrameworkConsumer()
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
                "doc://org.swift.MixedLanguageFramework/tutorials/TutorialOverview",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/TutorialArticle",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/Tutorial",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/APICollection",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
            ],
            referenceTitles: [
                "APICollection",
                "Article",
                "Bar",
                "Foo",
                "MixedLanguageFramework",
                "MixedLanguageFramework Tutorials",
                "SwiftOnlyStruct",
                "Tutorial",
                "Tutorial Article",
                "_MixedLanguageFrameworkVersionNumber",
                "_MixedLanguageFrameworkVersionString"
            ],
            referenceFragments: [
                "class Bar",
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
                "doc://org.swift.MixedLanguageFramework/tutorials/TutorialOverview",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/TutorialArticle",
                "doc://org.swift.MixedLanguageFramework/tutorials/MixedLanguageFramework/Tutorial",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Article",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/APICollection",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
            ],
            referenceTitles: [
                "APICollection",
                "Article",
                "Bar",
                "Foo",
                "MixedLanguageFramework",
                "MixedLanguageFramework Tutorials",
                "SwiftOnlyStruct",
                "Tutorial",
                "Tutorial Article",
                "_MixedLanguageFrameworkVersionNumber",
                "_MixedLanguageFrameworkVersionString"
            ],
            referenceFragments: [
                "@interface Bar : NSObject",
                "struct Foo",
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'MixedLanguageFramework' module has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testObjectiveCAuthoredRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try mixedLanguageFrameworkConsumer()
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
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
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
    
    func testArticleInMixedLanguageFramework() throws {
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        let outputConsumer = try mixedLanguageFrameworkConsumer() { url in
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
        enableFeatureFlag(\.isExperimentalObjectiveCSupportEnabled)
        
        let outputConsumer = try mixedLanguageFrameworkConsumer()
        
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

private class TestRenderNodeOutputConsumer: ConvertOutputConsumer {
    var renderNodes = Synchronized<[RenderNode]>([])
    
    func consume(renderNode: RenderNode) throws {
        renderNodes.sync { renderNodes in
            renderNodes.append(renderNode)
        }
    }
    
    func consume(problems: [Problem]) throws { }
    func consume(assetsInBundle bundle: DocumentationBundle) throws { }
    func consume(linkableElementSummaries: [LinkDestinationSummary]) throws { }
    func consume(indexingRecords: [IndexingRecord]) throws { }
    func consume(assets: [RenderReferenceType: [RenderReference]]) throws { }
    func consume(benchmarks: Benchmark) throws { }
    func consume(documentationCoverageInfo: [CoverageDataEntry]) throws { }
    func consume(renderReferenceStore: RenderReferenceStore) throws { }
    func consume(buildMetadata: BuildMetadata) throws { }
}

extension TestRenderNodeOutputConsumer {
    func renderNodes(withInterfaceLanguages interfaceLanguages: Set<String>?) -> [RenderNode] {
        renderNodes.sync { renderNodes in
            renderNodes.filter { renderNode in
                guard let interfaceLanguages = interfaceLanguages else {
                    // If there are no interface languages set, return the nodes with no variants.
                    return renderNode.variants == nil
                }
                
                guard let variants = renderNode.variants else {
                    return false
                }
                
                let actualInterfaceLanguages: [String] = variants.flatMap { variant in
                    variant.traits.compactMap { trait in
                        guard case .interfaceLanguage(let interfaceLanguage) = trait else {
                            return nil
                        }
                        return interfaceLanguage
                    }
                }
                
                return Set(actualInterfaceLanguages) == interfaceLanguages
            }
        }
    }
    
    func renderNode(withIdentifier identifier: String) throws -> RenderNode {
        try renderNode(where: { renderNode in renderNode.metadata.externalID == identifier })
    }
    
    func renderNode(withTitle title: String) throws -> RenderNode {
        try renderNode(where: { renderNode in renderNode.metadata.title == title })
    }
    
    private func renderNode(where predicate: (RenderNode) -> Bool) throws -> RenderNode {
        let renderNode = renderNodes.sync { renderNodes in
            renderNodes.first { renderNode in
                predicate(renderNode)
            }
        }
        
        return try XCTUnwrap(renderNode)
    }
}

fileprivate extension SemaToRenderNodeMixedLanguageTests {
    func mixedLanguageFrameworkConsumer(
        configureBundle: ((URL) throws -> Void)? = nil
    ) throws -> TestRenderNodeOutputConsumer {
        let (bundleURL, _, context) = try testBundleAndContext(
            copying: "MixedLanguageFramework",
            configureBundle: configureBundle
        )
        
        var converter = DocumentationConverter(
            documentationBundleURL: bundleURL,
            emitDigest: false,
            documentationCoverageOptions: .noCoverage,
            currentPlatforms: nil,
            workspace: context.dataProvider as! DocumentationWorkspace,
            context: context,
            dataProvider: try LocalFileSystemDataProvider(rootURL: bundleURL),
            bundleDiscoveryOptions: BundleDiscoveryOptions()
        )
        
        let outputConsumer = TestRenderNodeOutputConsumer()
        let (_, _) = try converter.convert(outputConsumer: outputConsumer)
        
        return outputConsumer
    }
}
