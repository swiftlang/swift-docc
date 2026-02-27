/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@_spi(ExternalLinks) @testable import SwiftDocC
import Markdown
import SymbolKit
import DocCCommon
import DocCTestUtilities

class ReferenceResolverTests: XCTestCase {
    func testResolvesMediaForIntro() async throws {
        let source = """
@Intro(
       title: x) {
   
   @Image(source: missingimage.png, alt: missing)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext()
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: context.inputs, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context)
        _ = resolver.visitIntro(intro)
        XCTAssertEqual(resolver.problems.count, 1)
    }
    
    func testResolvesMediaForContentAndMedia() async throws {
        let source = """
@ContentAndMedia {
   Blah blah.

   @Image(source: missing.png)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext()
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context)
        _ = resolver.visit(contentAndMedia)
        XCTAssertEqual(resolver.problems.count, 1)
    }

    func testResolvesExternalLinks() async throws {
        let source = """
    @Intro(title: "Technology X") {
       Info at: <https://www.wikipedia.org>.
    }
    """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext()
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: context.inputs, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context)
        
        guard let container = resolver.visit(intro).children.first as? MarkupContainer,
              let firstElement = container.elements.first,
              firstElement.childCount > 2 else {
                XCTFail("Unexpected markup result")
                return
        }
        
