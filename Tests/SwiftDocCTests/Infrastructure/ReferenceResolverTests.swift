/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
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
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 9)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass" }, true)
    }

    // Test relative paths to non-child symbol
    func testReferencesToGrandChildFromFramework() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/myFunction()" }, true)
    }
    
    // Test references to a sibling symbol
    func testReferencesToSiblingFromFramework() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/documentation/SideKit/SideClass/path" }, true)
    }

    // Test references to symbols in root paths
    func testReferencesToTutorial() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 4)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial" }, true)
    }

    // Test references to technology pages
    func testReferencesToTechnologyPages() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        // Verify resolved links
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.count, 3)
        XCTAssertEqual(renderNode.topicSections.first?.identifiers.allSatisfy { $0 == "doc://org.swift.docc.example/tutorials/TestOverview" }, true)
    }

    // Test external references
    func testExternalReferencesConsiderBundleIdentifier() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/SideKit/SideClass/myFunction()", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
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
        let (_, _, context) = try testBundleAndContext(copying: "TestBundle") { root in
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
        
        let diagnostics = context.problems.filter({ $0.diagnostic.source?.standardizedFileURL == uncuratedArticleFile.standardizedFileURL }).map(\.diagnostic)
        let diagnostic = try XCTUnwrap(diagnostics.first(where: { $0.identifier == "org.swift.docc.ArticleUncurated" }))
        XCTAssertEqual(diagnostic.localizedSummary, "You haven't curated 'doc://org.swift.docc.example/documentation/Test-Bundle/UncuratedArticle'")
        
        let referencingFileDiagnostics = context.problems.map(\.diagnostic).filter({ $0.source?.standardizedFileURL == referencingArticleURL.standardizedFileURL })
        XCTAssertEqual(referencingFileDiagnostics.filter({ $0.identifier == "org.swift.docc.unresolvedTopicReference" }).count, 1)
    }
    
    func testRelativeReferencesToExtensionSymbols() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "BundleWithRelativePathAmbiguity") { root in
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
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/BundleWithRelativePathAmbiguity/Dependency", sourceLanguage: .swift))
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference, source: nil)
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
            zip(resolvedReferencesOfSection, expectedReferences).forEach { resolved, expected in
                XCTAssertEqual(resolved.identifier, expected)
            }
        }
    }
    
    struct TestExternalReferenceResolver: ExternalReferenceResolver {
        var bundleIdentifier = "com.external.testbundle"
        var expectedReferencePath = "/externally/resolved/path"
        var resolvedEntityTitle = "Externally Resolved Title"
        var resolvedEntityKind = DocumentationNode.Kind.article
        var expectedAvailableSourceLanguages: Set<SourceLanguage> = [.swift, .objectiveC]
        
        func resolve(_ reference: TopicReference, sourceLanguage: SourceLanguage) -> TopicReferenceResolutionResult {
            return .success(ResolvedTopicReference(bundleIdentifier: bundleIdentifier, path: expectedReferencePath, sourceLanguage: .swift))
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
        let article = try XCTUnwrap(Article(markup: document, metadata: nil, redirects: nil, options: [:]))
        
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
    
    func testForwardsSymbolPropertiesThatAreUnmodifiedDuringLinkResolution() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var resolver = ReferenceResolver(context: context, bundle: bundle, source: nil)
        
        let symbol = try XCTUnwrap(context.symbolIndex["s:5MyKit0A5ClassC"]?.semantic as? Symbol)
        
        /// Verifies the given assertion on a variants property of the given symbols.
        func assertSymbolVariants<Variant>(
            _ symbol1: Symbol,
            _ symbol2: Symbol,
            keyPath: KeyPath<Symbol, DocumentationDataVariants<Variant>>,
            assertion: (Variant, Variant) -> (),
            file: StaticString = #file,
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
            file: StaticString = #file,
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
            file: StaticString = #file,
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
            populateObjCVariantAndCreateAssertion(keyPath: \.redirectsVariants),
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
}

private extension DocumentationDataVariantsTrait {
    static var objectiveC: DocumentationDataVariantsTrait { .init(interfaceLanguage: "occ") }
}

private extension Collection where Element == RenderBlockContent {
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
