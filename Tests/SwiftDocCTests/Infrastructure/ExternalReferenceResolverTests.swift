/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@_spi(ExternalLinks) @testable import SwiftDocC
import Markdown
import SymbolKit
import SwiftDocCTestUtilities

class ExternalReferenceResolverTests: XCTestCase {
    class TestExternalReferenceResolver: ExternalDocumentationSource {
        var bundleIdentifier = "com.external.testbundle"
        var expectedReferencePath = "/externally/resolved/path"
        var expectedFragment: String? = nil
        var resolvedEntityTitle = "Externally Resolved Title"
        var resolvedEntityKind = DocumentationNode.Kind.article
        var resolvedEntityLanguage = SourceLanguage.swift
        var resolvedEntityDeclarationFragments: SymbolGraph.Symbol.DeclarationFragments? = nil
   
        var resolvedExternalPaths = [String]()
        
        func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
            if let path = reference.url?.path {
                resolvedExternalPaths.append(path)
            }
            return .success(ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: expectedReferencePath, fragment: expectedFragment, sourceLanguage: resolvedEntityLanguage))
        }
        
        func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
            guard reference.bundleIdentifier == bundleIdentifier else {
                fatalError("It is a programming mistake to retrieve an entity for a reference that the external resolver didn't resolve.")
            }
            
            let (kind, role) = DocumentationContentRenderer.renderKindAndRole(resolvedEntityKind, semantic: nil)
            return LinkResolver.ExternalEntity(
                topicRenderReference: TopicRenderReference(
                    identifier: .init(reference.absoluteString),
                    title: resolvedEntityTitle,
                    abstract: [.text("Externally Resolved Markup Content")],
                    url: "/example" + reference.path + (reference.fragment.map { "#\($0)" } ?? ""),
                    kind: kind,
                    role: role,
                    fragments: resolvedEntityDeclarationFragments?.declarationFragments.map { fragment in
                        return DeclarationRenderSection.Token(fragment: fragment, identifier: nil)
                    },
                    estimatedTime: nil,
                    titleStyle: resolvedEntityKind.isSymbol ? .symbol : .title
                ),
                renderReferenceDependencies: RenderReferenceDependencies(),
                sourceLanguages: [resolvedEntityLanguage]
            )
        }
    }
    
    func testResolveExternalReference() throws {
        let sourceURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        // Create a copy of the test bundle
        let bundleURL = try createTemporaryDirectory().appendingPathComponent("test.docc")
        try FileManager.default.copyItem(at: sourceURL, to: bundleURL)
        
        // Add external link
        let myClassMDURL = bundleURL.appendingPathComponent("documentation").appendingPathComponent("myclass.md")
        try String(contentsOf: myClassMDURL)
            .replacingOccurrences(of: "MyClass abstract.", with: "MyClass uses a <doc://com.external.testbundle/article>.")
            .write(to: myClassMDURL, atomically: true, encoding: .utf8)
        
        // Load bundle and context
        let automaticDataProvider = try LocalFileSystemDataProvider(rootURL: bundleURL)
        let bundle = try XCTUnwrap(automaticDataProvider.bundles().first)
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalDocumentationSources = ["com.external.testbundle" : TestExternalReferenceResolver()]

        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)

        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.external.testbundle/article")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyClass", sourceLanguage: .swift)

        guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Couldn't resolve \(unresolved)")
            return
        }
        
        XCTAssertEqual("com.external.testbundle", resolved.bundleIdentifier)
        XCTAssertEqual("/externally/resolved/path", resolved.path)
        
        let expectedURL = URL(string: "doc://com.external.testbundle/externally/resolved/path")
        XCTAssertEqual(expectedURL, resolved.url)
    }
    
    // Asserts that an external reference from a source language not locally included
    // in the current DocC catalog is still included in any rendered topic groups that
    // manually curate it. (94406023)
    func testExternalReferenceInOtherLanguageIsIncludedInTopicGroup() throws {
        let externalResolver = TestExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        externalResolver.expectedReferencePath = "/path/to/external/api"
        externalResolver.resolvedEntityTitle = "Name of API"
        externalResolver.resolvedEntityKind = .technology
        
        // Set the language of the externally resolved entity to 'data'.
        externalResolver.resolvedEntityLanguage = .data
        
        let (_, bundle, context) = try testBundleAndContext(
            copying: "TestBundle",
            externalResolvers: [externalResolver.bundleIdentifier: externalResolver]
        ) { url in
            let sideClassExtension = """
                # ``SideKit/SideClass``

                ## Topics
                    
                ### External reference

                - <doc://com.test.external/path/to/external/api>
                
                """
            
            let sideClassExtensionURL = url.appendingPathComponent(
                "documentation/sideclass.md",
                isDirectory: false
            )
            try sideClassExtension.write(to: sideClassExtensionURL, atomically: true, encoding: .utf8)
        }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let sideClassReference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SideKit/SideClass",
            sourceLanguage: .swift
        )
        let node = try context.entity(with: sideClassReference)
        let fileURL = try XCTUnwrap(context.documentURL(for: node.reference))
        let renderNode = try converter.convert(node, at: fileURL)
        
        // First assert that the external reference is included in the render node's references
        // and is defined as expected.
        let externalRenderReference = try XCTUnwrap(
            renderNode.references["doc://com.test.external/path/to/external/api"] as? TopicRenderReference
        )
        XCTAssertEqual(
            externalRenderReference.identifier.identifier,
            "doc://com.test.external/path/to/external/api"
        )
        XCTAssertEqual(externalRenderReference.title, "Name of API")
        XCTAssertEqual(externalRenderReference.url, "/example/path/to/external/api")
        XCTAssertEqual(externalRenderReference.kind, .overview)
        XCTAssertEqual(externalRenderReference.role, RenderMetadata.Role.overview.rawValue)
        
        // Then assert the topic group including that reference was actually included.
        let externalReferencesTopicSection = try XCTUnwrap(
            renderNode.topicSections.first { topicSection in
                topicSection.title == "External reference"
            }
        )
        XCTAssertEqual(
            externalReferencesTopicSection.identifiers.first,
            externalRenderReference.identifier.identifier
        )
    }
    
    func testResolvesReferencesExternallyOnlyWhenFallbackResolversAreSet() throws {
        let workspace = DocumentationWorkspace()
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        let bundleIdentifier = bundle.identifier
        
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://\(bundleIdentifier)/ArticleThatDoesNotExistInLocally")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "", sourceLanguage: .swift)
        
        do {
            context.externalDocumentationSources = [:]
            context.convertServiceFallbackResolver = nil
            
            if case .success = context.resolve(.unresolved(unresolved), in: parent) {
                XCTFail("The reference was unexpectedly resolved.")
            }
        }
        
        do {
            class TestFallbackResolver: ConvertServiceFallbackResolver {
                init(bundleIdentifier: String) {
                    resolver.bundleIdentifier = bundleIdentifier
                }
                var bundleIdentifier: String {
                    resolver.bundleIdentifier
                }
                private var resolver = TestExternalReferenceResolver()
                func resolve(_ reference: SwiftDocC.TopicReference) -> TopicReferenceResolutionResult {
                    TestExternalReferenceResolver().resolve(reference)
                }
                func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity? {
                    nil
                }
                func resolve(assetNamed assetName: String) -> DataAsset? {
                    nil
                }
            }
            
            context.externalDocumentationSources = [:]
            context.convertServiceFallbackResolver = TestFallbackResolver(bundleIdentifier: "org.swift.docc.example")
            
            guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
                XCTFail("The reference was unexpectedly unresolved.")
                return
            }
            
            XCTAssertEqual("com.external.testbundle", resolved.bundleIdentifier)
            XCTAssertEqual("/externally/resolved/path", resolved.path)
            
            let expectedURL = URL(string: "doc://com.external.testbundle/externally/resolved/path")
            XCTAssertEqual(expectedURL, resolved.url)
            
            try workspace.unregisterProvider(dataProvider)
            context.externalDocumentationSources = [:]
            guard case .failure = context.resolve(.unresolved(unresolved), in: parent) else {
                XCTFail("Unexpectedly resolved \(unresolved.topicURL) despite removing a data provider for it")
                return
            }
        }
    }
    
    func testLoadEntityForExternalReference() throws {
        let workspace = DocumentationWorkspace()
        let bundle = try testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalDocumentationSources = ["com.external.testbundle" : TestExternalReferenceResolver()]
        
        let identifier = ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/externally/resolved/path", sourceLanguage: .swift)
        
        XCTAssertThrowsError(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "some.other.bundle", path: identifier.path, sourceLanguage: .swift)))
        
        XCTAssertThrowsError(try context.entity(with: identifier))
    }
    
    func testRenderReferenceHasSymbolKind() throws {
        let fixtures: [(DocumentationNode.Kind, RenderNode.Kind)] = [
            (.class, .symbol),
            (.structure, .symbol),
            (.enumerationCase, .symbol),
            (.instanceMethod, .symbol),
            (.operator, .symbol),
            (.typeAlias, .symbol),
            (.keyword, .symbol),
            (.restAPI, .article),
            (.tag, .symbol),
            (.propertyList, .article),
            (.object, .symbol),
        ]
        
        for fixture in fixtures {
            let (resolvedEntityKind, renderNodeKind) = fixture
            
            let workspace = DocumentationWorkspace()
            let context = try DocumentationContext(dataProvider: workspace)
            
            let externalResolver = TestExternalReferenceResolver()
            externalResolver.bundleIdentifier = "com.test.external"
            externalResolver.expectedReferencePath = "/path/to/external/symbol"
            externalResolver.resolvedEntityTitle = "ClassName"
            externalResolver.resolvedEntityKind = resolvedEntityKind
            context.externalDocumentationSources = [externalResolver.bundleIdentifier: externalResolver]
            
            let bundle = try testBundle(named: "TestBundle")
            
            let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
            try workspace.registerProvider(dataProvider)
            
            let converter = DocumentationNodeConverter(bundle: bundle, context: context)
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
            
            guard let fileURL = context.documentURL(for: node.reference) else {
                XCTFail("Unable to find the file for \(node.reference.path)")
                return
            }
            
            let expectedReference = "doc://\(externalResolver.bundleIdentifier)\(externalResolver.expectedReferencePath)"
            XCTAssertTrue(
                try String(contentsOf: fileURL).contains("<\(expectedReference)>"),
                "The test content should include a link for the external reference resolver to resolve"
            )
            
            let renderNode = try converter.convert(node, at: fileURL)
            
            guard let symbolRenderReference = renderNode.references[expectedReference] as? TopicRenderReference else {
                XCTFail("The external reference should be resolved and included among the Tutorial's references.")
                return
            }
            
            XCTAssertEqual(symbolRenderReference.identifier.identifier, "doc://com.test.external/path/to/external/symbol")
            XCTAssertEqual(symbolRenderReference.title, "ClassName")
            XCTAssertEqual(symbolRenderReference.url, "/example/path/to/external/symbol")
            XCTAssertEqual(symbolRenderReference.kind, renderNodeKind)
        }
    }
    
    func testReferenceFromRenderedPageHasFragments() throws {
        let externalResolver = TestExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        externalResolver.expectedReferencePath = "/path/to/external/symbol"
        externalResolver.resolvedEntityTitle = "ClassName"
        externalResolver.resolvedEntityKind = .class
        externalResolver.resolvedEntityDeclarationFragments = .init(declarationFragments: [
            .init(kind: .keyword, spelling: "class", preciseIdentifier: nil),
            .init(kind: .text, spelling: " ", preciseIdentifier: nil),
            .init(kind: .identifier, spelling: "ClassName", preciseIdentifier: nil),
        ])
        
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # ``SideKit/SideClass``

            Curate some of the children and leave the rest for automatic curation.

            ## Topics
                
            ### External reference

            - <doc://com.test.external/path/to/external/symbol>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        guard let fileURL = context.documentURL(for: node.reference) else {
            XCTFail("Unable to find the file for \(node.reference.path)")
            return
        }
        
        let renderNode = try converter.convert(node, at: fileURL)
        
        guard let symbolRenderReference = renderNode.references["doc://com.test.external/path/to/external/symbol"] as? TopicRenderReference else {
            XCTFail("The external reference should be resolved and included among the SideClass symbols's references.")
            return
        }
        
        XCTAssertEqual(symbolRenderReference.identifier.identifier, "doc://com.test.external/path/to/external/symbol")
        XCTAssertEqual(symbolRenderReference.title, "ClassName")
        XCTAssertEqual(symbolRenderReference.url, "/example/path/to/external/symbol") // External references in topic groups use relative URLs
        XCTAssertEqual(symbolRenderReference.kind, .symbol)
        XCTAssertEqual(symbolRenderReference.fragments, [
            .init(text: "class", kind: .keyword),
            .init(text: " ", kind: .text),
            .init(text: "ClassName", kind: .identifier),
        ])
    }
    
    func testExternalReferenceWithDifferentResolvedPath() throws {
        let externalResolver = TestExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        // Return a different path for this resolved reference
        externalResolver.expectedReferencePath = "/path/to/externally-resolved-symbol"
        externalResolver.resolvedEntityTitle = "ClassName"
        externalResolver.resolvedEntityKind = .class
        
        let tempFolder = try createTempFolder(content: [
        Folder(name: "SingleArticleWithExternalLink.docc", content: [
            TextFile(name: "article.md", utf8Content: """
            # Article with external link
            
            @Metadata {
              @TechnologyRoot
            }
            
            Link to an external page: <doc://com.test.external/path/to/external/symbol>
            """)
            ])
        ])
        
        let workspace = DocumentationWorkspace()
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalDocumentationSources = [externalResolver.bundleIdentifier: externalResolver]
        let dataProvider = try LocalFileSystemDataProvider(rootURL: tempFolder)
        try workspace.registerProvider(dataProvider)
        let bundle = try XCTUnwrap(workspace.bundles.first?.value)
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/article", sourceLanguage: .swift))
        
        let fileURL = try XCTUnwrap(context.documentURL(for: node.reference))
        let renderNode = try converter.convert(node, at: fileURL)
        
        XCTAssertEqual(externalResolver.resolvedExternalPaths, ["/path/to/external/symbol"], "The authored link was resolved")
        
        // Verify that the article contains the external reference
        guard let symbolRenderReference = renderNode.references["doc://com.test.external/path/to/externally-resolved-symbol"] as? TopicRenderReference else {
            XCTFail("The external reference should be resolved and included among the article's references.")
            return
        }
        
        XCTAssertEqual(symbolRenderReference.identifier.identifier, "doc://com.test.external/path/to/externally-resolved-symbol")
        XCTAssertEqual(symbolRenderReference.title, "ClassName")
        XCTAssertEqual(symbolRenderReference.url, "/example/path/to/externally-resolved-symbol") // External references in topic groups use relative URLs
        XCTAssertEqual(symbolRenderReference.kind, .symbol)
        
        // Verify that the rendered abstract contains the resolved link
        if case RenderInlineContent.reference(identifier: let identifier, isActive: true, overridingTitle: _, overridingTitleInlineContent: _)? = renderNode.abstract?.last {
            XCTAssertEqual(identifier.identifier, "doc://com.test.external/path/to/externally-resolved-symbol")
        } else {
            XCTFail("Unexpected abstract content: \(renderNode.abstract ?? [])")
        }
    }
    
    func testSampleCodeReferenceHasSampleCodeRole() throws {
        let externalResolver = TestExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        externalResolver.expectedReferencePath = "/path/to/external/sample"
        externalResolver.resolvedEntityTitle = "Name of Sample"
        externalResolver.resolvedEntityKind = .sampleCode
        
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # ``SideKit/SideClass``

            Curate a sample code reference to verify the role of its render reference

            ## Topics
                
            ### External reference

            - <doc://com.test.external/path/to/external/sample>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        guard let fileURL = context.documentURL(for: node.reference) else {
            XCTFail("Unable to find the file for \(node.reference.path)")
            return
        }
        
        let renderNode = try converter.convert(node, at: fileURL)
        
        guard let sampleRenderReference = renderNode.references["doc://com.test.external/path/to/external/sample"] as? TopicRenderReference else {
            XCTFail("The external reference should be resolved and included among the SideClass symbols's references.")
            return
        }
        
        XCTAssertEqual(sampleRenderReference.identifier.identifier, "doc://com.test.external/path/to/external/sample")
        XCTAssertEqual(sampleRenderReference.title, "Name of Sample")
        XCTAssertEqual(sampleRenderReference.url, "/example/path/to/external/sample")
        XCTAssertEqual(sampleRenderReference.kind, .article) // there's no sample code _kind_, only a _role_.
        
        XCTAssertEqual(sampleRenderReference.role, RenderMetadata.Role.sampleCode.rawValue)
    }
    
    func testExternalTopicWithTopicImage() throws {
        let externalResolver = TestMultiResultExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        
        externalResolver.entitiesToReturn["/path/to/external-page-with-topic-image-1"] = .success(.init(
            referencePath: "/path/to/external-page-with-topic-image-1",
            title: "First external page with topic image",
            topicImages: [
                (TopicImage(type: .card, identifier: RenderReferenceIdentifier("external-card-1")), "First external card alt text"),
                (TopicImage(type: .icon, identifier: RenderReferenceIdentifier("external-icon-1")), "First external icon alt text"),
            ]
        ))
        externalResolver.entitiesToReturn["/path/to/external-page-with-topic-image-2"] = .success(.init(
            referencePath: "/path/to/external-page-with-topic-image-2",
            title: "Second external page with topic image",
            topicImages: [
                (TopicImage(type: .card, identifier: RenderReferenceIdentifier("external-card-2")), "Second external card alt text"),
                (TopicImage(type: .icon, identifier: RenderReferenceIdentifier("external-icon-2")), "Second external icon alt text"),
            ]
        ))
        
        let firstCardImageLightURL = try XCTUnwrap(URL(string: "https://com.test.example/first-image-name-light.jpg"))
        let firstCardImageDarkURL = try XCTUnwrap(URL(string: "https://com.test.example/first-image-name-dark.jpg"))
        
        let secondCardImageStandardURL = try XCTUnwrap(URL(string: "https://com.test.example/second-image-name-1x.jpg"))
        let secondCardImageDoubleURL = try XCTUnwrap(URL(string: "https://com.test.example/second-image-name-2x.jpg"))
        let secondCardImageTripleURL = try XCTUnwrap(URL(string: "https://com.test.example/second-image-name-3x.jpg"))
        
        externalResolver.assetsToReturn = [
            "external-card-1": DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): firstCardImageLightURL,
                    DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): firstCardImageDarkURL,
                ],
                metadata: [
                    firstCardImageLightURL: DataAsset.Metadata(svgID: nil),
                    firstCardImageDarkURL: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ),
            
            "external-card-2": DataAsset(
                variants: [
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): secondCardImageStandardURL,
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): secondCardImageDoubleURL,
                    DataTraitCollection(userInterfaceStyle: .light, displayScale: .triple): secondCardImageTripleURL,
                ],
                metadata: [
                    secondCardImageStandardURL: DataAsset.Metadata(svgID: nil),
                    secondCardImageDoubleURL: DataAsset.Metadata(svgID: nil),
                    secondCardImageTripleURL: DataAsset.Metadata(svgID: nil),
                ],
                context: .display
            ),
        ]
        
        let (_, bundle, context) = try testBundleAndContext(copying: "SampleBundle", excludingPaths: ["MySample.md", "MyLocalSample.md"], externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # SomeSample

            @Metadata {
              @TechnologyRoot
            }

            This is a great framework, I tell you what. More text

            @Options {
              @TopicsVisualStyle(compactGrid)
            }

            ## Topics

            ### Examples

            - <doc://com.test.external/path/to/external-page-with-topic-image-1>
            - <doc://com.test.external/path/to/external-page-with-topic-image-2>

            <!-- Copyright (c) 2023 Apple Inc and the Swift Project authors. All Rights Reserved. -->
            """.write(to: url.appendingPathComponent("SomeSample.md"), atomically: true, encoding: .utf8)
        }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SomeSample", sourceLanguage: .swift))
        
        guard let fileURL = context.documentURL(for: node.reference) else {
            XCTFail("Unable to find the file for \(node.reference.path)")
            return
        }
        
        let renderNode = try converter.convert(node, at: fileURL)
        
        XCTAssertEqual(context.assetManagers.keys.sorted(), ["org.swift.docc.sample"],
                       "The external bundle for the external asset shouldn't have it's own asset manager")
        
        let firstExternalRenderReference = try XCTUnwrap(renderNode.references["doc://com.test.external/path/to/external-page-with-topic-image-1"] as? TopicRenderReference)
        
        XCTAssertEqual(firstExternalRenderReference.identifier.identifier, "doc://com.test.external/path/to/external-page-with-topic-image-1")
        XCTAssertEqual(firstExternalRenderReference.title, "First external page with topic image")
        XCTAssertEqual(firstExternalRenderReference.url, "/example/path/to/external-page-with-topic-image-1")
        XCTAssertEqual(firstExternalRenderReference.kind, .article)
        
        XCTAssertEqual(firstExternalRenderReference.images, [
            TopicImage(type: .card, identifier: RenderReferenceIdentifier("external-card-1")),
            TopicImage(type: .icon, identifier: RenderReferenceIdentifier("external-icon-1")),
        ])
        
        let secondExternalRenderReference = try XCTUnwrap(renderNode.references["doc://com.test.external/path/to/external-page-with-topic-image-2"] as? TopicRenderReference)
        
        XCTAssertEqual(secondExternalRenderReference.identifier.identifier, "doc://com.test.external/path/to/external-page-with-topic-image-2")
        XCTAssertEqual(secondExternalRenderReference.title, "Second external page with topic image")
        XCTAssertEqual(secondExternalRenderReference.url, "/example/path/to/external-page-with-topic-image-2")
        XCTAssertEqual(secondExternalRenderReference.kind, .article)
        
        XCTAssertEqual(secondExternalRenderReference.images, [
            TopicImage(type: .card, identifier: RenderReferenceIdentifier("external-card-2")),
            TopicImage(type: .icon, identifier: RenderReferenceIdentifier("external-icon-2")),
        ])
        
        let imageReferences = (renderNode.assetReferences[.image] ?? [])
            .compactMap { $0 as? ImageReference }
            .sorted(by: \.identifier.identifier)
        
        XCTAssertEqual(imageReferences.map(\.identifier.identifier), ["external-card-1", "external-card-2", "external-icon-1", "external-icon-2"])
        XCTAssertEqual(imageReferences, [
            ImageReference(
                identifier: RenderReferenceIdentifier("external-card-1"),
                altText: "First external card alt text",
                imageAsset: DataAsset(
                    variants: [
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): firstCardImageLightURL,
                        DataTraitCollection(userInterfaceStyle: .dark, displayScale: .double): firstCardImageDarkURL,
                    ],
                    metadata: [
                        firstCardImageLightURL: DataAsset.Metadata(svgID: nil),
                        firstCardImageDarkURL: DataAsset.Metadata(svgID: nil),
                    ],
                    context: .display
                )
            ),
            
            ImageReference(
                identifier: RenderReferenceIdentifier("external-card-2"),
                altText: "Second external card alt text",
                imageAsset: DataAsset(
                    variants: [
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard): secondCardImageStandardURL,
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .double): secondCardImageDoubleURL,
                        DataTraitCollection(userInterfaceStyle: .light, displayScale: .triple): secondCardImageTripleURL,
                    ],
                    metadata: [
                        secondCardImageStandardURL: DataAsset.Metadata(svgID: nil),
                        secondCardImageDoubleURL: DataAsset.Metadata(svgID: nil),
                        secondCardImageTripleURL: DataAsset.Metadata(svgID: nil),
                    ],
                    context: .display
                )
            ),
            
            ImageReference(
                identifier: RenderReferenceIdentifier("external-icon-1"),
                altText: "First external icon alt text",
                imageAsset: DataAsset() // this image reference didn't have an asset in the test setup
            ),
            
            ImageReference(
                identifier: RenderReferenceIdentifier("external-icon-2"),
                altText: "Second external icon alt text",
                imageAsset: DataAsset() // this image reference didn't have an asset in the test setup
            )
        ])
    }
    
    // Tests that external references are included in task groups, rdar://72119391
    func testResolveExternalReferenceInTaskGroups() throws {
        // Copy the test bundle and add external links to the MyKit Topics.
        let workspace = DocumentationWorkspace()
        let (tempURL, _, _) = try testBundleAndContext(copying: "TestBundle")
        
        try """
        # ``MyKit``
        MyKit module root symbol
        ## Topics
        ### Task Group
         - <doc:article>
         - <doc:article2>
         - <doc://com.external.testbundle/article>
         - <doc://com.external.testbundle/article2>
        """.write(to: tempURL.appendingPathComponent("documentation").appendingPathComponent("mykit.md"), atomically: true, encoding: .utf8)
        
        // Load the new test bundle
        let dataProvider = try LocalFileSystemDataProvider(rootURL: tempURL)
        guard let bundle = try dataProvider.bundles().first else {
            XCTFail("Failed to create a temporary test bundle")
            return
        }
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        
        // Add external resolver
        context.externalDocumentationSources = ["com.external.testbundle" : TestExternalReferenceResolver()]
        
        // Get MyKit symbol
        let entity = try context.entity(with: .init(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        let taskGroupLinks = try XCTUnwrap((entity.semantic as? Symbol)?.topics?.taskGroups.first?.links.compactMap({ $0.destination }))
        
        // Verify the task group links have been resolved and are still present in the link list.
        XCTAssertEqual(taskGroupLinks, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
            "doc://com.external.testbundle/article",
            "doc://com.external.testbundle/article2",
        ])
    }
    
    // Tests that external references are resolved in tutorial content
    func testResolveExternalReferenceInTutorials() throws {
        let resolver = TestExternalReferenceResolver()
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.bundle": resolver, "com.external.testbundle": resolver], configureBundle: { (bundleURL) in
            // Replace TestTutorial.tutorial with a copy that includes a bunch of external links
            try FileManager.default.removeItem(at: bundleURL.appendingPathComponent("TestTutorial.tutorial"))
            try FileManager.default.copyItem(
                at: Bundle.module.url(forResource: "TestTutorial-ExternalLinks", withExtension: "tutorial", subdirectory: "Test Resources")!,
                to: bundleURL.appendingPathComponent("TestTutorial.tutorial")
            )
            
            // Replace TestOverview.tutorial with a copy that includes a bunch of external links
            try FileManager.default.removeItem(at: bundleURL.appendingPathComponent("TestOverview.tutorial"))
            try FileManager.default.copyItem(
                at: Bundle.module.url(forResource: "TestOverview-ExternalLinks", withExtension: "tutorial", subdirectory: "Test Resources")!,
                to: bundleURL.appendingPathComponent("TestOverview.tutorial")
            )
        })

        // Verify the external symbol is included in external cache
        let reference = ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/externally/resolved/path", sourceLanguage: .swift)
        XCTAssertNil(context.documentationCache[reference])
        XCTAssertNotNil(context.externalCache[reference])
        
        // Verify that all external links from various directives have been visited.
        XCTAssertEqual(resolver.resolvedExternalPaths.sorted(), [
            "/LinkFromAbstract",
            "/LinkFromChapter",
            "/LinkFromChoice",
            "/LinkFromContentAndMedia",
            "/LinkFromJustification",
            "/LinkFromMulitpleChoice",
            "/LinkFromNote",
            "/LinkFromResourceDocumentation",
            "/LinkFromResourceForums",
            "/LinkFromResourceSampleCode",
            "/LinkFromResourceVideos",
            "/LinkFromStep",
            "/LinkFromTechnologyIntro",
            "/externally/resolved/path",
        ])
        
        // Verify the link in a comment directive hasn't been visited.
        XCTAssertFalse(resolver.resolvedExternalPaths.contains("/LinkFromComment"))
    }
    
    // Tests that external references are included in task groups, rdar://72119391
    func testExternalResolverIsNotPassedReferencesItDidNotResolve() throws {
        final class CallCountingReferenceResolver: ExternalDocumentationSource {
            var referencesAskedToResolve: Set<TopicReference> = []
            
            var referencesCreatingEntityFor: Set<ResolvedTopicReference> = []
            
            func resolve(_ reference: TopicReference) -> TopicReferenceResolutionResult {
                referencesAskedToResolve.insert(reference)
                
                // Only resolve a specific, known reference
                guard reference.description == "doc://com.external.testbundle/resolvable" else {
                    switch reference {
                    case .unresolved(let unresolved):
                        return .failure(unresolved, TopicReferenceResolutionErrorInfo("Unit test: External resolve error."))
                    case .resolved(let resolvedResult):
                        return resolvedResult
                    }
                }
                // Note that this resolved reference doesn't have the same path as the unresolved reference.
                return .success(.init(bundleIdentifier: "com.external.testbundle", path: "/resolved", sourceLanguage: .swift))
            }
            
            func entity(with reference: ResolvedTopicReference) -> LinkResolver.ExternalEntity {
                referencesCreatingEntityFor.insert(reference)
                
                // Return an empty node
                return .init(
                    topicRenderReference: TopicRenderReference(
                        identifier: .init(reference.absoluteString),
                        title: "Resolved",
                        abstract: [],
                        url: reference.absoluteString,
                        kind: .symbol,
                        estimatedTime: nil
                    ),
                    renderReferenceDependencies: RenderReferenceDependencies(),
                    sourceLanguages: [.swift]
                )
            }
        }
        
        let resolver = CallCountingReferenceResolver()

        // Copy the test bundle and add external links to the MyKit See Also.
        // We're using a See Also group, because external links aren't rendered in Topics groups.
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.testbundle" : resolver]) { url in
            try """
            # ``MyKit``
            MyKit module root symbol <doc://com.external.testbundle/not-resolvable-2>
            ## Topics
            ### Basics
             - <doc:article>
             - <doc:article2>
            ## See Also
             - <doc:article>
             - <doc:article2>
             - <doc://com.external.testbundle/resolvable>
             - <doc://com.external.testbundle/not-resolvable-1>
             - <doc://com.external.other-test-bundle/article>
            """.write(to: url.appendingPathComponent("documentation").appendingPathComponent("mykit.md"), atomically: true, encoding: .utf8)
        }
        
        // Verify the external link has been collected and pre-resolved.
        XCTAssertEqual(context.externallyResolvedLinks.keys.map({ $0.absoluteString }).sorted(), [
            "doc://com.external.testbundle/not-resolvable-1", // expected failure
            "doc://com.external.testbundle/not-resolvable-2", // expected failure
            "doc://com.external.testbundle/resolvable", // expected success
            "doc://com.external.testbundle/resolved" // the successfully resolved reference has a different reference which should also be collected.
        ], "Results for both failed and successfully resolved external references should be collected.")
        
        XCTAssertNil(context.externallyResolvedLinks[ValidatedURL(parsingExact: "doc://com.external.other-test-bundle/article")!],
                     "External references without a registered external resolver should not be collected.")
        
        // Expected failed externally resolved reference.
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL(parsingExact: "doc://com.external.testbundle/not-resolvable-1")!],
            TopicReferenceResolutionResult.failure(UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.external.testbundle/not-resolvable-1")!), TopicReferenceResolutionErrorInfo("Unit test: External resolve error."))
        )
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL(parsingExact: "doc://com.external.testbundle/not-resolvable-2")!],
            TopicReferenceResolutionResult.failure(UnresolvedTopicReference(topicURL: ValidatedURL(parsingExact: "doc://com.external.testbundle/not-resolvable-2")!), TopicReferenceResolutionErrorInfo("Unit test: External resolve error."))
        )
        
        // Expected successful externally resolved reference.
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL(parsingExact: "doc://com.external.testbundle/resolvable")!],
            TopicReferenceResolutionResult.success(ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/resolved", fragment: nil, sourceLanguage: .swift))
        )
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL(parsingExact: "doc://com.external.testbundle/resolved")!],
            TopicReferenceResolutionResult.success(ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/resolved", fragment: nil, sourceLanguage: .swift))
        )
        
        XCTAssert(context.problems.contains(where: { $0.diagnostic.summary.contains("Unit test: External resolve error.")}),
                  "The external reference resolver error message is included in that problem's error summary.")
        
        // Get MyKit symbol
        let entity = try context.entity(with: .init(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = try converter.convert(entity, at: nil)
        
        let taskGroupLinks = try XCTUnwrap(renderNode.seeAlsoSections.first?.identifiers)
        // Verify the unresolved links are not included in the task group.
        XCTAssertEqual(taskGroupLinks.sorted(), [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
            "doc://com.external.testbundle/resolved",
        ].sorted())
        
        // Verify that the resolver was asked to resolve all references that match its bundle identifier.
        XCTAssertEqual(resolver.referencesAskedToResolve.map({ $0.description }).sorted(), [
            "doc://com.external.testbundle/not-resolvable-1",
            "doc://com.external.testbundle/not-resolvable-2",
            "doc://com.external.testbundle/resolvable", // Note that this is the reference in the content.
        ])
        // Verify that the resolver wasn't passed references it didn't resolve.
        XCTAssertEqual(resolver.referencesCreatingEntityFor.map({ $0.description }).sorted(), [
            "doc://com.external.testbundle/resolved", // Note that this is the resolved reference, not the one from the content.
        ])
    }
    
    /// Tests that the external resolving handles correctly fragments in URLs.
    func testExternalReferenceWithFragment() throws {
        // Configure an external resolver
        let resolver = TestExternalReferenceResolver()
        
        // Intentionally return different fragment than the link's to verify we don't rely
        // on the original link's destination text.
        resolver.expectedFragment = "67890"
        
        // Prepare a test bundle
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.testbundle" : resolver], externalSymbolResolver: nil, configureBundle: { url in
            // Add external link with fragment
            let myClassMDURL = url.appendingPathComponent("documentation").appendingPathComponent("myclass.md")
            try String(contentsOf: myClassMDURL)
                .replacingOccurrences(of: "MyClass abstract.", with: "MyClass uses a <doc://com.external.testbundle/article#12345>.")
                .write(to: myClassMDURL, atomically: true, encoding: .utf8)
        })

        let myClassRef = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let documentationNode = try context.entity(with: myClassRef)
        
        // Verify the external link was resolved in markup.
        let abstractParagraph = try XCTUnwrap((documentationNode.semantic as? Symbol)?.abstract)
        let markdownLink = try XCTUnwrap(abstractParagraph.children.mapFirst { markup -> String? in
            return (markup as? Link)?.destination
        })
        XCTAssertEqual(markdownLink, "doc://com.external.testbundle/externally/resolved/path#67890")

        // Verify that the external link was stored in the context.
        let linkURL = try XCTUnwrap(ValidatedURL(parsingExact: markdownLink))
        guard case .success(let linkReference) = try XCTUnwrap(context.externallyResolvedLinks[linkURL]) else {
            XCTFail("Unexpected failed external reference.")
            return
        }
        XCTAssertEqual(linkReference.absoluteString, "doc://com.external.testbundle/externally/resolved/path#67890")
    }
    
    func testExternalArticlesAreIncludedInAllVariantsTopicsSection() throws {
        let externalResolver = TestMultiResultExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        
        externalResolver.entitiesToReturn["/path/to/external/swiftArticle"] = .success(
            .init(
                    referencePath: "/path/to/external/swiftArticle",
                    title: "SwiftArticle",
                    kind: .article,
                    language: .swift
                )
        )
        
        externalResolver.entitiesToReturn["/path/to/external/objCArticle"] = .success(
            .init(
                    referencePath: "/path/to/external/objCArticle",
                    title: "ObjCArticle",
                    kind: .article,
                    language: .objectiveC
                )
        )
        
        externalResolver.entitiesToReturn["/path/to/external/swiftSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/swiftSymbol",
                title: "SwiftSymbol",
                kind: .class,
                language: .swift
            )
        )
                
        externalResolver.entitiesToReturn["/path/to/external/objCSymbol"] = .success(
            .init(
                referencePath: "/path/to/external/objCSymbol",
                title: "ObjCSymbol",
                kind: .class,
                language: .objectiveC
            )
        )
        
        let (_, bundle, context) = try testBundleAndContext(
            copying: "MixedLanguageFramework",
            externalResolvers: [externalResolver.bundleIdentifier: externalResolver]
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
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let mixedLanguageFrameworkReference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/MixedLanguageFramework",
            sourceLanguage: .swift
        )
        let node = try context.entity(with: mixedLanguageFrameworkReference)
        let fileURL = try XCTUnwrap(context.documentURL(for: node.reference))
        let renderNode = try converter.convert(node, at: fileURL)
        // Topic identifiers in the Swift variant of the `MixedLanguageFramework` symbol
        let swiftTopicIDs = renderNode.topicSections.flatMap(\.identifiers)
        
        let data = try renderNode.encodeToJSON()
        let variantRenderNode = try RenderNodeVariantOverridesApplier()
            .applyVariantOverrides(in: data, for: [.interfaceLanguage("occ")])
        let objCRenderNode = try RenderJSONDecoder.makeDecoder().decode(RenderNode.self, from: variantRenderNode)
        // Topic identifiers in the ObjC variant of the `MixedLanguageFramework` symbol
        let objCTopicIDs = objCRenderNode.topicSections.flatMap(\.identifiers)
        
        // Verify that external articles are included in the Topics section of both symbol
        // variants regardless of their perceived language.
        XCTAssertTrue(swiftTopicIDs.contains("doc://com.test.external/path/to/external/swiftArticle"))
        XCTAssertTrue(swiftTopicIDs.contains("doc://com.test.external/path/to/external/objCArticle"))
        XCTAssertTrue(objCTopicIDs.contains("doc://com.test.external/path/to/external/swiftArticle"))
        XCTAssertTrue(objCTopicIDs.contains("doc://com.test.external/path/to/external/objCArticle"))
        // Verify that external language specific symbols are dropped from the Topics section in the
        // variants for languages where the symbol isn't available.
        XCTAssertFalse(swiftTopicIDs.contains("doc://com.test.external/path/to/external/objCSymbol"))
        XCTAssertTrue(swiftTopicIDs.contains("doc://com.test.external/path/to/external/swiftSymbol"))
        XCTAssertTrue(objCTopicIDs.contains("doc://com.test.external/path/to/external/objCSymbol"))
        XCTAssertFalse(objCTopicIDs.contains("doc://com.test.external/path/to/external/swiftSymbol"))
    }
    
    func testDeprecationSummaryWithExternalLink() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                        names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["SymbolName"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                        mixins: [:]
                    )
                ]
            )),
            
            TextFile(name: "Extension.md", utf8Content: """
            # ``SymbolName``
            
            @DeprecationSummary {
              Use <doc://com.external.testbundle/something> instead.
            }
            
            Link to external content in a symbol deprecation message.
            """),
            
            TextFile(name: "Article.md", utf8Content: """
            # Article
            
            @DeprecationSummary {
              Use <doc://com.external.testbundle/something-else> instead.
            }
            
            Link to external content in an article deprecation message.
            """),
        ])
        
        let resolver = TestExternalReferenceResolver()
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL, externalResolvers: [resolver.bundleIdentifier: resolver])
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems:\n\(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))")
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/ModuleName/SymbolName", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            let deprecatedSection = try XCTUnwrap((node.semantic as? Symbol)?.deprecatedSummary)
            XCTAssertEqual(deprecatedSection.content.count, 1)
            XCTAssertEqual(deprecatedSection.content.first?.format().trimmingCharacters(in: .whitespaces), "Use <doc://com.external.testbundle/externally/resolved/path> instead.", "The link should have been resolved")
        }
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/unit-test/Article", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            let deprecatedSection = try XCTUnwrap((node.semantic as? Article)?.deprecationSummary)
            XCTAssertEqual(deprecatedSection.count, 1)
            XCTAssertEqual(deprecatedSection.first?.format().trimmingCharacters(in: .whitespaces), "Use <doc://com.external.testbundle/externally/resolved/path> instead.", "The link should have been resolved")
        }
    }
    
    func testExternalLinkInGeneratedSeeAlso() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: """
            # Root
            
            @Metadata {
              @TechnologyRoot
            }
            
            Curate two local articles and one external link
            
            ## Topics
            
            - <doc:First>
            - <doc://com.external.testbundle/something>
            - <doc:Second>
            """),
            
            TextFile(name: "First.md", utf8Content: """
            # First
            
            One article.
            """),
            TextFile(name: "Second.md", utf8Content: """
            # Second
            
            Another article.
            """),
        ])
        
        let resolver = TestExternalReferenceResolver()
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL, externalResolvers: [resolver.bundleIdentifier: resolver])
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Check the curation on the root page
        let rootNode = try context.entity(with: XCTUnwrap(context.soleRootModuleReference))
        let topics = try XCTUnwrap((rootNode.semantic as? Article)?.topics)
        XCTAssertEqual(topics.taskGroups.count, 1, "The Root page should only have one task group because all the other pages are curated in one group so there are no automatic groups.")
        let taskGroup = try XCTUnwrap(topics.taskGroups.first)
        XCTAssertEqual(taskGroup.links.map(\.destination), [
            "doc://unit-test/documentation/unit-test/First",
            "doc://com.external.testbundle/externally/resolved/path",
            "doc://unit-test/documentation/unit-test/Second",
        ])
        
        // Check the rendered SeeAlso sections for the two curated articles.
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/unit-test/First", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let rendered = try converter.convert(node, at: nil)
            
            XCTAssertEqual(rendered.seeAlsoSections.count, 1, "The page should only have the automatic See Also section created based on the curation on the Root page.")
            let seeAlso = try XCTUnwrap(rendered.seeAlsoSections.first)
            
            XCTAssertEqual(seeAlso.identifiers, [
                "doc://com.external.testbundle/externally/resolved/path",
                "doc://unit-test/documentation/unit-test/Second",
            ])
        }
        
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/unit-test/Second", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            let rendered = try converter.convert(node, at: nil)
            
            XCTAssertEqual(rendered.seeAlsoSections.count, 1, "The page should only have the automatic See Also section created based on the curation on the Root page.")
            let seeAlso = try XCTUnwrap(rendered.seeAlsoSections.first)
            
            XCTAssertEqual(seeAlso.identifiers, [
                "doc://unit-test/documentation/unit-test/First",
                "doc://com.external.testbundle/externally/resolved/path",
            ])
        }
    }
    
    func testExternalLinkInAuthoredSeeAlso() throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: [
            TextFile(name: "Root.md", utf8Content: """
            # Root
            
            @Metadata {
              @TechnologyRoot
            }
            
            An external link in an authored SeeAlso section
            
            ## See Also
            
            - <doc://com.external.testbundle/something>
            """),
        ])
        
        let resolver = TestExternalReferenceResolver()
        
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL, externalResolvers: [resolver.bundleIdentifier: resolver])
        
        XCTAssert(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        
        // Check the curation on the root page
        let reference = try XCTUnwrap(context.soleRootModuleReference)
        let node = try context.entity(with: reference)
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let rendered = try converter.convert(node, at: nil)
        
        XCTAssertEqual(rendered.seeAlsoSections.count, 1, "The page should only have the authored See Also section.")
        let seeAlso = try XCTUnwrap(rendered.seeAlsoSections.first)
        
        XCTAssertEqual(seeAlso.identifiers, [
            "doc://com.external.testbundle/externally/resolved/path",
        ])
    }

    func assertMarkupHasResolvedLink(markupsWithResolvedLink: [String], actualMarkup: [Markup]) throws {
        let value: String = try XCTUnwrap(actualMarkup.first?.format().trimmingCharacters(in: .whitespaces))
        XCTAssert(
            markupsWithResolvedLink.contains(value),
            "Markup does not have resolved link\nActual markdown: \(value)\nExpected markdown options:\n\(markupsWithResolvedLink.joined(separator: "\n"))"
        )
    }

    func withExampleDocumentation(_ files: [any File], path: String, block: (Symbol) throws -> Void) throws {
        let exampleDocumentation = Folder(name: "unit-test.docc", content: files)

        let resolver = TestExternalReferenceResolver()

        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL, externalResolvers: [resolver.bundleIdentifier: resolver])
        XCTAssert(context.problems.isEmpty, "Unexpected problems:\n\(context.problems.map(\.diagnostic.summary).joined(separator: "\n"))")

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: path, sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        try block(symbol)
    }

    func withExampleSymbolDocumentation(_ files: File..., block: (Symbol) throws -> Void) throws {
        let symbolGraph = JSONFile(
            name: "ModuleName.symbols.json",
            content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    SymbolGraph.Symbol(
                        identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                        names: .init(title: "SymbolName", navigator: nil, subHeading: nil, prose: nil),
                        pathComponents: ["SymbolName"],
                        docComment: nil,
                        accessLevel: .public,
                        kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                        mixins: [:]
                    )
                ]
            )
        )
        try withExampleDocumentation(
            [symbolGraph] + files,
            path: "/documentation/ModuleName/SymbolName",
            block: block
        )
    }

    func testParametersWithExternalLink() throws {
        try withExampleSymbolDocumentation(
            TextFile(name: "Extension.md", utf8Content: """
            # ``SymbolName``

            This is about some symbol.

            - Parameters:
              - one: The first parameter has a link: <doc://com.external.testbundle/something/related/to/this/param>.
              - two: The second parameter also has a link: <doc://com.external.testbundle/something/related/to/this/param>.

            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = [
                "The first parameter has a link: <doc://com.external.testbundle/externally/resolved/path>.",
                "The second parameter also has a link: <doc://com.external.testbundle/externally/resolved/path>."
            ]
            let parametersSection = try XCTUnwrap(symbol.parametersSection)
            XCTAssertEqual(parametersSection.parameters.count, 2)
            try parametersSection.parameters.forEach {
                try assertMarkupHasResolvedLink(markupsWithResolvedLink: expectedMarkupsWithResolvedLink, actualMarkup: $0.contents)
            }
        }
    }

    func testDictionaryKeysWithExternalLink() throws {
        try withExampleSymbolDocumentation(
            TextFile(name: "Extension.md", utf8Content: """
            # ``SymbolName``

            This is about some symbol.

            - DictionaryKeys:
              - key1: The first key has a link: <doc://com.external.testbundle/something/related/to/this/key>.
              - key2: The second key also has a link: <doc://com.external.testbundle/something/related/to/this/key>.

            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = [
                "The first key has a link: <doc://com.external.testbundle/externally/resolved/path>.",
                "The second key also has a link: <doc://com.external.testbundle/externally/resolved/path>."
            ]
            let dictionaryKeySection = try XCTUnwrap(symbol.dictionaryKeysSection)
            XCTAssertEqual(dictionaryKeySection.dictionaryKeys.count, 2)
            try dictionaryKeySection.dictionaryKeys.forEach {
                try assertMarkupHasResolvedLink(markupsWithResolvedLink: expectedMarkupsWithResolvedLink, actualMarkup: $0.contents)
            }
        }
    }

    func withExampleRESTAPIDocumentation(_ files: File..., block: (Symbol) throws -> Void) throws {
        let symbolGraph = JSONFile(name: "SomeRestAPI.symbols.json", content: makeSymbolGraph(
            moduleName: "SomeRestAPI",
            symbols: [
                SymbolGraph.Symbol(
                    identifier: .init(
                        precise: "rest:some_api:get:some_data",
                        interfaceLanguage: "data"
                    ),
                    names: .init(
                        title: "Some Data",
                        navigator: .init(
                            [
                                .init(
                                    kind: .init(rawValue: "identifier")!,
                                    spelling: "Some Data",
                                    preciseIdentifier: nil
                                )
                            ]
                        ),
                        subHeading: nil,
                        prose: nil
                    ),
                    pathComponents: ["Some-Data"],
                    docComment: nil,
                    accessLevel: .public,
                    kind: .init(parsedIdentifier: .httpRequest, displayName: "Web Endpoint"),
                    mixins: [:]
                )
            ]
        ))
        try withExampleDocumentation(
            [symbolGraph] + files,
            path: "/documentation/SomeRestAPI/Some-Data",
            block: block
        )
    }

    func testHTTPParametersWithExternalLink() throws {
        try withExampleRESTAPIDocumentation(
            TextFile(name: "Some-Data.md", utf8Content: """
            # ``Some-Data``

            Retrieve some data from our database.

            - HTTPParameters:
              - value: For more information about this value, see <doc://com.external.testbundle/something> instead.
              - another_value: For more information about this other value, see <doc://com.external.testbundle/other> instead.
            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = [
                "For more information about this value, see <doc://com.external.testbundle/externally/resolved/path> instead.",
                "For more information about this other value, see <doc://com.external.testbundle/externally/resolved/path> instead."
            ]
            let httpParametersSection = try XCTUnwrap(symbol.httpParametersSection)
            XCTAssertEqual(httpParametersSection.parameters.count, 2)
            try httpParametersSection.parameters.forEach {
                try assertMarkupHasResolvedLink(markupsWithResolvedLink: expectedMarkupsWithResolvedLink, actualMarkup: $0.contents)
            }
        }
    }

    func testHTTPBodyWithExternalLink() throws {
        try withExampleRESTAPIDocumentation(
            TextFile(name: "Some-Data.md", utf8Content: """
            # ``Some-Data``

            Retrieve some data from our database.

            - HTTPBody: Read this instead: <doc://com.external.testbundle/something-else>.

            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = "Read this instead: <doc://com.external.testbundle/externally/resolved/path>."
            let httpBodySection = try XCTUnwrap(symbol.httpBodySection)
            try assertMarkupHasResolvedLink(markupsWithResolvedLink: [expectedMarkupsWithResolvedLink], actualMarkup: httpBodySection.body.contents)
        }
    }

    func testHTTPBodyParametersWithExternalLink() throws {
        try withExampleRESTAPIDocumentation(
            TextFile(name: "Some-Data.md", utf8Content: """
            # ``Some-Data``

            Retrieve some data from our database.

            - HTTPBodyParameters:
                - artist: Read more about artists: <doc://com.external.testbundle/artists>.
                - userName: Read more about user names: <doc://com.external.testbundle/user-names>.

            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = [
                "Read more about artists: <doc://com.external.testbundle/externally/resolved/path>.",
                "Read more about user names: <doc://com.external.testbundle/externally/resolved/path>."
            ]
            let httpBodySection = try XCTUnwrap(symbol.httpBodySection)
            XCTAssertEqual(httpBodySection.body.parameters.count, 2)
            try httpBodySection.body.parameters.forEach {
                try assertMarkupHasResolvedLink(markupsWithResolvedLink: expectedMarkupsWithResolvedLink, actualMarkup: $0.contents)
            }
        }
    }

    func testHTTPResponsesWithExternalLink() throws {
        try withExampleRESTAPIDocumentation(
            TextFile(name: "Some-Data.md", utf8Content: """
            # ``Some-Data``

            Retrieve some data from our database.

            - HTTPResponses:
              - 201: More information here: <doc://com.external.testbundle/more-info>.
              - 204: Even more information here: <doc://com.external.testbundle/more-info2>.
              - 887: Much more information here: <doc://com.external.testbundle/more-info3>.

            """)
        ) { symbol in
            let expectedMarkupsWithResolvedLink = [
                "More information here: <doc://com.external.testbundle/externally/resolved/path>.",
                "Even more information here: <doc://com.external.testbundle/externally/resolved/path>.",
                "Much more information here: <doc://com.external.testbundle/externally/resolved/path>."
            ]
            let httpResponsesSection = try XCTUnwrap(symbol.httpResponsesSection)
            try httpResponsesSection.responses.forEach {
                try assertMarkupHasResolvedLink(markupsWithResolvedLink: expectedMarkupsWithResolvedLink, actualMarkup: $0.contents)
            }
        }
    }
}
