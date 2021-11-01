/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown
import SymbolKit

class ExternalReferenceResolverTests: XCTestCase {
    class TestExternalReferenceResolver: ExternalReferenceResolver, FallbackReferenceResolver {
        var bundleIdentifier = "com.external.testbundle"
        var expectedReferencePath = "/externally/resolved/path"
        var expectedFragment: String? = nil
        var resolvedEntityTitle = "Externally Resolved Title"
        var resolvedEntityKind = DocumentationNode.Kind.article
        var resolvedEntityDeclarationFragments: SymbolGraph.Symbol.DeclarationFragments? = nil
        
        enum Error: Swift.Error {
            case testErrorRaisedForWrongBundleIdentifier
        }
        
        var resolvedExternalPaths = [String]()
        
        func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
            if let path = reference.url?.path {
                resolvedExternalPaths.append(path)
            }
            return .success(ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: expectedReferencePath, fragment: expectedFragment, sourceLanguage: .swift))
        }
        
        func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
            guard reference.bundleIdentifier == bundleIdentifier else {
                throw Error.testErrorRaisedForWrongBundleIdentifier
            }
            
            let semantic: Semantic?
            if let declaration = resolvedEntityDeclarationFragments {
                semantic = Symbol(
                    kind: OutOfProcessReferenceResolver.symbolKind(forNodeKind: resolvedEntityKind),
                    title: resolvedEntityTitle,
                    subHeading: declaration.declarationFragments,
                    navigator: nil,
                    roleHeading: "", // This information isn't used anywhere.
                    platformName: nil,
                    moduleName: "", // This information isn't used anywhere.
                    externalID: nil,
                    accessLevel: nil,
                    availability: nil,
                    deprecatedSummary: nil,
                    mixins: nil,
                    abstractSection: nil,
                    discussion: nil,
                    topics: nil,
                    seeAlso: nil,
                    returnsSection: nil,
                    parametersSection: nil,
                    redirects: nil
                )
            } else {
                semantic = nil
            }
            
            return DocumentationNode(
                reference: reference,
                kind: resolvedEntityKind,
                sourceLanguage: .swift,
                name: .conceptual(title: resolvedEntityTitle),
                markup: Document(parsing: "Externally Resolved Markup Content", options: [.parseBlockDirectives, .parseSymbolLinks]),
                semantic: semantic
            )
        }
        
        let testBaseURL: String = "https://example.com/example"
        func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
            let fragment = expectedFragment.map {"#\($0)"} ?? ""
            return URL(string: "\(testBaseURL)\(reference.path)\(fragment)")!
        }
        
        func entityIfPreviouslyResolved(with reference: ResolvedTopicReference) throws -> DocumentationNode? {
            hasResolvedReference(reference) ? try entity(with: reference) : nil
        }
        
        func urlForResolvedReferenceIfPreviouslyResolved(_ reference: ResolvedTopicReference) -> URL? {
            hasResolvedReference(reference) ? urlForResolvedReference(reference) : nil
        }
        
        func hasResolvedReference(_ reference: ResolvedTopicReference) -> Bool {
            true
        }
    }
    
    func testResolveExternalReference() throws {
        let sourceURL = Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        
        // Create a copy of the test bundle
        let bundleURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(ProcessInfo.processInfo.globallyUniqueString.appending(".docc"))
        try FileManager.default.copyItem(at: sourceURL, to: bundleURL)
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
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
        context.externalReferenceResolvers = ["com.external.testbundle" : TestExternalReferenceResolver()]

        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)

        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL("doc://com.external.testbundle/article")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyClass", sourceLanguage: .swift)

        guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Couldn't resolve \(unresolved)")
            return
        }
        
        XCTAssertEqual("com.external.testbundle", resolved.bundleIdentifier)
        XCTAssertEqual("/externally/resolved/path", resolved.path)
        
        let expectedURL = URL(string: "doc://com.external.testbundle/externally/resolved/path")
        XCTAssertEqual(expectedURL, resolved.url)
        
        try workspace.unregisterProvider(dataProvider)
        context.externalReferenceResolvers = [:]
        guard case .failure = context.resolve(.unresolved(unresolved), in: parent) else {
            XCTFail("Unexpectedly resolved \(unresolved.topicURL) despite removing a data provider for it")
            return
        }
    }
    
    func testResolvesReferencesExternallyOnlyWhenFallbackResolversAreSet() throws {
        let workspace = DocumentationWorkspace()
        let bundle = testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        let bundleIdentifier = bundle.identifier
        
        let unresolved = UnresolvedTopicReference(topicURL: ValidatedURL("doc://\(bundleIdentifier)/ArticleThatDoesNotExistInLocally")!)
        let parent = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "", sourceLanguage: .swift)
        
        do {
            context.externalReferenceResolvers = [:]
            context.fallbackReferenceResolvers = [:]
            
            if case .success = context.resolve(.unresolved(unresolved), in: parent) {
                XCTFail("The reference was unexpectedly resolved.")
            }
        }
        
        do {
            context.externalReferenceResolvers = [:]
            context.fallbackReferenceResolvers = [bundleIdentifier : TestExternalReferenceResolver()]
            
            guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: parent) else {
                XCTFail("The reference was unexpectedly unresolved.")
                return
            }
            
            XCTAssertEqual("com.external.testbundle", resolved.bundleIdentifier)
            XCTAssertEqual("/externally/resolved/path", resolved.path)
            
            let expectedURL = URL(string: "doc://com.external.testbundle/externally/resolved/path")
            XCTAssertEqual(expectedURL, resolved.url)
            
            try workspace.unregisterProvider(dataProvider)
            context.externalReferenceResolvers = [:]
            guard case .failure = context.resolve(.unresolved(unresolved), in: parent) else {
                XCTFail("Unexpectedly resolved \(unresolved.topicURL) despite removing a data provider for it")
                return
            }
        }
    }
    
    func testLoadEntityForExternalReference() throws {
        let workspace = DocumentationWorkspace()
        let bundle = testBundle(named: "TestBundle")
        let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
        try workspace.registerProvider(dataProvider)
        let context = try DocumentationContext(dataProvider: workspace)
        context.externalReferenceResolvers = ["com.external.testbundle" : TestExternalReferenceResolver()]
        
        let identifier = ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/externally/resolved/path", sourceLanguage: .swift)
        
        XCTAssertThrowsError(try context.entity(with: ResolvedTopicReference(bundleIdentifier: "some.other.bundle", path: identifier.path, sourceLanguage: .swift)))
        
        let node = try context.entity(with: identifier)
        
        let expectedDump = """
Document @1:1-1:35
└─ Paragraph @1:1-1:35
   └─ Text @1:1-1:35 "Externally Resolved Markup Content"
"""
        XCTAssertEqual(expectedDump, node.markup.debugDescription(options: .printSourceLocations))
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
            (.object, .symbol)
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
            context.externalReferenceResolvers = [externalResolver.bundleIdentifier: externalResolver]
            
            let bundle = testBundle(named: "TestBundle")
            
            let dataProvider = PrebuiltLocalFileSystemDataProvider(bundles: [bundle])
            try workspace.registerProvider(dataProvider)
            
            let converter = DocumentationNodeConverter(bundle: bundle, context: context)
            let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/tutorials/Test-Bundle/TestTutorial", sourceLanguage: .swift))
            
            guard let fileURL = context.fileURL(for: node.reference) else {
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
            .init(kind: .identifier, spelling: "ClassName", preciseIdentifier: nil)
        ])
        
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # ``SideKit/SideClass``

            Curate some of the children and leave the rest for automatic curation.

            ## Topics
                
            ### External reference

            - <doc://com.test.external/path/to/external/symbol>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        guard let fileURL = context.fileURL(for: node.reference) else {
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
            .init(text: "ClassName", kind: .identifier)
        ])
    }
    
    func testSampleCodeReferenceHasSampleCodeRole() throws {
        let externalResolver = TestExternalReferenceResolver()
        externalResolver.bundleIdentifier = "com.test.external"
        externalResolver.expectedReferencePath = "/path/to/external/sample"
        externalResolver.resolvedEntityTitle = "Name of Sample"
        externalResolver.resolvedEntityKind = .sampleCode
        
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: [externalResolver.bundleIdentifier: externalResolver]) { url in
            try """
            # ``SideKit/SideClass``

            Curate a sample code reference to verify the role of its render reference

            ## Topics
                
            ### External reference

            - <doc://com.test.external/path/to/external/sample>
            """.write(to: url.appendingPathComponent("documentation/sideclass.md"), atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: url) }
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift))
        
        guard let fileURL = context.fileURL(for: node.reference) else {
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
    
    // Tests that external references are included in task groups, rdar://72119391
    func testResolveExternalReferenceInTaskGroups() throws {
        // Copy the test bundle and add external links to the MyKit Topics.
        let workspace = DocumentationWorkspace()
        let (tempURL, _, _) = try testBundleAndContext(copying: "TestBundle")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
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
        context.externalReferenceResolvers = ["com.external.testbundle" : TestExternalReferenceResolver()]
        
        // Get MyKit symbol
        let entity = try context.entity(with: .init(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit", sourceLanguage: .swift))
        let taskGroupLinks = try XCTUnwrap((entity.semantic as? Symbol)?.topics?.taskGroups.first?.links.compactMap({ $0.destination }))
        
        // Verify the task group links have been resolved and are still present in the link list.
        XCTAssertEqual(taskGroupLinks, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
            "doc://com.external.testbundle/article",
            "doc://com.external.testbundle/article2"
        ])
    }
    
    // Tests that external references are resolved in tutorial content
    func testResolveExternalReferenceInTutorials() throws {
        let resolver = TestExternalReferenceResolver()
        let (tempURL, _, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.bundle": resolver, "com.external.testbundle": resolver], configureBundle: { (bundleURL) in
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
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Verify the external symbol is included in cache
        XCTAssertNotNil(context.documentationCache[.init(bundleIdentifier: "com.external.testbundle", path: "/externally/resolved/path", sourceLanguage: .swift)])
        
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
            "/externally/resolved/path"
        ])
        
        // Verify the link in a comment directive hasn't been visited.
        XCTAssertFalse(resolver.resolvedExternalPaths.contains("/LinkFromComment"))
    }
    
    // Tests that external references are included in task groups, rdar://72119391
    func testExternalResolverIsNotPassedReferencesItDidNotResolve() throws {
        final class CallCountingReferenceResolver: ExternalReferenceResolver {
            var referencesAskedToResolve: Set<TopicReference> = []
            
            var referencesCreatingEntityFor: Set<ResolvedTopicReference> = []
            var referencesReadingURLFor: Set<ResolvedTopicReference> = []
            
            func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
                referencesAskedToResolve.insert(reference)
                
                // Only resolve a specific, known reference
                guard reference.description == "doc://com.external.testbundle/resolvable" else {
                    switch reference {
                    case .unresolved(let unresolved):
                        return .failure(unresolved, errorMessage: "Unit test: External resolve error.")
                    case .resolved(let resolvedResult):
                        return resolvedResult
                    }
                }
                // Note that this resolved reference doesn't have the same path as the unresolved reference.
                return .success(.init(bundleIdentifier: "com.external.testbundle", path: "/resolved", sourceLanguage: .swift))
            }
            
            func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
                referencesCreatingEntityFor.insert(reference)
                
                // Return an empty node
                return DocumentationNode(reference: reference, kind: .class, sourceLanguage: .swift, name: .conceptual(title: "Resolved"), markup: Document(), semantic: nil)
            }
            
            func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
                referencesReadingURLFor.insert(reference)
                
                return URL(string: "http://some.host/path/to/resolved")!
            }
        }
        
        let resolver = CallCountingReferenceResolver()

        // Copy the test bundle and add external links to the MyKit See Also.
        // We're using a See Also group, because external links aren't rendered in Topics groups.
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.testbundle" : resolver]) { url in
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
        defer { try? FileManager.default.removeItem(at: url) }
        
        // Verify the external link has been collected and pre-resolved.
        XCTAssertEqual(context.externallyResolvedLinks.keys.map({ $0.absoluteString }).sorted(), [
            "doc://com.external.testbundle/not-resolvable-1", // expected failure
            "doc://com.external.testbundle/not-resolvable-2", // expected failure
            "doc://com.external.testbundle/resolvable", // expected success
            "doc://com.external.testbundle/resolved" // the successfully resolved reference has a different reference which should also be collected.
        ], "Results for both failed and successfully resolved external references should be collected.")
        
        XCTAssertNil(context.externallyResolvedLinks[ValidatedURL("doc://com.external.other-test-bundle/article")!],
                     "External references without a registered external resolver should not be collected.")
        
        // Expected failed externally resolved reference.
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL("doc://com.external.testbundle/not-resolvable-1")!],
            TopicReferenceResolutionResult.failure(UnresolvedTopicReference(topicURL: ValidatedURL("doc://com.external.testbundle/not-resolvable-1")!), errorMessage: "Unit test: External resolve error.")
        )
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL("doc://com.external.testbundle/not-resolvable-2")!],
            TopicReferenceResolutionResult.failure(UnresolvedTopicReference(topicURL: ValidatedURL("doc://com.external.testbundle/not-resolvable-2")!), errorMessage: "Unit test: External resolve error.")
        )
        
        // Expected successful externally resolved reference.
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL("doc://com.external.testbundle/resolvable")!],
            TopicReferenceResolutionResult.success(ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/resolved", fragment: nil, sourceLanguage: .swift))
        )
        XCTAssertEqual(
            context.externallyResolvedLinks[ValidatedURL("doc://com.external.testbundle/resolved")!],
            TopicReferenceResolutionResult.success(ResolvedTopicReference(bundleIdentifier: "com.external.testbundle", path: "/resolved", fragment: nil, sourceLanguage: .swift))
        )
        
        XCTAssert(context.problems.contains(where: { $0.diagnostic.localizedSummary.contains("Unit test: External resolve error.")}),
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
            "doc://com.external.testbundle/resolved"
        ].sorted())
        
        // Verify that the resolver was asked to resolve all references that match its bundle identifier.
        XCTAssertEqual(resolver.referencesAskedToResolve.map({ $0.description }).sorted(), [
            "doc://com.external.testbundle/not-resolvable-1",
            "doc://com.external.testbundle/not-resolvable-2",
            "doc://com.external.testbundle/resolvable" // Note that this is the reference in the content.
        ])
        // Verify that the resolver wasn't passed references it didn't resolve.
        XCTAssertEqual(resolver.referencesCreatingEntityFor.map({ $0.description }).sorted(), [
            "doc://com.external.testbundle/resolved" // Note that this is the resolved reference, not the one from the content.
        ])
        XCTAssertEqual(resolver.referencesReadingURLFor.map({ $0.description }).sorted(), [
            "doc://com.external.testbundle/resolved" // Note that this is the resolved reference, not the one from the content.
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
        let (url, bundle, context) = try testBundleAndContext(copying: "TestBundle", externalResolvers: ["com.external.testbundle" : resolver], externalSymbolResolver: nil, configureBundle: { url in
            // Add external link with fragment
            let myClassMDURL = url.appendingPathComponent("documentation").appendingPathComponent("myclass.md")
            try String(contentsOf: myClassMDURL)
                .replacingOccurrences(of: "MyClass abstract.", with: "MyClass uses a <doc://com.external.testbundle/article#12345>.")
                .write(to: myClassMDURL, atomically: true, encoding: .utf8)
        })
        defer { try? FileManager.default.removeItem(at: url) }

        let myClassRef = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
        let documentationNode = try context.entity(with: myClassRef)
        
        // Verify the external link was resolved in markup.
        let abstractParagraph = try XCTUnwrap((documentationNode.semantic as? Symbol)?.abstract)
        let markdownLink = try XCTUnwrap(abstractParagraph.children.mapFirst { markup -> String? in
            return (markup as? Link)?.destination
        })
        XCTAssertEqual(markdownLink, "doc://com.external.testbundle/externally/resolved/path#67890")

        // Verify that the external link was stored in the context.
        let linkURL = try XCTUnwrap(ValidatedURL(markdownLink))
        guard case .success(let linkReference) = try XCTUnwrap(context.externallyResolvedLinks[linkURL]) else {
            XCTFail("Unexpected failed external reference.")
            return
        }
        XCTAssertEqual(linkReference.absoluteString, "doc://com.external.testbundle/externally/resolved/path#67890")

        // Verify that the final URL is as expected.
        let urlGenerator = PresentationURLGenerator(context: context, baseURL: URL(fileURLWithPath: "/"))
        let finalURL = urlGenerator.presentationURLForReference(linkReference)
        XCTAssertEqual(finalURL.absoluteString, "https://example.com/example/externally/resolved/path#67890")
    }
}
