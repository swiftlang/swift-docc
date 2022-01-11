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
        
        for documentationNode in context.documentationCache.values {
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
    }
    
    func testOutputsMultiLanguageRenderNodes() throws {
        let outputConsumer = try TestRenderNodeOutputConsumer.mixedLanguageFrameworkConsumer()
        
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
                    .map { $0.metadata.externalID }
            ),
            [
                "MixedLanguageFramework",
                "c:@E@Foo",
                "c:@E@Foo@first",
                "c:@E@Foo@fourth",
                "c:@E@Foo@second",
                "c:@E@Foo@third",
                "c:objc(cs)Bar",
                "c:objc(cs)Bar(cm)MyStringFunction:error:",
            ]
        )
    }
    
    func testFrameworkRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try TestRenderNodeOutputConsumer.mixedLanguageFrameworkConsumer()
        let mixedLanguageFrameworkRenderNode = try outputConsumer.renderNode(
            withIdentifier: "MixedLanguageFramework"
        )
        
        assertExpectedContent(
            mixedLanguageFrameworkRenderNode,
            sourceLanguage: "swift",
            symbolKind: "module",
            title: "MixedLanguageFramework",
            navigatorTitle: nil,
            abstract: "No overview available.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/SwiftOnlyStruct",
            ],
            referenceTitles: [
                "Bar",
                "Foo",
                "Foo",
                "MixedLanguageFramework",
                "SwiftOnlyStruct",
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
        
        let objectiveCVariantData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: RenderJSONEncoder.makeEncoder().encode(mixedLanguageFrameworkRenderNode),
            for: [.interfaceLanguage("occ")]
        )
        
        let objectiveCVariantNode = try RenderJSONDecoder.makeDecoder().decode(
            RenderNode.self,
            from: objectiveCVariantData
        )
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            symbolKind: "module",
            title: "MixedLanguageFramework",
            navigatorTitle: nil,
            abstract: "No overview available.",
            declarationTokens: nil,
            discussionSection: nil,
            topicSectionIdentifiers: [
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Bar",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionNumber",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/_MixedLanguageFrameworkVersionString",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-occ.typealias",
                "doc://org.swift.MixedLanguageFramework/documentation/MixedLanguageFramework/Foo-swift.struct",
            ],
            referenceTitles: [
                "Bar",
                "Foo",
                "Foo",
                "MixedLanguageFramework",
                "SwiftOnlyStruct",
                "_MixedLanguageFrameworkVersionNumber",
                "_MixedLanguageFrameworkVersionString"
            ],
            referenceFragments: [
                "class Bar",
                "struct Foo",
                "struct SwiftOnlyStruct",
            ],
            failureMessage: { fieldName in
                "Objective-C variant of 'MixedLanguageFramework' module has unexpected content for '\(fieldName)'."
            }
        )
    }
    
    func testObjectiveCAuthoredRenderNodeHasExpectedContentAcrossLanguages() throws {
        let outputConsumer = try TestRenderNodeOutputConsumer.mixedLanguageFrameworkConsumer()
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
        
        let objectiveCVariantData = try RenderNodeVariantOverridesApplier().applyVariantOverrides(
            in: RenderJSONEncoder.makeEncoder().encode(fooRenderNode),
            for: [.interfaceLanguage("occ")]
        )
        
        let objectiveCVariantNode = try RenderJSONDecoder.makeDecoder().decode(
            RenderNode.self,
            from: objectiveCVariantData
        )
        
        assertExpectedContent(
            objectiveCVariantNode,
            sourceLanguage: "occ",
            symbolKind: "enum",
            title: "Foo",
            navigatorTitle: "Foo",
            abstract: "A foo.",
            declarationTokens: [
                "FOO",
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
    
    func assertExpectedContent(
        _ renderNode: RenderNode,
        sourceLanguage expectedSourceLanguage: String,
        symbolKind expectedSymbolKind: String,
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
    func renderNodes(withInterfaceLanguages interfaceLanguages: Set<String>) -> [RenderNode] {
        renderNodes.sync { renderNodes in
            renderNodes.filter { renderNode in
                let actualInterfaceLanguages: [String] = renderNode.variants?.flatMap { variant in
                    variant.traits.compactMap { trait in
                        guard case .interfaceLanguage(let interfaceLanguage) = trait else {
                            return nil
                        }
                        return interfaceLanguage
                    }
                } ?? []
                
                return Set(actualInterfaceLanguages) == interfaceLanguages
            }
        }
    }
    
    func renderNode(withIdentifier identifier: String) throws -> RenderNode {
        let renderNode = renderNodes.sync { renderNodes in
            renderNodes.first { renderNode in
                renderNode.metadata.externalID == identifier
            }
        }
        
        return try XCTUnwrap(renderNode)
    }
    
    static func mixedLanguageFrameworkConsumer() throws -> TestRenderNodeOutputConsumer {
        let (bundleURL, _, context) = try testBundleAndContext(copying: "MixedLanguageFramework")
        
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
