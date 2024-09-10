/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import SwiftDocCTestUtilities
import Markdown
import SymbolKit

class RenderNodeTranslatorTests: XCTestCase {
    private func findDiscussion(forSymbolPath: String, configureBundle: ((URL) throws -> Void)? = nil) throws -> ContentRenderSection? {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", configureBundle: configureBundle)
        
        let node = try context.entity(with: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: forSymbolPath, sourceLanguage: .swift))
        
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: node.reference)
        let renderNode = translator.visit(node.semantic as! Symbol) as! RenderNode
        
        guard let section = renderNode.primaryContentSections.last(where: { section -> Bool in
            return section.kind == .content
        }), let discussion = section as? ContentRenderSection else {
            XCTFail("Could not find discussion")
            return nil
        }
        return discussion
    }
    
    private func findParagraph(withPrefix: String, forSymbolPath: String) throws -> [RenderInlineContent]? {
        guard let discussion = try findDiscussion(forSymbolPath: forSymbolPath) else {
            return nil
        }
        
        // In the rendered content find the link exercising paragraph
        guard let paragraph = discussion.content
            .compactMap({ block -> [RenderInlineContent]? in
                switch block {
                case .paragraph(let p): return p.inlineContent
                default: return nil
                }
            })
            .first(where: { children in
                switch children[0] {
                case .text(let string): return string.hasPrefix(withPrefix)
                default: return false
                }
            }) else {
                XCTFail("Could not find 'Exercise links to symbols' paragraph")
                return nil
            }
        
        return paragraph
    }
    
    func testResolvingSymbolLinks() throws {
        guard let paragraph = try findParagraph(withPrefix: "Exercise links to symbols", forSymbolPath: "/documentation/MyKit/MyProtocol") else {
            XCTFail("Failed to fetch test content")
            return
        }

        // Find the references to ``MyClass``
        let references = paragraph.filter { inline -> Bool in
            switch inline {
            case .reference(let identifier, let active, _, _):
                return identifier.identifier == "doc://org.swift.docc.example/documentation/MyKit/MyClass" && active
            default: return false
            }
        }
        
        // Verify that we found exactly 2 resolved references
        XCTAssertEqual(references.count, 2)
    }
    
    func testExternalSymbolLink() throws {
        guard let paragraph = try findParagraph(withPrefix: "Exercise unresolved symbols", forSymbolPath: "/documentation/MyKit/MyProtocol") else {
            XCTFail("Failed to fetch test content")
            return
        }
        
        // Find the references to ``MyClass``
        let references = paragraph.filter { inline -> Bool in
            switch inline {
            case .codeVoice(code: let text):
                return text == "MyUnresolvedSymbol"
            default: return false
            }
        }
        
        // Verify that we found exactly 1 unresolved references
        XCTAssertEqual(references.count, 1)
    }
    
    func testOrderedAndUnorderedList() throws {
        guard let discussion = try findDiscussion(forSymbolPath: "/documentation/MyKit/MyProtocol") else {
            return
        }
        
        XCTAssert(discussion.content.contains(where: { block in
            if case .orderedList(let l) = block,
                l.startIndex == 1,
                l.items.count == 3,
                l.items[0].content.first == .paragraph(.init(inlineContent: [.text("One ordered")])),
                l.items[1].content.first == .paragraph(.init(inlineContent: [.text("Two ordered")])),
                l.items[2].content.first == .paragraph(.init(inlineContent: [.text("Three ordered")]))
            {
                return true
            } else {
                return false
            }
        }))
        
        XCTAssert(discussion.content.contains(where: { block in
            if case .unorderedList(let l) = block,
                l.items.count == 3,
                l.items[0].content.first == .paragraph(.init(inlineContent: [.text("One unordered")])),
                l.items[1].content.first == .paragraph(.init(inlineContent: [.text("Two unordered")])),
                l.items[2].content.first == .paragraph(.init(inlineContent: [.text("Three unordered")]))
            {
                return true
            } else {
                return false
            }
        }))

        XCTAssert(discussion.content.contains(where: { block in
            if case .orderedList(let l) = block,
               l.startIndex == 2,
               l.items.count == 3,
               l.items[0].content.first == .paragraph(.init(inlineContent: [.text("Two ordered with custom start")])),
               l.items[1].content.first == .paragraph(.init(inlineContent: [.text("Three ordered with custom start")])),
               l.items[2].content.first == .paragraph(.init(inlineContent: [.text("Four ordered with custom start")]))
            {
                return true
            } else {
                return false
            }
        }))
    }
    
    func testAutomaticOverviewAndDiscussionHeadings() throws {
        guard let myFunctionDiscussion = try findDiscussion(forSymbolPath: "/documentation/MyKit/MyClass/myFunction()", configureBundle: { url in
            let sidecarURL = url.appendingPathComponent("/documentation/myFunction.md")
            try """
            # ``MyKit/MyClass/myFunction()``
            
            This is the overview for myFunction.
            """.write(to: sidecarURL, atomically: true, encoding: .utf8)
        }) else {
            return
        }
        
        XCTAssertEqual(
            myFunctionDiscussion.content,
            [
                RenderBlockContent.heading(.init(level: 2, text: "Discussion", anchor: "discussion")),
                RenderBlockContent.paragraph(.init(inlineContent: [.text("This is the overview for myFunction.")])),
            ]
        )
        
        guard let myClassDiscussion = try findDiscussion(forSymbolPath: "/documentation/MyKit/MyClass", configureBundle: { url in
            let sidecarURL = url.appendingPathComponent("/documentation/myclass.md")
            XCTAssert(FileManager.default.fileExists(atPath: sidecarURL.path), "Make sure that this overrides the existing file.")
            try """
            # ``MyKit/MyClass``

            This is the abstract (because MyClass doesn't have an in-source abstract).

            This is the overview for MyClass.
            """.write(to: sidecarURL, atomically: true, encoding: .utf8)
        }) else {
            return
        }

        XCTAssertEqual(
            myClassDiscussion.content,
            [
                RenderBlockContent.heading(.init(level: 2, text: "Overview", anchor: "overview")),
                RenderBlockContent.paragraph(.init(inlineContent: [.text("This is the overview for MyClass.")])),
            ]
        )
    }
    
    func testContentSectionSafeAnchor() {
        // Verify an already safe title is not altered
        do {
            let section = ContentRenderSection(kind: .content, content: [], heading: "declaration")
            XCTAssertEqual("declaration", section.content.mapFirst(where: { element -> String? in
                switch element {
                case .heading(let h): return h.anchor
                default: return nil
                }
            }))
        }
        
        // Verify mixed cased title is lowercased
        do {
            let section = ContentRenderSection(kind: .content, content: [], heading: "DeclaratioN")
            XCTAssertEqual("declaration", section.content.mapFirst(where: { element -> String? in
                switch element {
                case .heading(let h): return h.anchor
                default: return nil
                }
            }))
        }
        
        do {
            // Verify that "unsafe" title is safe-ified
            let section = ContentRenderSection(kind: .content, content: [], heading: "My Declaration")
            XCTAssertEqual("my-declaration", section.content.mapFirst(where: { element -> String? in
                switch element {
                case .heading(let h): return h.anchor
                default: return nil
                }
            }))
        }
    }
            
    func testArticleRoles() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        
        // Verify article's role
        do {
            let source = """
            # My Article
            My introduction.
            My exposé.
            My conclusion.
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let article = try XCTUnwrap(
                Article(from: document.root, source: nil, for: bundle, in: context, problems: &problems)
            )
            XCTAssertEqual(RenderMetadata.Role.article, DocumentationContentRenderer.roleForArticle(article, nodeKind: .article))
        }

        // Verify collections' role
        do {
            let source = """
            # My Article
            My introduction.
            My exposé.
            My conclusion.
            ## Topics
            ### Basics
             - <doc:MyKit>
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)

            // Verify a collection group
            let article1 = try XCTUnwrap(
                Article(from: document.root, source: nil, for: bundle, in: context, problems: &problems)
            )
            XCTAssertEqual(RenderMetadata.Role.collectionGroup, DocumentationContentRenderer.roleForArticle(article1, nodeKind: .article))
            
            let metadataSource = """
            @Metadata {
               @TechnologyRoot
            }
            """
            let metadataDocument = Document(
                parsing: source + "\n" + metadataSource,
                options: .parseBlockDirectives
            )

            // Verify a collection
            let article2 = try XCTUnwrap(
                Article(from: metadataDocument.root, source: nil, for: bundle, in: context, problems: &problems)
            )
            XCTAssertEqual(RenderMetadata.Role.collection, DocumentationContentRenderer.roleForArticle(article2, nodeKind: .article))
        }
    }
    
    // Verifies that links to sections include their container's abstract rdar://72110558
    func testSectionAbstracts() throws {
        // Create an article including a link to a tutorial section
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], configureBundle: { url in
            try """
            # Article
            Article abstract
            ## Topics
            ### Task Group
            - <doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>
            """.write(to: url.appendingPathComponent("article.md"), atomically: true, encoding: .utf8)
        })

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/article", sourceLanguage: .swift)
        let node = try context.entity(with: reference)
        let article = try XCTUnwrap(node.semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderedNode = translator.visit(article) as! RenderNode

        // Verify that the render reference to a section includes the container symbol's abstract
        let renderReference = try XCTUnwrap(renderedNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"] as? TopicRenderReference)
        XCTAssertEqual(renderReference.abstract.first?.plainText, "This is the tutorial abstract.")
    }

    func testEmptyTaskGroupsNotRendered() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        
        let source = """
            # My Article
            
            ## Topics           
                        
            ### No Topics

            -
            
            ### Links
            
            - <doc:article>

            ### Not even an empty item


            ### Bad Topics

            - text <doc:DoesNotExist>
            - <https://www.example.com>
            - <doc:ThisArticleDoesNotResolve>
            
            ### Last
            
            This task group has at least one good topic
            
            - <https://www.example.com>
            - <doc:article2>
            -
            
            """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let article = try XCTUnwrap(
            Article(from: document.root, source: nil, for: bundle, in: context, problems: &problems)
        )
        let reference = ResolvedTopicReference(bundleIdentifier: "org.swift.docc.example", path: "/documentation/Test-Bundle/taskgroups", fragment: nil, sourceLanguage: .swift)
        context.documentationCache[reference] = try DocumentationNode(reference: reference, article: article)
        let topicGraphNode = TopicGraph.Node(reference: reference, kind: .article, source: .file(url: URL(fileURLWithPath: "/path/to/article.md")), title: "My Article")
        context.topicGraph.addNode(topicGraphNode)
    
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        XCTAssertEqual(node.topicSections.count, 2)
        
        let linksGroup = try XCTUnwrap(node.topicSections.first)
        XCTAssertEqual(linksGroup.title, "Links")
        XCTAssertEqual(linksGroup.identifiers, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article",
        ])
        
        let lastGroup = try XCTUnwrap(node.topicSections.last)
        XCTAssertEqual(lastGroup.title, "Last")
        XCTAssertEqual(lastGroup.identifiers, [
            "doc://org.swift.docc.example/documentation/Test-Bundle/article2",
        ])
    }
    
    /// Tests the ordering of automatic groups for symbols
    func testAutomaticTaskGroupsOrderingInSymbols() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # ``SideKit/SideClass``
            SideClass abstract
            ## Topics
            ### Basics
             - <doc:documentation/MyKit/MyProtocol>
            """.write(to: url.appendingPathComponent("sideclass.md"), atomically: true, encoding: .utf8)
        })
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(try? context.entity(with: reference))
        
        // Test manual task groups and automatic symbol groups ordering
        do {
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

            // Verify that by default we render:
            // 1. Manually curated task group
            // 2. Automatic task groups for uncurated symbols
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
                "Enumeration Cases",
                "Initializers",
                "Instance Properties",
                "Instance Methods",
                "Type Aliases",
            ])
        }

        // Test manual task groups, automatic symbol groups ordering, and
        // automatic uncurated article groups.
        do {
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            symbol.automaticTaskGroups = [
                AutomaticTaskGroupSection(
                    title: "Articles",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .top
                ),
            ]
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

            // Verify that by default we render:
            // 1. Manually curated task group
            // 2. Automatic article groups
            // 3. Automatic task groups for uncurated symbols
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
                "Articles",
                "Enumeration Cases",
                "Initializers",
                "Instance Properties",
                "Instance Methods",
                "Type Aliases",
            ])
        }

        // Test manual task groups, automatic symbol groups ordering,
        // automatic uncurated article groups, and automatic api collections.
        do {
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            symbol.automaticTaskGroups = [
                AutomaticTaskGroupSection(
                    title: "Articles",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .top
                ),
                AutomaticTaskGroupSection(
                    title: "Default Implementations",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .bottom
                ),
                AutomaticTaskGroupSection(
                    title: "Another Task Group",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .bottom
                ),
            ]
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

            // Verify that by default we render:
            // 1. Manually curated task group
            // 2. Automatic article groups
            // 3. Automatic task groups for uncurated symbols
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
                "Articles",
                "Enumeration Cases",
                "Initializers",
                "Instance Properties",
                "Instance Methods",
                "Type Aliases",
                "Default Implementations",
                "Another Task Group",
            ])
        }
    }
    
    /// Tests the ordering of automatic groups for articles
    func testAutomaticTaskGroupsOrderingInArticles() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # Article
            Article abstract
            ## Topics
            ### Basics
             - <doc:documentation/MyKit/MyProtocol>
            """.write(to: url.appendingPathComponent("article.md"), atomically: true, encoding: .utf8)
        })
        
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Test-Bundle/article", sourceLanguage: .swift)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(try? context.entity(with: reference))
        
        // Test the manual curation task groups
        do {
            let article = try XCTUnwrap(node.semantic as? Article)
            let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

            // Verify that by default we render manually curated task groups.
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
            ])
        }

        // Test manual task groups, and automatic uncurated article groups.
        do {
            let article = try XCTUnwrap(node.semantic as? Article)
            article.automaticTaskGroups = [
                AutomaticTaskGroupSection(
                    title: "Articles",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .top
                ),
            ]
            let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

            // Verify that by default we render:
            // 1. Manually curated task group
            // 2. Automatic task groups for uncurated symbols
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
                "Articles",
            ])
        }

        // Test manual task groups, automatic symbol groups ordering,
        // automatic uncurated article groups, and automatic api collections.
        do {
            let article = try XCTUnwrap(node.semantic as? Article)
            article.automaticTaskGroups = [
                AutomaticTaskGroupSection(
                    title: "Articles",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .top
                ),
                AutomaticTaskGroupSection(
                    title: "Default Implementations",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .bottom
                ),
                AutomaticTaskGroupSection(
                    title: "Another Task Group",
                    references: [
                        ResolvedTopicReference(
                            bundleIdentifier: bundle.identifier,
                            path: "/documentation/MyKit/MyProtocol",
                            sourceLanguage: .swift
                        ),
                    ],
                    renderPositionPreference: .bottom
                ),
            ]
            let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

            // Verify that by default we render:
            // 1. Manually curated task group
            // 2. Automatic task groups for uncurated symbols
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Basics",
                "Articles",
                "Default Implementations",
                "Another Task Group",
            ])
        }
    }

    /// Tests the ordering of automatic groups in defining protocol
    func testOrderingOfAutomaticGroupsInDefiningProtocol() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            //
        })
        
        // Verify "Default Implementations" group on the implementing type
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element", sourceLanguage: .swift)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let node = try XCTUnwrap(try? context.entity(with: reference))
            
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

            // Verify that implementing type gets a "Default implementations"
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Default Implementations",
            ])
            XCTAssertEqual(renderNode.topicSections.map(\.identifiers), [
                ["doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/Protocol-Implementations"],
            ])
            
        }
        
        // Verify automatically generated api collection
        do {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass/Element/Protocol-Implementations", sourceLanguage: .swift)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let node = try XCTUnwrap(try? context.entity(with: reference))
            
            let article = try XCTUnwrap(node.semantic as? Article)
            let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

            // Verify that implementing type gets a "Default implementations"
            XCTAssertEqual(renderNode.topicSections.map(\.title), [
                "Instance Methods",
            ])
            XCTAssertEqual(renderNode.topicSections.map(\.identifiers), [
                ["doc://org.swift.docc.example/documentation/SideKit/SideClass/Element/inherited()"],
            ])
            
        }

    }

    /// Verify that symbols with ellipsis operators don't get curated into an unnamed protocol implementation section.
    func testAutomaticImplementationsWithExtraDots() throws {
        let fancyProtocolSGFURL = Bundle.module.url(
            forResource: "FancyProtocol.symbols", withExtension: "json", subdirectory: "Test Resources")!

        // Create a test bundle copy with the symbol graph from above
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: []) { url in
            try? FileManager.default.copyItem(at: fancyProtocolSGFURL, to: url.appendingPathComponent("FancyProtocol.symbols.json"))
        }

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/FancyProtocol/SomeClass", sourceLanguage: .swift)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

        let defaultImplementationSection = try XCTUnwrap(renderNode.topicSections.first(where: { $0.title == "Default Implementations" }))
        XCTAssertEqual(defaultImplementationSection.identifiers, [
            "doc://org.swift.docc.example/documentation/FancyProtocol/SomeClass/Comparable-Implementations",
            "doc://org.swift.docc.example/documentation/FancyProtocol/SomeClass/Equatable-Implementations",
            "doc://org.swift.docc.example/documentation/FancyProtocol/SomeClass/FancyProtocol-Implementations",
        ])
        let implReferences = defaultImplementationSection.identifiers.compactMap({ renderNode.references[$0] as? TopicRenderReference })
        XCTAssertEqual(implReferences.map({ $0.title }), [
            "Comparable Implementations",
            "Equatable Implementations",
            "FancyProtocol Implementations",
        ])

    }
    
    func testAutomaticImplementationsWithExtraDotsFromExternalModule() throws {
        let inheritedDefaultImplementationsFromExternalModuleSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementationsFromExternalModule.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let testBundle = try Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                CopyOfFile(original: inheritedDefaultImplementationsFromExternalModuleSGF),
            ]
        ).write(inside: createTemporaryDirectory())
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/SecondTarget/FancyProtocolConformer", in: testBundle),
            [
                "FancyProtocol Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/SecondTarget/OtherFancyProtocolConformer", in: testBundle),
            [
                "OtherFancyProtocol Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/SecondTarget/FooConformer", in: testBundle),
            [
                "Foo Implementations",
            ]
        )
    }
    
    func testAutomaticImplementationsFromCurrentModuleWithMixOfDocCoverage() throws {
        let inheritedDefaultImplementationsSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementations.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        let inheritedDefaultImplementationsAtSwiftSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementations@Swift.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let testBundle = try Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                CopyOfFile(original: inheritedDefaultImplementationsSGF),
                CopyOfFile(original: inheritedDefaultImplementationsAtSwiftSGF),
            ]
        ).write(inside: createTemporaryDirectory())
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/Bar", in: testBundle),
            [
                "Foo Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/OtherStruct", in: testBundle),
            [
                "Comparable Implementations",
                "Equatable Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/SomeStruct", in: testBundle),
            [
                "Comparable Implementations",
                "Equatable Implementations",
                "FancyProtocol Implementations",
                "OtherFancyProtocol Implementations",
            ]
        )
    }
    
    func testAutomaticImplementationsFromMultiPlatformSymbolGraphs() throws {
        let inheritedDefaultImplementationsSGF = Bundle.module.url(
            forResource: "InheritedDefaultImplementations.symbols",
            withExtension: "json",
            subdirectory: "Test Resources"
        )!
        
        let symbolGraphWithModifiedPlatform = try String(
            contentsOf: inheritedDefaultImplementationsSGF
        )
        .replacingOccurrences(
            of: """
                "architecture": "x86_64",
                """,
            with: """
                "architecture": "arm64",
                """
        )
        .replacingOccurrences(
            of: """
                "name": "macosx",
                """,
            with: """
                "name": "ios",
                """
        )
        
        let testBundle = try Folder(
            name: "unit-test.docc",
            content: [
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                Folder(
                    name: "x86_64-apple-macos",
                    content: [
                        CopyOfFile(original: inheritedDefaultImplementationsSGF),
                    ]
                ),
                Folder(
                    name: "arm64-apple-ios",
                    content: [
                        DataFile(
                            name: inheritedDefaultImplementationsSGF.lastPathComponent,
                            data: Data(symbolGraphWithModifiedPlatform.utf8)
                        ),
                    ]
                ),
            ]
        ).write(inside: createTemporaryDirectory())
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/Bar", in: testBundle),
            [
                "Foo Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/OtherStruct", in: testBundle),
            [
                "Comparable Implementations",
                "Equatable Implementations",
            ]
        )
        
        try assertDefaultImplementationCollectionTitles(
            in: try loadRenderNode(at: "/documentation/FirstTarget/SomeStruct", in: testBundle),
            [
                "Comparable Implementations",
                "Equatable Implementations",
                "FancyProtocol Implementations",
                "OtherFancyProtocol Implementations",
            ]
        )
    }
    
    func assertDefaultImplementationCollectionTitles(
        in renderNode: RenderNode,
        _ expectedTitles: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        let defaultImplementationSection = try XCTUnwrap(
            renderNode.topicSections.first(where: { $0.title == "Default Implementations" }),
            "Expected to find default implementations topic section.",
            file: file,
            line: line
        )
        
        let references = defaultImplementationSection.identifiers.compactMap { identifier in
            renderNode.references[identifier] as? TopicRenderReference
        }
        
        XCTAssertEqual(references.map(\.title), expectedTitles, file: file, line: line)
    }
    
    func loadRenderNode(at path: String, in bundleURL: URL) throws -> RenderNode {
        let (_, bundle, context) = try loadBundle(from: bundleURL)

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: path, sourceLanguage: .swift)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try context.entity(with: reference)
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        return try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
    }
    
    func testAutomaticTaskGroupTopicsAreSorted() throws {
        let (bundle, context) = try testBundleAndContext(named: "DefaultImplementations")
        let structReference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/DefaultImplementations/Foo", sourceLanguage: .swift)
        let structNode = try context.entity(with: structReference)
        let symbol = try XCTUnwrap(structNode.semantic as? Symbol)
        
        // Verify that the ordering of default implementations is deterministic
        for _ in 0..<100 {
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: structReference)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            let section = renderNode.topicSections.first(where: { $0.title == "Default Implementations" })
            XCTAssertEqual(section?.identifiers, [
                "doc://org.swift.docc.example/documentation/DefaultImplementations/Foo/A-Implementations",
                "doc://org.swift.docc.example/documentation/DefaultImplementations/Foo/B-Implementations",
                "doc://org.swift.docc.example/documentation/DefaultImplementations/Foo/C-Implementations",
            ])
        }
    }
    
    // Verifies we don't render links to non linkable nodes.
    func testNonLinkableNodes() throws {
        // Create a bundle with variety absolute and relative links and symbol links to a non linkable node.
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
            try """
            # ``SideKit/SideClass``
            Abstract.
            ## Discussion
            This is a link to <doc:/documentation/SideKit/SideClass/Element/Protocol-Implementations>.
            ## Topics
            ### Basics
             - <doc:documentation/SideKit/SideClass/Element/Protocol-Implementations>
             - ``SideKit/SideClass/Element/Protocol-Implementations``
             - ``Element/Protocol-Implementations``
            """.write(to: url.appendingPathComponent("sideclass.md"), atomically: true, encoding: .utf8)
        })

        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit/SideClass", sourceLanguage: .swift)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(try? context.entity(with: reference))
        
        let symbol = try XCTUnwrap(node.semantic as? Symbol)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)

        let discussion = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)
        let paragraph = try XCTUnwrap(discussion.content.last)

        guard case let RenderBlockContent.paragraph(p) = paragraph else {
            XCTFail("Unexpected discussion content.")
            return
        }
        
        XCTAssertEqual(p.inlineContent, [
            .text("This is a link to "),
            .text("doc:/documentation/SideKit/SideClass/Element/Protocol-Implementations"),
            .text("."),
        ])
    }
    
    // Verifies we support rendering links in abstracts.
    func testLinkInAbstract() throws {
        do {
            // First verify that `SideKit` page does not contain render reference to `SideKit/SideClass/Element`.
            let (bundle, context) = try testBundleAndContext(named: "TestBundle")
            
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            
            // No render reference to `Element`
            XCTAssertFalse(renderNode.references.keys.contains("doc://\(bundle.identifier)/documentation/SideKit/SideClass/Element"))
        }
        
        do {
            // Create a bundle with a link in abstract, then verify the render reference is present in `SideKit` render node references.
            let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle", excludingPaths: [], externalResolvers: [:], externalSymbolResolver: nil, configureBundle: { url in
                try """
                # ``SideKit/SideClass``
                This is a link to <doc:/documentation/SideKit/SideClass/Element>.
                """.write(to: url.appendingPathComponent("sideclass.md"), atomically: true, encoding: .utf8)
            })

            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/SideKit", sourceLanguage: .swift)
            let node = try context.entity(with: reference)
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let symbol = try XCTUnwrap(node.semantic as? Symbol)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            
            // There is a render reference to `Element`
            XCTAssertTrue(renderNode.references.keys.contains("doc://\(bundle.identifier)/documentation/SideKit/SideClass/Element"))
        }
    }

    func testSnippetToCodeListing() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Snippets/Snippets", sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let discussion = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)
        
        if case let .paragraph(p) = discussion.content.dropFirst(2).first {
            XCTAssertEqual(p.inlineContent, [.text("Does a foo.")])
        } else {
            XCTFail("Unexpected content where snippet explanation should be.")
        }

        if case let .codeListing(l) = discussion.content.dropFirst(3).first {
            XCTAssertEqual(l.syntax, "swift")
            XCTAssertEqual(l.code.joined(separator: "\n"), """
                func foo() {}
                
                do {
                  middle()
                }
                
                func bar() {}
                """)
        } else {
            XCTFail("Missing snippet code block")
        }
    }
    
    func testSnippetSliceToCodeListing() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Snippets/Snippets", sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let discussion = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)
        
        let lastCodeListingIndex = try XCTUnwrap(discussion.content.indices.last {
            guard case .codeListing = discussion.content[$0] else {
                return false
            }
            return true
        })

        guard case let .codeListing(l) = discussion.content[lastCodeListingIndex] else {
            XCTFail("Missing snippet slice code block")
            return
        }

        XCTAssertEqual(l.syntax, "swift")
        XCTAssertEqual(l.code, ["func foo() {}"])
    }

    func testNestedSnippetSliceToCodeListing() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Snippets/Snippets", sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let discussion = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)

        let lastTabNavigator = try XCTUnwrap(discussion.content.indices.last {
            guard case .tabNavigator = discussion.content[$0] else {
                return false
            }
            return true
        })

        guard case let .tabNavigator(t) = discussion.content[lastTabNavigator] else {
            XCTFail("Missing snippet slice code block")
            return
        }

        let codeListing = t.tabs.last?.content.last

        guard case let .codeListing(l) = codeListing else {
            XCTFail("Missing nested snippet inside TabNavigator")
            return
        }

        XCTAssertEqual(l.syntax, "swift")
        XCTAssertEqual(l.code, ["middle()"])
    }
    
    func testSnippetSliceTrimsIndentation() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/documentation/Snippets/SliceIndentation", sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        let discussion = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0.kind == .content }) as? ContentRenderSection)
        
        let lastCodeListingIndex = try XCTUnwrap(discussion.content.indices.last {
            guard case .codeListing = discussion.content[$0] else {
                return false
            }
            return true
        })

        guard case let .codeListing(l) = discussion.content[lastCodeListingIndex] else {
            XCTFail("Missing snippet slice code block")
            return
        }

        XCTAssertEqual(l.syntax, "swift")
        XCTAssertEqual(l.code, ["middle()"])

    }
    
    func testRowAndColumn() throws {
        let (bundle, context) = try testBundleAndContext(named: "BookLikeContent")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/BestBook/MyArticle",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        
        let discussion = try XCTUnwrap(
            renderNode.primaryContentSections.first(
                where: { $0.kind == .content }
            ) as? ContentRenderSection
        )
        
        guard case let .row(row) = discussion.content.dropFirst().first else {
            XCTFail("Expected to find row as first child.")
            return
        }
        
        XCTAssertEqual(row.numberOfColumns, 8)
        XCTAssertEqual(row.columns.first?.size, 3)
        XCTAssertEqual(row.columns.first?.content.count, 1)
        XCTAssertEqual(row.columns.last?.size, 5)
        XCTAssertEqual(row.columns.last?.content.count, 3)
    }
    
    func testSmall() throws {
        let (bundle, context) = try testBundleAndContext(named: "BookLikeContent")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/BestBook/MyArticle",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        
        let discussion = try XCTUnwrap(
            renderNode.primaryContentSections.first(
                where: { $0.kind == .content }
            ) as? ContentRenderSection
        )
        
        guard case let .small(small) = discussion.content.last else {
            XCTFail("Expected to find small as last child.")
            return
        }
        
        XCTAssertEqual(
            small.inlineContent,
            [.text("Copyright (c) 2022 Apple Inc and the Swift Project authors. All Rights Reserved.")]
        )
    }
    
    func testTabNavigator() throws {
        let (bundle, context) = try testBundleAndContext(named: "BookLikeContent")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/BestBook/TabNavigatorArticle",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
        
        let discussion = try XCTUnwrap(
            renderNode.primaryContentSections.first(
                where: { $0.kind == .content }
            ) as? ContentRenderSection
        )
        
        guard case let .tabNavigator(tabNavigator) = discussion.content.dropFirst().first else {
            XCTFail("Expected to find tab as first child.")
            return
        }
        

        guard tabNavigator.tabs.count == 3 else {
            XCTFail("Expected to find a tab navigator with '3' tabs")
            return
        }
        
        XCTAssertEqual(tabNavigator.tabs[0].title, "Powers")
        XCTAssertEqual(tabNavigator.tabs[1].title, "Exercise routines")
        XCTAssertEqual(tabNavigator.tabs[2].title, "Hats")
        
        XCTAssertEqual(tabNavigator.tabs[0].content.count, 1)
        XCTAssertEqual(tabNavigator.tabs[1].content.count, 2)
        XCTAssertEqual(tabNavigator.tabs[2].content.count, 1)
    }
    
    func testRenderNodeMetadata() throws {
         let (bundle, context) = try testBundleAndContext(named: "BookLikeContent")
         let reference = ResolvedTopicReference(
             bundleIdentifier: bundle.identifier,
             path: "/documentation/BestBook/MyArticle",
             sourceLanguage: .swift
         )
         let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
         var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
         let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
    
         let encodedArticle = try JSONEncoder().encode(renderNode)
         let roundTrippedArticle = try JSONDecoder().decode(RenderNode.self, from: encodedArticle)
    
         XCTAssertEqual(roundTrippedArticle.icon?.identifier, "plus.svg")

         XCTAssertEqual(renderNode.metadata.customMetadata.count, 1)
         XCTAssertEqual(
             roundTrippedArticle.references["figure1.png"] as? ImageReference,
             ImageReference(
                 identifier: RenderReferenceIdentifier("figure1.png"),
                 imageAsset: DataAsset(
                     variants: [
                         DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard)
                             : URL(string: "/images/figure1.png")!,
    
                         DataTraitCollection(userInterfaceStyle: .dark, displayScale: .standard)
                             : URL(string: "/images/figure1~dark.png")!,
                     ],
                     metadata: [
                         URL(string: "/images/figure1.png")! : DataAsset.Metadata(),
                         URL(string: "/images/figure1~dark.png")! : DataAsset.Metadata(),
                     ]
                 )
             )
         )
    
         XCTAssertEqual(
             roundTrippedArticle.references["plus.svg"] as? ImageReference,
             ImageReference(
                 identifier: RenderReferenceIdentifier("plus.svg"),
                 imageAsset: DataAsset(
                     variants: [
                         DataTraitCollection(userInterfaceStyle: .light, displayScale: .standard)
                             : URL(string: "/images/plus.svg")!,
                     ],
                     metadata: [
                         URL(string: "/images/plus.svg")! : DataAsset.Metadata(svgID: "plus-id"),
                     ]
                 )
             )
         )
    
         XCTAssertEqual(
             Set(roundTrippedArticle.metadata.images),
             [
                 TopicImage(type: .icon, identifier: RenderReferenceIdentifier("plus.svg")),
                 TopicImage(type: .card, identifier: RenderReferenceIdentifier("figure1.png"))
             ]
         )

        XCTAssertEqual(roundTrippedArticle.metadata.customMetadata.count, 1)
        XCTAssertEqual(roundTrippedArticle.metadata.customMetadata.keys.count, 1)
        XCTAssertEqual(roundTrippedArticle.metadata.customMetadata.keys.first, "country")
        XCTAssertEqual(roundTrippedArticle.metadata.customMetadata.values.count, 1)
        XCTAssertEqual(roundTrippedArticle.metadata.customMetadata.values.first, "Belgium")
        
        XCTAssertEqual(
            roundTrippedArticle.metadata.color?.standardColorIdentifier,
            "yellow"
        )

        XCTAssertEqual(roundTrippedArticle.metadata.roleHeading, "Book-Like Content")
        XCTAssertEqual(roundTrippedArticle.metadata.role, "article")
     }
    
    func testPageColorMetadataInSymbolExtension() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedManualAutomaticCuration")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/TestBed",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
   
        let encodedSymbol = try JSONEncoder().encode(renderNode)
        let roundTrippedSymbol = try JSONDecoder().decode(RenderNode.self, from: encodedSymbol)
        XCTAssertEqual(roundTrippedSymbol.metadata.color?.standardColorIdentifier, "purple")
    }

    func testTitleHeadingMetadataInSymbolExtension() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedManualAutomaticCuration")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/TestBed",
            sourceLanguage: .swift
        )
        let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Symbol)
        var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
   
        let encodedSymbol = try JSONEncoder().encode(renderNode)
        let roundTrippedSymbol = try JSONDecoder().decode(RenderNode.self, from: encodedSymbol)
        XCTAssertEqual(roundTrippedSymbol.metadata.roleHeading, "TestBed Notes")
        XCTAssertEqual(roundTrippedSymbol.metadata.role, "collection")
    }
    
    func testExpectedRoleHeadingIsAssigned() throws {
        let exampleDocumentation = Folder(
            name: "unit-test.docc",
            content: [
                TextFile(name: "APICollection.md", utf8Content: """
                # API Collection
                My API Collection Abstract.
                ## Topics
                - ``Symbol``
                - <doc:article2>
                - <doc:article3>
                """),
                TextFile(name: "Collection.md", utf8Content: """
                # Collection
                An abstract with a symbol link: ``MyKit/MyProtocol``
                ## Overview
                An overview with a symbol link: ``MyKit/MyProtocol``
                ## Topics
                A topic group abstract with a symbol link: ``MyKit/MyProtocol``
                - <doc:article4>
                - <doc:article5>
                """),
                TextFile(name: "Article.md", utf8Content: """
                # Article
                My Article Abstract.
                ## Overview
                An overview.
                """),
                TextFile(name: "CustomRole.md", utf8Content: """
                # Article 4
                @Metadata {
                    @TitleHeading("Custom Role")
                }
                My Article Abstract.
                ## Overview
                An overview.
                """),
                TextFile(name: "SampleCode.md", utf8Content: """
                # Sample Code
                @Metadata {
                    @PageKind(sampleCode)
                }
                ## Topics
                - <doc:article>
                """),
                JSONFile(
                    name: "unit-test.symbols.json",
                    content: makeSymbolGraph(
                        moduleName: "unit-test",
                        symbols: [SymbolGraph.Symbol(
                            identifier: .init(precise: "symbol-id", interfaceLanguage: "swift"),
                            names: .init(title: "Symbol", navigator: nil, subHeading: nil, prose: nil),
                            pathComponents: ["Symbol"],
                            docComment: nil,
                            accessLevel: .public,
                            kind: .init(parsedIdentifier: .class, displayName: "Kind Display Name"),
                            mixins: [:]
                        )]
                    )
                ),
            ]
        )
        let tempURL = try createTempFolder(content: [exampleDocumentation])
        let (_, bundle, context) = try loadBundle(from: tempURL)

        func renderNodeArticleFromReferencePath(
            referencePath: String
        ) throws -> RenderNode {
            let reference = ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: referencePath, sourceLanguage: .swift)
            let symbol = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            return try XCTUnwrap(translator.visitArticle(symbol) as? RenderNode)
        }
        
        // Assert that articles that curates any symbol gets 'API Collection' assigned as the eyebrow title.
        var renderNode = try renderNodeArticleFromReferencePath(referencePath: "/documentation/unit-test/APICollection")
        XCTAssertEqual(renderNode.metadata.roleHeading, "API Collection")
        // Assert that articles that curates only other articles don't get any value assigned as the eyebrow title.
        renderNode = try renderNodeArticleFromReferencePath(referencePath: "/documentation/unit-test/Collection")
        XCTAssertEqual(renderNode.metadata.roleHeading, nil)
        // Assert that articles that don't curate anything else get 'Article' assigned as the eyebrow title.
        renderNode = try renderNodeArticleFromReferencePath(referencePath: "/documentation/unit-test/Article")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Article")
        // Assert that articles that have a custom title heading the eyebrow title assigned properly.
        renderNode = try renderNodeArticleFromReferencePath(referencePath: "/documentation/unit-test/CustomRole")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Custom Role")
        // Assert that articles that have a custom page kind the eyebrow title assigned properly.
        renderNode = try renderNodeArticleFromReferencePath(referencePath: "/documentation/unit-test/SampleCode")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Sample Code")
    }

    func testEncodesOverloadsInRenderNode() throws {
        enableFeatureFlag(\.isExperimentalOverloadedSymbolPresentationEnabled)

        let (bundle, context) = try testBundleAndContext(named: "OverloadedSymbols")
        
        let overloadPreciseIdentifiers = ["s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSiF",
                                   "s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSfF",
                                   "s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSSF",
                                   "s:8ShapeKit14OverloadedEnumO19firstTestMemberNameyS2dF",
                                   "s:8ShapeKit14OverloadedEnumO19firstTestMemberNameySdSaySdGF"]
        
        let overloadReferences = try overloadPreciseIdentifiers.map { try XCTUnwrap(context.documentationCache.reference(symbolID: $0)) }
        
        for (index, reference) in overloadReferences.indexed() {
            let documentationNode = try context.entity(with: reference)
            
            var translator = RenderNodeTranslator(context: context, bundle: bundle, identifier: reference)
            let symbol = try XCTUnwrap(documentationNode.semantic as? Symbol)
            let renderNode = try XCTUnwrap(translator.visitSymbol(symbol) as? RenderNode)
            
            let declarationSection = try XCTUnwrap(renderNode.primaryContentSections.first(where: { $0 is DeclarationsRenderSection }) as? DeclarationsRenderSection)
            
            // Each render node should contain declarations for all of its sibling overloads.
            let otherDeclarations = try XCTUnwrap(declarationSection.declarations.first?.otherDeclarations)
            XCTAssertEqual(otherDeclarations.declarations.count, overloadPreciseIdentifiers.count - 1)
            
            for declaration in otherDeclarations.declarations {
                XCTAssertNotNil(declaration.tokens)
            }
            
            for (otherIndex, otherReference) in overloadReferences.indexed() where otherIndex != index {
                XCTAssertTrue(otherDeclarations.declarations.contains(where: { $0.identifier == otherReference.absoluteString }))

                XCTAssert(renderNode.references.keys.contains(otherReference.absoluteString))
            }
        }
    }
}
