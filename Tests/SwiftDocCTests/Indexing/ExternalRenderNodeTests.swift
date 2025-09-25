/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@_spi(ExternalLinks) @testable import SwiftDocC
import SwiftDocCTestUtilities

class ExternalRenderNodeTests: XCTestCase {
    private func generateExternalResolver() -> TestMultiResultExternalReferenceResolver {
        let externalResolver = TestMultiResultExternalReferenceResolver()
        externalResolver.bundleID = "com.test.external"
        externalResolver.entitiesToReturn["/path/to/external/swiftArticle"] = .success(
            .init(
                referencePath: "/path/to/external/swiftArticle",
                title: "SwiftArticle",
                kind: .article,
                language: .swift,
                platforms: [.init(name: "iOS", introduced: nil, isBeta: false)]
            )
        )
        externalResolver.entitiesToReturn["/path/to/external/objCArticle"] = .success(
            .init(
                referencePath: "/path/to/external/objCArticle",
                title: "ObjCArticle",
                kind: .article,
                language: .objectiveC,
                platforms: [.init(name: "macOS", introduced: nil, isBeta: true)]
            )
        )
        externalResolver.entitiesToReturn["/path/to/external/swiftSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/swiftSymbol",
                title: "SwiftSymbol",
                kind: .class,
                language: .swift,
                declarationFragments: .init(declarationFragments: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "SwiftSymbol", preciseIdentifier: nil)
                ]),
                platforms: [.init(name: "iOS", introduced: nil, isBeta: true)]
            )
        )
        externalResolver.entitiesToReturn["/path/to/external/objCSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/objCSymbol",
                title: "ObjCSymbol",
                kind: .function,
                language: .objectiveC,
                declarationFragments: .init(declarationFragments: [
                    .init(kind: .text, spelling: "- ", preciseIdentifier: nil),
                    .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: nil),
                    .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "ObjCSymbol", preciseIdentifier: nil)
                ]),
                platforms: [.init(name: "macOS", introduced: nil, isBeta: false)]
            )
        )
        externalResolver.entitiesToReturn["/path/to/external/navigatorTitleSwiftSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/navigatorTitleSwiftSymbol",
                title: "NavigatorTitleSwiftSymbol (title)",
                kind: .class,
                language: .swift,
                declarationFragments: .init(declarationFragments: [
                    .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
                    .init(kind: .text, spelling: " ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "NavigatorTitleSwiftSymbol", preciseIdentifier: nil)
                ]),
                navigatorTitle: .init(declarationFragments: [
                    .init(kind: .identifier, spelling: "NavigatorTitleSwiftSymbol (navigator title)", preciseIdentifier: nil)
                ]),
                platforms: [.init(name: "iOS", introduced: nil, isBeta: true)]
            )
        )
        externalResolver.entitiesToReturn["/path/to/external/navigatorTitleObjCSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/navigatorTitleObjCSymbol",
                title: "NavigatorTitleObjCSymbol (title)",
                kind: .function,
                language: .objectiveC,
                declarationFragments: .init(declarationFragments: [
                    .init(kind: .text, spelling: "- ", preciseIdentifier: nil),
                    .init(kind: .text, spelling: "(", preciseIdentifier: nil),
                    .init(kind: .typeIdentifier, spelling: "void", preciseIdentifier: nil),
                    .init(kind: .text, spelling: ") ", preciseIdentifier: nil),
                    .init(kind: .identifier, spelling: "ObjCSymbol", preciseIdentifier: nil)
                ]),
                navigatorTitle: .init(declarationFragments: [
                    .init(kind: .identifier, spelling: "NavigatorTitleObjCSymbol (navigator title)", preciseIdentifier: nil)
                ]),
                platforms: [.init(name: "macOS", introduced: nil, isBeta: false)]
            )
        )
        return externalResolver
    }
        
    func testExternalRenderNode() async throws {
        let externalResolver = generateExternalResolver()
        let (_, bundle, context) = try await testBundleAndContext(
            copying: "MixedLanguageFramework",
            externalResolvers: [externalResolver.bundleID: externalResolver]
        ) { url in
            let mixedLanguageFrameworkExtension = """
                # ``MixedLanguageFramework``
                
                This symbol has a Swift and Objective-C variant.

                ## Topics
                
                ### External Reference

                - <doc://com.test.external/path/to/external/swiftArticle>
                - <doc://com.test.external/path/to/external/swiftSymbol>
                - <doc://com.test.external/path/to/external/objCArticle>
                - <doc://com.test.external/path/to/external/objCSymbol>
                """
            try mixedLanguageFrameworkExtension.write(to: url.appendingPathComponent("/MixedLanguageFramework.md"), atomically: true, encoding: .utf8)
        }
        
        let externalRenderNodes = context.externalCache.valuesByReference.values.map {
            ExternalRenderNode(externalEntity: $0, bundleIdentifier: bundle.id)
        }.sorted(by: \.titleVariants.defaultValue)
        XCTAssertEqual(externalRenderNodes.count, 4)
        
        XCTAssertEqual(externalRenderNodes[0].identifier.absoluteString, "doc://org.swift.MixedLanguageFramework/path/to/external/objCArticle")
        XCTAssertEqual(externalRenderNodes[0].kind, .article)
        XCTAssertEqual(externalRenderNodes[0].symbolKind, nil)
        XCTAssertEqual(externalRenderNodes[0].role, "article")
        XCTAssertEqual(externalRenderNodes[0].externalIdentifier.identifier, "doc://com.test.external/path/to/external/objCArticle")
        XCTAssertTrue(externalRenderNodes[0].isBeta)

        XCTAssertEqual(externalRenderNodes[1].identifier.absoluteString, "doc://org.swift.MixedLanguageFramework/path/to/external/objCSymbol")
        XCTAssertEqual(externalRenderNodes[1].kind, .symbol)
        XCTAssertEqual(externalRenderNodes[1].symbolKind, .func)
        XCTAssertEqual(externalRenderNodes[1].role, "symbol")
        XCTAssertEqual(externalRenderNodes[1].externalIdentifier.identifier, "doc://com.test.external/path/to/external/objCSymbol")
        XCTAssertFalse(externalRenderNodes[1].isBeta)
        
        XCTAssertEqual(externalRenderNodes[2].identifier.absoluteString, "doc://org.swift.MixedLanguageFramework/path/to/external/swiftArticle")
        XCTAssertEqual(externalRenderNodes[2].kind, .article)
        XCTAssertEqual(externalRenderNodes[2].symbolKind, nil)
        XCTAssertEqual(externalRenderNodes[2].role, "article")
        XCTAssertEqual(externalRenderNodes[2].externalIdentifier.identifier, "doc://com.test.external/path/to/external/swiftArticle")
        XCTAssertFalse(externalRenderNodes[2].isBeta)
        
        XCTAssertEqual(externalRenderNodes[3].identifier.absoluteString, "doc://org.swift.MixedLanguageFramework/path/to/external/swiftSymbol")
        XCTAssertEqual(externalRenderNodes[3].kind, .symbol)
        XCTAssertEqual(externalRenderNodes[3].symbolKind, .class)
        XCTAssertEqual(externalRenderNodes[3].role, "symbol")
        XCTAssertEqual(externalRenderNodes[3].externalIdentifier.identifier, "doc://com.test.external/path/to/external/swiftSymbol")
        XCTAssertTrue(externalRenderNodes[3].isBeta)
    }
    
    func testExternalRenderNodeVariantRepresentation() throws {
        let reference = ResolvedTopicReference(bundleID: "com.test.external", path: "/path/to/external/symbol", sourceLanguages: [.swift, .objectiveC])
        
        // Variants for the title
        let swiftTitle = "Swift Symbol"
        let objcTitle  = "Objective-C Symbol"
        
        // Variants for the fragments
        let swiftFragments: [DeclarationRenderSection.Token] = [.init(text: "func", kind: .keyword), .init(text: "symbol", kind: .identifier)]
        let objcFragments:  [DeclarationRenderSection.Token] = [.init(text: "func", kind: .keyword), .init(text: "occ_symbol", kind: .identifier)]
        
        let externalEntity = LinkResolver.ExternalEntity(
            kind: .function,
            language: .swift,
            relativePresentationURL: URL(string: "/example/path/to/external/symbol")!,
            referenceURL: reference.url,
            title: swiftTitle,
            availableLanguages: [.swift, .objectiveC],
            usr: "some-unique-symbol-id",
            subheadingDeclarationFragments: swiftFragments,
            variants: [
                .init(
                    traits: [.interfaceLanguage(SourceLanguage.objectiveC.id)],
                    language: .objectiveC,
                    title: objcTitle,
                    subheadingDeclarationFragments: objcFragments
                )
            ]
        )
        let externalRenderNode = ExternalRenderNode(
            externalEntity: externalEntity,
            bundleIdentifier: "com.test.external"
        )
        
        let swiftNavigatorExternalRenderNode = try XCTUnwrap(
            NavigatorExternalRenderNode(renderNode: externalRenderNode)
        )
        XCTAssertEqual(swiftNavigatorExternalRenderNode.metadata.title, swiftTitle)
        XCTAssertFalse(swiftNavigatorExternalRenderNode.metadata.isBeta)
        XCTAssertEqual(swiftNavigatorExternalRenderNode.metadata.fragments, swiftFragments)
        
        let objcNavigatorExternalRenderNode = try XCTUnwrap(
            NavigatorExternalRenderNode(renderNode: externalRenderNode, trait: .interfaceLanguage(SourceLanguage.objectiveC.id))
        )
        XCTAssertEqual(objcNavigatorExternalRenderNode.metadata.title, objcTitle)
        XCTAssertFalse(objcNavigatorExternalRenderNode.metadata.isBeta)
        XCTAssertEqual(objcNavigatorExternalRenderNode.metadata.fragments, objcFragments)
    }

    func testNavigatorWithExternalNodes() async throws {
        let catalog = Folder(name: "ModuleName.docc", content: [
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .swift, kind: .class, pathComponents: ["SomeClass"])
                ]))
            ]),
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .objectiveC, kind: .class, pathComponents: ["TLASomeClass"])
                ]))
            ]),
            
            InfoPlist(identifier: "some.custom.identifier"),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Curate a few external language-specific symbols and articles 

            ## Topics

            ### External Reference

            - <doc://com.test.external/path/to/external/swiftArticle>
            - <doc://com.test.external/path/to/external/swiftSymbol>
            - <doc://com.test.external/path/to/external/objCArticle>
            - <doc://com.test.external/path/to/external/objCSymbol>
            """),
        ])
        
        var configuration = DocumentationContext.Configuration()
        let externalResolver = generateExternalResolver()
        configuration.externalDocumentationConfiguration.sources[externalResolver.bundleID] = externalResolver
        let (bundle, context) = try await loadBundle(catalog: catalog, configuration: configuration)
        XCTAssert(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: bundle.id.rawValue, sortRootChildrenByName: true, groupByLanguage: true)
        builder.setup()
        for externalLink in context.externalCache {
            let externalRenderNode = ExternalRenderNode(externalEntity: externalLink.value, bundleIdentifier: bundle.id)
            try builder.index(renderNode: externalRenderNode)
        }
        for identifier in context.knownPages {
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity))
            try builder.index(renderNode: renderNode)
        }
        builder.finalize()
        let renderIndex = try RenderIndex.fromURL(targetURL.appendingPathComponent("index.json"))

        // Verify that there are no uncurated external links at the top level
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.swift.id]?.count(where: \.isExternal), 0)
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.objectiveC.id]?.count(where: \.isExternal), 0)

        
        func externalNodes(by language: SourceLanguage) -> [RenderIndex.Node]? {
            renderIndex.interfaceLanguages[language.id]?.first?.children?.filter(\.isExternal)
        }
        
        // Verify that the curated external links are part of the index.
        let swiftExternalNodes = try XCTUnwrap(externalNodes(by: .swift))
        XCTAssertEqual(swiftExternalNodes.count, 2)

        let objcExternalNodes = try XCTUnwrap(externalNodes(by: .objectiveC))
        XCTAssertEqual(objcExternalNodes.count, 2)

        let swiftArticleExternalNode = try XCTUnwrap(swiftExternalNodes.first(where: { $0.path == "/path/to/external/swiftarticle" }))
        let swiftSymbolExternalNode = try XCTUnwrap(swiftExternalNodes.first(where: { $0.path == "/path/to/external/swiftsymbol" }))
        let objcArticleExternalNode = try XCTUnwrap(objcExternalNodes.first(where: { $0.path == "/path/to/external/objcarticle" }))
        let objcSymbolExternalNode = try XCTUnwrap(objcExternalNodes.first(where: { $0.path == "/path/to/external/objcsymbol" }))

        XCTAssertEqual(swiftArticleExternalNode.title, "SwiftArticle")
        XCTAssertEqual(swiftArticleExternalNode.isBeta, false)
        XCTAssertEqual(swiftArticleExternalNode.type, "article")

        XCTAssertEqual(swiftSymbolExternalNode.title, "SwiftSymbol")  // Classes don't use declaration fragments in their navigator title
        XCTAssertEqual(swiftSymbolExternalNode.isBeta, true)
        XCTAssertEqual(swiftSymbolExternalNode.type, "class")

        XCTAssertEqual(objcArticleExternalNode.title, "ObjCArticle")
        XCTAssertEqual(objcArticleExternalNode.isBeta, true)
        XCTAssertEqual(objcArticleExternalNode.type, "article")

        XCTAssertEqual(objcSymbolExternalNode.title, "- (void) ObjCSymbol")
        XCTAssertEqual(objcSymbolExternalNode.isBeta, false)
        XCTAssertEqual(objcSymbolExternalNode.type, "func")
    }
    
    func testNavigatorWithExternalNodesWithNavigatorTitle() async throws {
        let catalog = Folder(name: "ModuleName.docc", content: [
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .swift, kind: .class, pathComponents: ["SomeClass"])
                ]))
            ]),
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .objectiveC, kind: .class, pathComponents: ["TLASomeClass"])
                ]))
            ]),
            
            InfoPlist(identifier: "some.custom.identifier"),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Curate a few external language-specific symbols and articles 

            ## Topics

            ### External Reference

            - <doc://com.test.external/path/to/external/navigatorTitleSwiftSymbol>
            - <doc://com.test.external/path/to/external/navigatorTitleObjCSymbol>
            """),
        ])
        
        var configuration = DocumentationContext.Configuration()
        let externalResolver = generateExternalResolver()
        configuration.externalDocumentationConfiguration.sources[externalResolver.bundleID] = externalResolver
        let (bundle, context) = try await loadBundle(catalog: catalog, configuration: configuration)
        XCTAssert(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: bundle.id.rawValue, sortRootChildrenByName: true, groupByLanguage: true)
        builder.setup()
        for externalLink in context.externalCache {
            let externalRenderNode = ExternalRenderNode(externalEntity: externalLink.value, bundleIdentifier: bundle.id)
            try builder.index(renderNode: externalRenderNode)
        }
        for identifier in context.knownPages {
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity))
            try builder.index(renderNode: renderNode)
        }
        builder.finalize()
        let renderIndex = try RenderIndex.fromURL(targetURL.appendingPathComponent("index.json"))

        // Verify that there are no uncurated external links at the top level
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.swift.id]?.count(where: \.isExternal), 0)
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.objectiveC.id]?.count(where: \.isExternal), 0)

        func externalNodes(by language: SourceLanguage) -> [RenderIndex.Node]? {
            renderIndex.interfaceLanguages[language.id]?.first?.children?.filter(\.isExternal)
        }
        
        // Verify that the curated external links are part of the index.
        let swiftExternalNodes = try XCTUnwrap(externalNodes(by: .swift))
        let objcExternalNodes = try XCTUnwrap(externalNodes(by: .objectiveC))

        XCTAssertEqual(swiftExternalNodes.count, 1)
        XCTAssertEqual(objcExternalNodes.count, 1)

        let swiftSymbolExternalNode = try XCTUnwrap(swiftExternalNodes.first)
        let objcSymbolExternalNode = try XCTUnwrap(objcExternalNodes.first)

        XCTAssertEqual(swiftSymbolExternalNode.title, "NavigatorTitleSwiftSymbol (title)")  // Swift types prefer not using the navigator title where possible
        XCTAssertEqual(objcSymbolExternalNode.title, "NavigatorTitleObjCSymbol (navigator title)")  // Objective C types prefer using the navigator title where possible
    }

    func testNavigatorWithExternalNodesOnlyAddsCuratedNodesToNavigator() async throws {
        let catalog = Folder(name: "ModuleName.docc", content: [
            Folder(name: "swift", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .swift, kind: .class, pathComponents: ["SomeClass"])
                ]))
            ]),
            Folder(name: "clang", content: [
                JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                    makeSymbol(id: "some-symbol-id", language: .objectiveC, kind: .class, pathComponents: ["TLASomeClass"])
                ]))
            ]),
            
            InfoPlist(identifier: "some.custom.identifier"),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            
            Curate and link to a few external language-specific symbols and articles 

            It also has an external reference which is not curated in the Topics section:
            <doc://com.test.external/path/to/external/objCArticle>
            <doc://com.test.external/path/to/external/swiftSymbol>
            
            ## Topics
            
            ### External Reference
            
            - <doc://com.test.external/path/to/external/swiftArticle>
            - <doc://com.test.external/path/to/external/objCSymbol>
            """),
        ])
        
        var configuration = DocumentationContext.Configuration()
        let externalResolver = generateExternalResolver()
        configuration.externalDocumentationConfiguration.sources[externalResolver.bundleID] = externalResolver
        let (bundle, context) = try await loadBundle(catalog: catalog, configuration: configuration)
        XCTAssert(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let renderContext = RenderContext(documentationContext: context, bundle: bundle)
        let converter = DocumentationContextConverter(bundle: bundle, context: context, renderContext: renderContext)
        let targetURL = try createTemporaryDirectory()
        let builder = NavigatorIndex.Builder(outputURL: targetURL, bundleIdentifier: bundle.id.rawValue, sortRootChildrenByName: true, groupByLanguage: true)
        builder.setup()
        for externalLink in context.externalCache {
            let externalRenderNode = ExternalRenderNode(externalEntity: externalLink.value, bundleIdentifier: bundle.id)
            try builder.index(renderNode: externalRenderNode)
        }
        for identifier in context.knownPages {
            let entity = try context.entity(with: identifier)
            let renderNode = try XCTUnwrap(converter.renderNode(for: entity))
            try builder.index(renderNode: renderNode)
        }
        builder.finalize()
        let renderIndex = try RenderIndex.fromURL(targetURL.appendingPathComponent("index.json"))
        
        // Verify that there are no uncurated external links at the top level
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.swift.id]?.count(where: \.isExternal), 0)
        XCTAssertEqual(renderIndex.interfaceLanguages[SourceLanguage.objectiveC.id]?.count(where: \.isExternal), 0)

        // Verify that the curated external links are part of the index.
        let swiftExternalNodes = (renderIndex.interfaceLanguages[SourceLanguage.swift.id]?.first?.children?.filter(\.isExternal) ?? []).sorted(by: \.title)
        let objcExternalNodes  = (renderIndex.interfaceLanguages[SourceLanguage.objectiveC.id]?.first?.children?.filter(\.isExternal) ?? []).sorted(by: \.title)
        XCTAssertEqual(swiftExternalNodes.count, 1)
        XCTAssertEqual(objcExternalNodes.count, 1)
        XCTAssertEqual(swiftExternalNodes.map(\.title), ["SwiftArticle"])
        XCTAssertEqual(objcExternalNodes.map(\.title), ["- (void) ObjCSymbol"])
        XCTAssertEqual(swiftExternalNodes.map(\.type), ["article"])
        XCTAssertEqual(objcExternalNodes.map(\.type), ["func"])
    }

    func testExternalRenderNodeVariantRepresentationWhenIsBeta() throws {
        let reference = ResolvedTopicReference(bundleID: "com.test.external", path: "/path/to/external/symbol", sourceLanguages: [.swift, .objectiveC])
        
        // Variants for the title
        let swiftTitle = "Swift Symbol"
        let objcTitle  = "Objective-C Symbol"
        
        // Variants for the fragments
        let swiftFragments: [DeclarationRenderSection.Token] = [.init(text: "func", kind: .keyword), .init(text: "symbol", kind: .identifier)]
        let objcFragments:  [DeclarationRenderSection.Token] = [.init(text: "func", kind: .keyword), .init(text: "occ_symbol", kind: .identifier)]
        
        let externalEntity = LinkResolver.ExternalEntity(
            kind: .function,
            language: .swift,
            relativePresentationURL: URL(string: "/example/path/to/external/symbol")!,
            referenceURL: reference.url,
            title: swiftTitle,
            availableLanguages: [.swift, .objectiveC],
            platforms: [.init(name: "Platform name", introduced: "1.2.3", isBeta: true)],
            usr: "some-unique-symbol-id",
            subheadingDeclarationFragments: swiftFragments,
            variants: [
                .init(
                    traits: [.interfaceLanguage(SourceLanguage.objectiveC.id)],
                    language: .objectiveC,
                    title: objcTitle,
                    subheadingDeclarationFragments: objcFragments
                )
            ]
        )
        let externalRenderNode = ExternalRenderNode(
            externalEntity: externalEntity,
            bundleIdentifier: "com.test.external"
        )
        
        let swiftNavigatorExternalRenderNode = try XCTUnwrap(
            NavigatorExternalRenderNode(renderNode: externalRenderNode)
        )
        XCTAssertEqual(swiftNavigatorExternalRenderNode.metadata.title, swiftTitle)
        XCTAssertTrue(swiftNavigatorExternalRenderNode.metadata.isBeta)

        let objcNavigatorExternalRenderNode = try XCTUnwrap(
            NavigatorExternalRenderNode(renderNode: externalRenderNode, trait: .interfaceLanguage(SourceLanguage.objectiveC.id))
        )
        XCTAssertEqual(objcNavigatorExternalRenderNode.metadata.title, objcTitle)
        XCTAssertTrue(objcNavigatorExternalRenderNode.metadata.isBeta)
    }
}