        XCTAssertEqual((firstElement.child(at: 1) as? Link)?.destination, "https://www.wikipedia.org")
    }
    
    // Tests all reference syntax formats to a child symbol
    func testReferencesToChildFromFramework() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass``
            - ``SideKit/SideClass``
            - ``documentation/SideKit/SideClass``
            - ``/documentation/SideKit/SideClass``
            - <doc:SideClass>
            - <doc:SideKit/SideClass>
            - <doc:documentation/SideKit/SideClass>
            - <doc:/documentation/SideKit/SideClass>
            - <doc://org.swift.docc.example/documentation/SideKit/SideClass>
            - <doc://TestBundle/documentation/SideKit/SideClass>

            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 9)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass" }, true)
    }

    // Test relative paths to non-child symbol
    func testReferencesToGrandChildFromFramework() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``SideClass/myFunction()``
            - ``SideKit/SideClass/myFunction()``
            - ``documentation/SideKit/SideClass/myFunction()``
            - ``/documentation/SideKit/SideClass/myFunction()``
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()" }, true)
    }
    
    // Test references to a sibling symbol
    func testReferencesToSiblingFromFramework() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit/SideClass/myFunction()``
            SideKit module root symbol
            ## Topics
            ### Basics
            - ``path``
            - ``SideClass/path``
            - ``documentation/SideKit/SideClass/path``
            - ``/documentation/SideKit/SideClass/path``
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/path" }, true)
    }

    // Test references to symbols in root paths
    func testReferencesToTutorial() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit/SideClass/myFunction()``
            SideKit module root symbol
            ## Topics
            ### Basics
            - <doc:TestTutorial>
            - <doc:Test-Bundle/TestTutorial>
            - <doc:Test-Bundle/TestTutorial>
            - <doc:/Test-Bundle/TestTutorial>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial" }, true)
    }

    // Test references to technology pages
    func testReferencesToTechnologyPages() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit/SideClass/myFunction()``
            SideKit module root symbol
            ## Topics
            ### Basics
            - <doc:TestOverview>
            - <doc:tutorials/TestOverview>
            - <doc:/tutorials/TestOverview>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 3)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/TestOverview" }, true)
    }

    // Test external references
    func testExternalReferencesConsiderBundleIdentifier() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { root in
            /// Article that curates `SideClass`
            try """
            # ``SideKit/SideClass/myFunction()``
            SideKit module root symbol

            - <doc://blip_blop/documentation/MyKit>
            - <blip://blip_blop/documentation/MyKit>
            - [Example](https://www.example.com)
            - <https://www.example.com>
            - <https://www.example.com/MyKit>
            """.write(to: root.appendingPathComponent("documentation/sidekit.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        let discussion = renderNode.primaryContentSections.mapFirst { section in
            return section as? ContentRenderSection
        }!
        
        let items = discussion.content.mapFirst(where: { block -> [RenderBlockContent.ListItem]? in
            guard case RenderBlockContent.unorderedList(let l) = block else {
                return nil
            }
            return l.items
        })!
        
        let inlineItems = items.compactMap { listItem in
            return listItem.content.mapFirst { block -> RenderInlineContent? in
                guard case RenderBlockContent.paragraph(let p) = block else {
                    return nil
                }
                return p.inlineContent.first
            }
        }
        
        guard inlineItems.count == 5 else {
            XCTFail("Expected to convert all links but not found the same amount")
            return
        }
        
        XCTAssertEqual(inlineItems[0], .text("doc://blip_blop/documentation/MyKit"))
        
        if case let .reference(referenceIdentifier, _, _, _) = inlineItems[1] {
            XCTAssertEqual((renderNode.references[referenceIdentifier.identifier] as? LinkReference)?.url, "blip://blip_blop/documentation/MyKit")
        } else {
            XCTFail("The unknown blip:// link should have been converted to a `LinkReference`.")
        }
        
        do {
            guard case RenderInlineContent.reference(identifier: let refID, _, let overridingTitle, let overridingTitleInlineContent) = inlineItems[2],
            let reference = renderNode.references[refID.identifier] as? LinkReference else {
                XCTFail("[Example](https://www.example.com) wasn't converted to a reference")
                return
            }
            
            XCTAssertEqual(reference.title, "Example")
            XCTAssertEqual(reference.titleInlineContent, [.text("Example")])
            XCTAssertEqual(reference.url, "https://www.example.com")
            XCTAssertNil(overridingTitle)
            XCTAssertNil(overridingTitleInlineContent)
        }

        do {
            guard case RenderInlineContent.reference(identifier: let refID, _, let overridingTitle, let overridingTitleInlineContent) = inlineItems[3],
            let reference = renderNode.references[refID.identifier] as? LinkReference else {
                XCTFail("[https://www.example.com](https://www.example.com) wasn't converted to a reference")
                return
            }
            
            XCTAssertEqual(overridingTitle, "https://www.example.com")
            XCTAssertEqual(overridingTitleInlineContent, [.text("https://www.example.com")])
            XCTAssertEqual(reference.url, "https://www.example.com")
        }
        
        do {
            guard case RenderInlineContent.reference(identifier: let refID, _, _, _) = inlineItems[4],
            let reference = renderNode.references[refID.identifier] as? LinkReference else {
                XCTFail("[https://www.example.com/MyKit](https://www.example.com/MyKit) wasn't converted to a reference")
                return
            }
            
            XCTAssertEqual(reference.title, "https://www.example.com/MyKit")
            XCTAssertEqual(reference.titleInlineContent, [.text("https://www.example.com/MyKit")])
            XCTAssertEqual(reference.url, "https://www.example.com/MyKit")
        }
    }
    
    func testWarningsAboutArticleNotInDocumentationHierarchy() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            // This setup is not supported and only happens if the developer manually mixes symbol inputs from different builds.
            JSONFile(name: "FirstModuleName.symbols.json", content: makeSymbolGraph(moduleName: "FirstModuleName")),
            JSONFile(name: "SecondModuleName.symbols.json", content: makeSymbolGraph(moduleName: "SecondModuleName")),
            
            TextFile(name: "FirstModule.md", utf8Content:"""
            # ``FirstModuleName``
            
            Referencing an article not in the documentation hierarchy raises a warning: <doc:UncuratedArticle>
            """),
            
            TextFile(name: "UncuratedArticle.md", utf8Content:"""
            # Unregistered and Uncurated Article
            
            This article isn't automatically curated or registered in the topic graph.
            
            Its references aren't resolved, so this won't raise a warning: <doc:NotFoundThatWillNotWarn>
            """),
        ])
        let (_, context) = try await loadBundle(catalog: catalog, diagnosticFilterLevel: .information)
        
        let problems = context.problems.sorted(by: { $0.diagnostic.source?.lastPathComponent ?? "" < $1.diagnostic.source?.lastPathComponent ?? "" })
        XCTAssertEqual(problems.map(\.diagnostic.identifier), ["org.swift.docc.MultipleMainModules", "UnfindableArticle", "ArticleNotInDocumentationHierarchy"],
                       "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        do {
            let diagnostic = try XCTUnwrap(problems.dropFirst().first?.diagnostic)
            XCTAssertEqual(diagnostic.source?.lastPathComponent, "FirstModule.md")
            XCTAssertEqual(diagnostic.summary, "Article is not findable in invalid documentation hierarchy with 2 roots")
            XCTAssertEqual(diagnostic.explanation, """
                Documentation with 2 roots ('FirstModuleName' and 'SecondModuleName') has a disjoint and unsupported documentation hierarchy.
                Because there are multiple roots in the hierarchy, it's undefined behavior where in hierarchy this article would belong.
                As a consequence, the 'Unregistered and Uncurated Article' article (UncuratedArticle.md) is not findable and has no page in the output.
                """)
        }
        
        do {
            let diagnostic = try XCTUnwrap(problems.last?.diagnostic)
            XCTAssertEqual(diagnostic.source?.lastPathComponent, "UncuratedArticle.md")
            XCTAssertEqual(diagnostic.summary, "Article 'UncuratedArticle.md' has no default location in invalid documentation hierarchy with 2 roots")
            XCTAssertEqual(diagnostic.explanation, """
                A single DocC build covers either a single module (for example a framework, library, or executable) or a single article-only technology.
                Documentation with 2 roots ('FirstModuleName' and 'SecondModuleName') has a disjoint and unsupported documentation hierarchy.
                Because there are multiple roots in the hierarchy, it's undefined behavior where in hierarchy this article would belong.
                As a consequence, DocC cannot create a page for the 'Unregistered and Uncurated Article' article (UncuratedArticle.md).
                """)
        }
    }
    
    func testRelativeReferencesToExtensionSymbols() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "BundleWithRelativePathAmbiguity") { root in
            // We don't want the external target to be part of the archive as that is not
            // officially supported yet.
            try FileManager.default.removeItem(at: root.appendingPathComponent("Dependency.symbols.json"))
            
            try """
            # ``BundleWithRelativePathAmbiguity/Dependency``

            ## Overview
            
            ### Module Scope Links
            
            - ``BundleWithRelativePathAmbiguity/Dependency``
            - ``BundleWithRelativePathAmbiguity/Dependency/AmbiguousType``
            - ``BundleWithRelativePathAmbiguity/Dependency/AmbiguousType/foo()``
            
            ### Extended Module Scope Links
            
            - ``Dependency``
            - ``Dependency/AmbiguousType``
            - ``Dependency/AmbiguousType/foo()``
            
            ### Local Scope Links
            
            - ``Dependency``
            - ``AmbiguousType``
            - ``AmbiguousType/foo()``
            """.write(to: root.appendingPathComponent("Article.md"), atomically: true, encoding: .utf8)
        }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/BundleWithRelativePathAmbiguity/Dependency", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        let content = try XCTUnwrap(renderNode.primaryContentSections.first as? ContentRenderSection).content
        
        let expectedReferences = [
            "doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity/Dependency",
            "doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity/Dependency/AmbiguousType",
            "doc://org.swift.docc.example/documentation/BundleWithRelativePathAmbiguity/Dependency/AmbiguousType/foo()",
        ]
        
        let sectionContents = [
            content.contents(of: "Module Scope Links"),
            content.contents(of: "Extended Module Scope Links"),
            content.contents(of: "Local Scope Links"),
        ]
        
        let sectionReferences = try sectionContents.map { sectionContent in
            try sectionContent.listItems().map { item in try XCTUnwrap(item.firstReference(), "found no reference for \(item)") }
        }
            
        for resolvedReferencesOfSection in sectionReferences {
            for (resolved, expected) in zip(resolvedReferencesOfSection, expectedReferences) {
                XCTAssertEqual(resolved.identifier, expected)
            }
        }
    }

    func testCuratedExtensionRemovesEmptyPage() async throws {
        let (_, context) = try await testBundleAndContext(named: "ModuleWithSingleExtension")

        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithSingleExtension", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode

        // The only children of the root topic should be the `MyNamespace` enum - i.e. the Swift
        // "Extended Module" page and its Array "Extended Structure" page should be removed.
        XCTAssertEqual(renderNode.topicSections.first?.identifiers, [
            "doc://org.swift.docc.example/documentation/ModuleWithSingleExtension/MyNamespace"
        ])

        // Make sure that the symbol added in the extension is still present in the topic graph,
        // even though its synthetic "extended symbol" parents are not
        XCTAssertNoThrow(try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array/asdf", sourceLanguage: .swift)))
    }

    func testCuratedExtensionWithDanglingReference() async throws {
        let (_, _, context) = try await testBundleAndContext(copying: "ModuleWithSingleExtension") { root in
            let topLevelArticle = root.appendingPathComponent("ModuleWithSingleExtension.md")
            try FileManager.default.removeItem(at: topLevelArticle)

            try """
            # ``ModuleWithSingleExtension``

            This is a test module with an extension to ``Swift/Array``.
            """.write(to: topLevelArticle, atomically: true, encoding: .utf8)
        }

        // Make sure that linking to `Swift/Array` raises a diagnostic about the page having been removed
        let diagnostic = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.removedExtensionLinkDestination"}))
        XCTAssertEqual(diagnostic.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(diagnostic.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "`Swift/Array`")

        // Also make sure that the extension pages are still gone
        let extendedModule = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithSingleExtension/Swift", sourceLanguage: .swift)
        XCTAssertFalse(context.knownPages.contains(where: { $0 == extendedModule }))

        let extendedStructure = ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array", sourceLanguage: .swift)
        XCTAssertFalse(context.knownPages.contains(where: { $0 == extendedStructure }))

        // Load the RenderNode for the root article and make sure that the `Swift/Array` symbol link
        // is not rendered as a link
        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithSingleExtension", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode

        XCTAssertEqual(renderNode.abstract, [
            .text("This is a test module with an extension to "),
            .codeVoice(code: "Swift/Array"),
            .text(".")
        ])
    }

    func testCuratedExtensionWithDanglingReferenceToFragment() async throws {
        let (_, bundle, context) = try await testBundleAndContext(copying: "ModuleWithSingleExtension") { root in
            let topLevelArticle = root.appendingPathComponent("ModuleWithSingleExtension.md")
            try FileManager.default.removeItem(at: topLevelArticle)

            try """
            # ``ModuleWithSingleExtension``

            This is a test module with an extension to ``Swift/Array``.
            """.write(to: topLevelArticle, atomically: true, encoding: .utf8)
        }

        // Make sure that linking to `Swift/Array` raises a diagnostic about the page having been removed
        let diagnostic = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.removedExtensionLinkDestination" }))
        XCTAssertEqual(diagnostic.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(diagnostic.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "`Swift/Array`")

        // Also make sure that the extension pages are still gone
        let extendedModule = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift", sourceLanguage: .swift)
        XCTAssertFalse(context.knownPages.contains(where: { $0 == extendedModule }))

        let extendedStructure = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array", sourceLanguage: .swift)
        XCTAssertFalse(context.knownPages.contains(where: { $0 == extendedStructure }))
    }

    func testCuratedExtensionWithDocumentationExtension() async throws {
        let (_, bundle, context) = try await testBundleAndContext(copying: "ModuleWithSingleExtension") { root in
            let topLevelArticle = root.appendingPathComponent("ModuleWithSingleExtension.md")
            try FileManager.default.removeItem(at: topLevelArticle)

            try """
            # ``ModuleWithSingleExtension``

            This is a test module with an extension to ``Swift/Array``.
            """.write(to: topLevelArticle, atomically: true, encoding: .utf8)

            try """
            # ``ModuleWithSingleExtension/Swift/Array``

            This is an extension to an extended type in another module.
            """.write(to: root.appendingPathComponent("Array.md"), atomically: true, encoding: .utf8)
        }

        // Make sure that linking to `Swift/Array` does not raise a diagnostic, since the page should still exist
        XCTAssertFalse(context.problems.contains(where: { $0.diagnostic.identifier == "org.swift.docc.removedExtensionLinkDestination" || $0.diagnostic.identifier == "org.swift.docc.unresolvedTopicReference" }))

        // Because the `Swift/Array` extension has an extension article, the pages should not be marked as virtual
        let extendedModule = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift", sourceLanguage: .swift)
        XCTAssert(context.knownPages.contains(where: { $0 == extendedModule }))

        let extendedStructure = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array", sourceLanguage: .swift)
        XCTAssert(context.knownPages.contains(where: { $0 == extendedStructure }))
    }

    func testCuratedExtensionWithAdditionalConformance() async throws {
        let (_, context) = try await testBundleAndContext(named: "ModuleWithConformanceAndExtension")

        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithConformanceAndExtension/MyProtocol", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode

        let conformanceSection = try XCTUnwrap(renderNode.relationshipSections.first(where: { $0.type == RelationshipsGroup.Kind.conformingTypes.rawValue }))
        XCTAssertEqual(conformanceSection.identifiers.count, 1)

        // Make sure that the reference to the dropped `Bool` page isn't rendered as a resolved link
        let boolReference = try XCTUnwrap(conformanceSection.identifiers.first)
        let renderReference = try XCTUnwrap(renderNode.references[boolReference])
        XCTAssert(renderReference is UnresolvedRenderReference)
    }

    func testExtensionWithEmptyDeclarationFragments() async throws {
        let (_, context) = try await testBundleAndContext(named: "ModuleWithEmptyDeclarationFragments")

        let node = try context.entity(with: ResolvedTopicReference(bundleID: context.inputs.id, path: "/documentation/ModuleWithEmptyDeclarationFragments", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode

        // Despite having an extension to Float, there are no symbols added by that extension, so
        // the resulting documentation should be empty
        XCTAssertEqual(renderNode.topicSections.count, 0)
    }
    
    func testUnresolvedTutorialReferenceIsWarning() async throws {
        let source = """
@Chapter(name: "SwiftUI Essentials") {

  Learn how to use SwiftUI to compose rich views out of simple ones.

  @TutorialReference(tutorial: "doc:does-not-exist")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext()
        var problems = [Problem]()

        let chapter = try XCTUnwrap(Chapter(from: directive, source: nil, for: context.inputs, problems: &problems))
        var resolver = ReferenceResolver(context: context)
        _ = resolver.visitChapter(chapter)
        XCTAssertFalse(resolver.problems.containsErrors)
        XCTAssertEqual(resolver.problems.count, 1)
        XCTAssertEqual(resolver.problems.filter({ $0.diagnostic.severity == .warning }).count, 1)
    }
    
    func testResolvesArticleContent() async throws {
        let source = """
        # An Article
        
        Abstract link to ``MyKit``.
        
        Discussion link to ``SideKit``.
        """
        
        let (_, context) = try await testBundleAndContext()
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let article = try XCTUnwrap(Article(markup: document, metadata: nil, redirects: nil, options: [:]))
        
        var resolver = ReferenceResolver(context: context)
        let resolvedArticle = try XCTUnwrap(resolver.visitArticle(article) as? Article)
        let abstractSection = try XCTUnwrap(resolvedArticle.abstractSection)
        
        // Check abstract for unresolved links
        var foundSymbolAbstractLink = false
        for index in 0 ..< abstractSection.paragraph.childCount {
            if let link = abstractSection.paragraph.child(at: index) as? SymbolLink, let destination = link.destination {
                XCTAssertNotNil(URL(string: destination))
                foundSymbolAbstractLink = true
            }
        }
        XCTAssertTrue(foundSymbolAbstractLink)

        let discussion = try XCTUnwrap(resolvedArticle.discussion?.content.first as? Paragraph)

        // Check discussion for unresolved links
        var foundSymbolDiscussionLink = false
        for index in 0 ..< discussion.childCount {
            if let link = discussion.child(at: index) as? SymbolLink, let destination = link.destination {
                XCTAssertNotNil(URL(string: destination))
                foundSymbolDiscussionLink = true
            }
        }
        XCTAssertTrue(foundSymbolDiscussionLink)
    }
    
    func testForwardsSymbolPropertiesThatAreUnmodifiedDuringLinkResolution() async throws {
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        var resolver = ReferenceResolver(context: context)
        
        let symbol = try XCTUnwrap(context.documentationCache["s:5MyKit0A5ClassC"]?.semantic as? Symbol)
        
        /// Verifies the given assertion on a variants property of the given symbols.
        func assertSymbolVariants<Variant>(
            _ symbol1: Symbol,
            _ symbol2: Symbol,
            keyPath: KeyPath<Symbol, DocumentationDataVariants<Variant>>,
            assertion: (Variant, Variant) -> (),
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            let variants1Values = symbol1[keyPath: keyPath].allValues
            let variants2Values = symbol2[keyPath: keyPath].allValues
            
            XCTAssertEqual(
                variants1Values.count, variants2Values.count,
                "The two symbols have a different number of variants for the key path '\(keyPath)'.",
                file: file, line: line
            )
            
            for (variants1Value, variants2Value) in zip(variants1Values, variants2Values) {
                XCTAssertEqual(
                    variants1Value.trait, variants2Value.trait,
                    "The two symbols have variants of mismatching traits for the key path '\(keyPath)'.",
                    file: file, line: line
                )
                assertion(variants1Value.variant, variants2Value.variant)
            }
        }
        
        /// Populates the symbol with an Objective-C variant and returns an assertion that checks that another symbol
        /// has the same variants.
        func populateObjCVariantAndCreateAssertion<Variant>(
            keyPath: ReferenceWritableKeyPath<Symbol, DocumentationDataVariants<Variant>>,
            assertion: @escaping (Variant, Variant) -> (),
            file: StaticString = #filePath,
            line: UInt = #line
        ) -> ((_ resolvedSymbol: Symbol) -> Void) {
            symbol[keyPath: keyPath][.objectiveC] = symbol[keyPath: keyPath].firstValue
            
            return { resolvedSymbol in
                assertSymbolVariants(
                    symbol,
                    resolvedSymbol,
                    keyPath: keyPath,
                    assertion: assertion,
                    file: file,
                    line: line
                )
            }
        }
        
        /// Populates the symbol with an Objective-C variant and returns an assertion that checks that another symbol
        /// has the same variants.
        ///
        /// This overload accepts a Symbol key path whose variant value is Equatable. The default assertion verifies that the variant values of the two
        /// symbols are equal.
        func populateObjCVariantAndCreateAssertion<Variant: Equatable>(
            keyPath: ReferenceWritableKeyPath<Symbol, DocumentationDataVariants<Variant>>,
            assertion: @escaping (Variant, Variant) -> () = { XCTAssertEqual($0, $1, file: #file, line: #line) },
            file: StaticString = #filePath,
            line: UInt = #line
        ) -> ((_ resolvedSymbol: Symbol) -> Void) {
            populateObjCVariantAndCreateAssertion(keyPath: keyPath, assertion: assertion)
        }
        
        let assertions = [
            // For variants properties that hold an Equatable value, populate the Objective-C variant and create
            // an assertion that verifies that the resolved symbol contains the same variants as the original symbol.
            
            populateObjCVariantAndCreateAssertion(keyPath: \.kindVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.titleVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.subHeadingVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.navigatorVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.roleHeadingVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.platformNameVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.isRequiredVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.externalIDVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.accessLevelVariants),
            populateObjCVariantAndCreateAssertion(keyPath: \.originVariants),
            
            // Otherwise, for variants properties that don't a value that is Equatable, populate the Objective-C variant
            // and specify an assertion.
            
            populateObjCVariantAndCreateAssertion(keyPath: \.availabilityVariants) { value1, value2 in
                XCTAssertEqual(value1.availability.count, value2.availability.count)
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.deprecatedSummaryVariants) { value1, value2 in
                XCTAssertEqual(
                    value1.content.map { $0.debugDescription() },
                    value2.content.map { $0.debugDescription() }
                )
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.mixinsVariants) { value1, value2 in
                XCTAssertEqual(value1.count, value2.count)
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.declarationVariants) { value1, value2 in
                XCTAssertEqual(value1.count, value2.count)
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.defaultImplementationsVariants) { value1, value2 in
                XCTAssertEqual(value1.groups.count, value2.groups.count)
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.relationshipsVariants) { value1, value2 in
                XCTAssertEqual(value1.groups.count, value2.groups.count)
            },
            populateObjCVariantAndCreateAssertion(keyPath: \.automaticTaskGroupsVariants) { value1, value2 in
                XCTAssertEqual(value1.map { $0.title }, value2.map { $0.title })
                XCTAssertEqual(value1.map { $0.references }, value2.map { $0.references })
                XCTAssertEqual(value1.map { $0.renderPositionPreference }, value2.map { $0.renderPositionPreference })
            },
        ]
        
        let resolvedSymbol = try XCTUnwrap(resolver.visitSymbol(symbol) as? Symbol)
        
        // Assert symbol variant values that are Equatable.
        for assertion in assertions {
            assertion(resolvedSymbol)
        }
    }
    
    func testEmitsDiagnosticsForEachDocumentationChunk() async throws {
        let moduleReference = ResolvedTopicReference(bundleID: "com.example.test", path: "/documentation/ModuleName", sourceLanguage: .swift)
        let reference = ResolvedTopicReference(bundleID: "com.example.test", path: "/documentation/ModuleName/Something", sourceLanguage: .swift)
        
        let inSourceComment = """
        Some description of this class
        
        These links to ``NotFoundSymbol`` and <doc:NotFoundArticle> won't resolve.
        
        This image name won't resolve: ![Some image that's not found](not-found-image)
        """
        let start = (line: 7, character: 4) // arbitrary non-zero values
        let sourceCodeURL = URL(fileURLWithPath: "/Users/username/path/to/Something.swift")
        
        let symbol = SymbolGraph.Symbol(
            identifier: .init(precise: "some-symbol-id", interfaceLanguage: SourceLanguage.swift.id),
            names: .init(title: "Something", navigator: nil, subHeading: nil, prose: nil),
            pathComponents: ["Something"],
            docComment: SymbolGraph.LineList(
                inSourceComment.splitByNewlines.enumerated().map { lineOffset, line in
                    SymbolGraph.LineList.Line(text: line, range: .init(
                        start: .init(line: start.line + lineOffset, character: start.character),
                        end: .init(line: start.line + lineOffset, character: start.character + line.count)
                    ))
                },
                uri: sourceCodeURL.absoluteString // We want the "file://" prefix
            ),
            accessLevel: .public,
            kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
            mixins: [:]
        )
        
        let (_, context) = try await testBundleAndContext()
        
        let documentationExtensionContent = """
        # ``Something``
        
        Continue the documentation for the "something" class.
        
        These other links to ``OtherNotFoundSymbol`` and <doc:OtherNotFoundArticle> also won't resolve.
        
        This other image name also won't resolve: ![Some other image that's not found](other-not-found-image)
        """
        let documentationExtensionURL = URL(fileURLWithPath: "/Users/username/path/to/SomeCatalog.docc/Something.md")
        
        var ignoredProblems = [Problem]()
        let article = Article(
            from: Document(parsing: documentationExtensionContent, source: documentationExtensionURL, options: [.parseSymbolLinks, .parseBlockDirectives]),
            source: documentationExtensionURL,
            for: context.inputs,
            problems: &ignoredProblems
        )
        XCTAssert(ignoredProblems.isEmpty, "Unexpected problems creating article")
        
        let node = DocumentationNode(
            reference: reference,
            symbol: symbol,
            platformName: nil,
            moduleReference: moduleReference,
            article: article,
            engine: context.diagnosticEngine
        )
        
        XCTAssertEqual(node.docChunks.count, 2, "This node has content from both the in-source comment and the documentation extension file.")
        
        var resolver = ReferenceResolver(context: context)
        _ = resolver.visitSymbol(node.semantic as! Symbol)
        
        let problems = resolver.problems.sorted(by: \.diagnostic.summary)
        XCTAssertEqual(problems.count, 6)
        
        // These links to ``NotFoundSymbol`` and <doc:NotFoundArticle> won't resolve.
        do {
            let problem = try XCTUnwrap(problems.first)
            XCTAssertEqual(problem.diagnostic.summary, "Can't resolve 'NotFoundArticle'")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/Something.swift")
            // Note: `ReferenceResolver` doesn't offset diagnostics. That happens in `DocumentationContext/resolveLinks(curatedReferences:bundle:)`
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 3)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 3)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 44)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 59)
        }
        do {
            let problem = try XCTUnwrap(problems.dropFirst().first)
            XCTAssertEqual(problem.diagnostic.summary, "Can't resolve 'NotFoundSymbol'")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/Something.swift")
            // Note: `ReferenceResolver` doesn't offset diagnostics. That happens in `DocumentationContext/resolveLinks(curatedReferences:bundle:)`
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 3)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 3)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 18)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 32)
        }
        
        // These other links to ``OtherNotFoundSymbol`` and <doc:OtherNotFoundArticle> also won't resolve.
        do {
            let problem = try XCTUnwrap(problems.dropFirst(2).first)
            XCTAssertEqual(problem.diagnostic.summary, "Can't resolve 'OtherNotFoundArticle'")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/SomeCatalog.docc/Something.md")
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 55)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 75)
        }
        do {
            let problem = try XCTUnwrap(problems.dropFirst(3).first)
            XCTAssertEqual(problem.diagnostic.summary, "Can't resolve 'OtherNotFoundSymbol'")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/SomeCatalog.docc/Something.md")
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 24)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 43)
        }
        
        // This image name won't resolve: ![Some image that's not found](some-not-found-image)
        do {
            let problem = try XCTUnwrap(problems.dropFirst(4).first)
            XCTAssertEqual(problem.diagnostic.summary, "Resource 'not-found-image' couldn't be found")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/Something.swift")
            // Note: `ReferenceResolver` doesn't offset diagnostics. That happens in `DocumentationContext/resolveLinks(curatedReferences:bundle:)`
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 5)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 32)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 79)
        }
        
        // This other image name also won't resolve: ![Some other image that's not found](other-not-found-image)
        do {
            let problem = try XCTUnwrap(problems.dropFirst(5).first)
            XCTAssertEqual(problem.diagnostic.summary, "Resource 'other-not-found-image' couldn't be found")
            XCTAssertEqual(problem.diagnostic.source?.path, "/Users/username/path/to/SomeCatalog.docc/Something.md")
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.line, 7)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.line, 7)
            XCTAssertEqual(problem.diagnostic.range?.lowerBound.column, 43)
            XCTAssertEqual(problem.diagnostic.range?.upperBound.column, 102)
        }
    }
}

private extension DocumentationDataVariantsTrait {
    static var objectiveC: DocumentationDataVariantsTrait { .init(interfaceLanguage: "occ") }
}

private extension Collection<RenderBlockContent> {
    func contents(of heading: String) -> Slice<Self> {
        var headingLevel: Int = 1
        
        guard let headingIndex = self.firstIndex(where: { element in
            if case let .heading(value) = element {
                headingLevel = value.level
                return heading == value.text
            }
            return false
        }) else {
            return Slice(base: self, bounds: self.startIndex..<self.startIndex)
        }
        
        let contentStart = self.index(after: headingIndex)
        
        return Slice(base: self, bounds: contentStart..<(self[contentStart...].firstIndex(where: { element in
            if case let .heading(value) = element {
                return value.level <= headingLevel
            }
            return false
        }) ?? self.endIndex))
    }
    
    func listItems() -> [RenderBlockContent.ListItem] {
        self.compactMap { block -> [RenderBlockContent.ListItem]? in
            if case let .unorderedList(value) = block {
                return value.items
            }
            return nil
        }.flatMap({ $0 })
    }
}

private extension RenderBlockContent.ListItem {
    func firstReference() -> RenderReferenceIdentifier? {
        self.content.compactMap { block in
            guard case let .paragraph(value) = block else {
                return nil
            }
            
            return value.inlineContent.compactMap { content in
                guard case let .reference(identifier, _, _, _) = content else {
                    return nil
                }
                
                return identifier
            }.first
        }.first
    }
}
