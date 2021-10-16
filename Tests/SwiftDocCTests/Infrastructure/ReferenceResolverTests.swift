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

class ReferenceResolverTests: XCTestCase {
    func testResolvesMediaForIntro() throws {
        let source = """
@Intro(
       title: x) {
   
   @Image(source: missingimage.png, alt: missing)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: bundle, in: context, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
        _ = resolver.visitIntro(intro)
        XCTAssertEqual(resolver.problems.count, 1)
    }
    
    func testResolvesMediaForContentAndMedia() throws {
        let source = """
@ContentAndMedia {
   Blah blah.

   @Image(source: missing.png)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: bundle, in: context, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
        _ = resolver.visit(contentAndMedia)
        XCTAssertEqual(resolver.problems.count, 1)
    }

    func testResolvesExternalLinks() throws {
        let source = """
    @Intro(title: "Technology X") {
       Info at: <https://www.wikipedia.org>.
    }
    """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let intro = Intro(from: directive, source: nil, for: bundle, in: context, problems: &problems)!
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
        
        guard let container = resolver.visit(intro).children.first as? MarkupContainer,
              let firstElement = container.elements.first,
              firstElement.childCount > 2 else {
                XCTFail("Unexpected markup result")
                return
        }
        
        XCTAssertEqual((firstElement.child(at: 1) as? Link)?.destination, "https://www.wikipedia.org")
    }
    
    // Tests all reference syntax formats to a child symbol
    func testReferencesToChildFromFramework() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 9)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass" }, true)
    }

    // Test relative paths to non-child symbol
    func testReferencesToGrandChildFromFramework() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()" }, true)
    }
    
    // Test references to a sibling symbol
    func testReferencesToSiblingFromFramework() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/path" }, true)
    }

    // Test references to symbols in root paths
    func testReferencesToTutorial() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial" }, true)
    }

    // Test references to technology pages
    func testReferencesToTechnologyPages() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 3)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/TestOverview" }, true)
    }

    // Test external references
    func testExternalReferencesConsiderBundleIdentifier() throws {
        let (bundleURL, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        // Get a translated render node
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        let discussion = renderNode.primaryContentSections.mapFirst { section in
            return section as? ContentRenderSection
        }!
        
        let items = discussion.content.mapFirst(where: { block -> [RenderBlockContent.ListItem]? in
            guard case RenderBlockContent.unorderedList(items: let items) = block else {
                return nil
            }
            return items
        })!
        
        let inlineItems = items.compactMap { listItem in
            return listItem.content.mapFirst { block -> RenderInlineContent? in
                guard case RenderBlockContent.paragraph(inlineContent: let inlineItems) = block else {
                    return nil
                }
                return inlineItems.first
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
    
    func testRegisteredButUncuratedArticles() throws {
        var referencingArticleURL: URL!
        var uncuratedArticleFile: URL!
        
        let source = """
        # Article
        
        The abstract

        ## Overview
        
        Referencing an uncurated article will raise a warning: <doc:RegisteredArticle>
        """
        
        // TestBundle has more than one module, so automatic registration and curation won't happen
        let (bundleURL, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
            referencingArticleURL = root.appendingPathComponent("article.md")
            try source.write(to: referencingArticleURL, atomically: true, encoding: .utf8)
            
            uncuratedArticleFile = root.appendingPathComponent("UncuratedArticle.md")
            try """
            # Unregistered and Uncurated Article
            
            This article isn't automatically curated or registerd in the topic graph.
            
            ## Overview
            
            Its references aren't resolved, so this won't raise a warning: <doc:InvalidReferenceThatWillNotWarn>
            """.write(to: uncuratedArticleFile, atomically: true, encoding: .utf8)
        }
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        
        let diagnostics = context.problems.filter({ $0.diagnostic.source?.standardizedFileURL == uncuratedArticleFile.standardizedFileURL }).map(\.diagnostic)
        let diagnostic = try XCTUnwrap(diagnostics.first(where: { $0.identifier == "org.swift.docc.ArticleUncurated" }))
        XCTAssertEqual(diagnostic.localizedSummary, "You haven't curated 'doc://org.swift.docc.example/documentation/Test-Bundle/UncuratedArticle'")
        
        let referencingFileDiagnostics = context.problems.map(\.diagnostic).filter({ $0.source?.standardizedFileURL == referencingArticleURL.standardizedFileURL })
        XCTAssertEqual(referencingFileDiagnostics.filter({ $0.identifier == "org.swift.docc.unresolvedTopicReference" }).count, 1)
    }
    
    struct TestExternalReferenceResolver: ExternalReferenceResolver {
        var bundleIdentifier = "com.external.testbundle"
        var expectedReferencePath = "/externally/resolved/path"
        var resolvedEntityTitle = "Externally Resolved Title"
        var resolvedEntityKind = DocumentationNode.Kind.article
        var expectedAvailableSourceLanguages: Set<SourceLanguage> = [.swift, .objectiveC]
        
        func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReference {
            return .resolved(ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: expectedReferencePath, sourceLanguage: .swift))
        }
        
        func entity(with reference: ResolvedTopicReference) throws -> DocumentationNode {
            return DocumentationNode(
                reference: reference,
                kind: resolvedEntityKind,
                sourceLanguage: .swift,
                availableSourceLanguages: expectedAvailableSourceLanguages,
                name: .conceptual(title: resolvedEntityTitle),
                markup: Document(parsing: "Externally Resolved Markup Content", options: [.parseBlockDirectives, .parseSymbolLinks]),
                semantic: Semantic(),
                platformNames: ["fooOS", "barOS"]
            )
        }
        
        func urlForResolvedReference(_ reference: ResolvedTopicReference) -> URL {
            fatalError("Unimplemented")
        }
    }
    
    func testUnresolvedTutorialReferenceIsWarning() throws {
        let source = """
@Chapter(name: "SwiftUI Essentials") {

  Learn how to use SwiftUI to compose rich views out of simple ones.

  @TutorialReference(tutorial: "doc:does-not-exist")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()

        let chapter = try XCTUnwrap(Chapter(from: directive, source: nil, for: bundle, in: context, problems: &problems))
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
        _ = resolver.visitChapter(chapter)
        XCTAssertFalse(resolver.problems.containsErrors)
        XCTAssertEqual(resolver.problems.count, 1)
        XCTAssertEqual(resolver.problems.filter({ $0.diagnostic.severity == .warning }).count, 1)
    }
    
    func testResolvesArticleContent() throws {
        let source = """
        # An Article
        
        Abstract link to ``MyKit``.
        
        Discussion link to ``SideKit``.
        """
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let article = try XCTUnwrap(Article(markup: document, metadata: nil, redirects: nil))
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
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
}
