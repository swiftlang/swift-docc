/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities
import Markdown

class DocumentationCuratorTests: XCTestCase {
    fileprivate struct ParentChild: Hashable, Equatable {
        let parent: String
        let child: String
        
        init(_ parent: String, _ child: String) {
            self.parent = parent
            self.child = child
        }
    }
    
    func testCrawl() throws {
        let (bundle, context) = try testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        var crawler = DocumentationCurator.init(in: context, bundle: bundle)
        let mykit = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift))

        var symbolsWithCustomCuration = [ResolvedTopicReference]()
        var curatedRelationships = [ParentChild]()
        
        XCTAssertNoThrow(
            try crawler.crawlChildren(of: mykit.reference,
                prepareForCuration: { reference in
                    symbolsWithCustomCuration.append(reference)
                },
                relateNodes: { (parent, child) in
                    curatedRelationships.append(ParentChild(parent.absoluteString, child.absoluteString))
                }
            )
        )

        let sortedPairs = Set(curatedRelationships).sorted(by: { (lhs, rhs) -> Bool in
            if lhs.parent == rhs.parent {
                return lhs.child < rhs.child
            }
            return lhs.parent < rhs.parent
        })

        XCTAssertEqual(
            sortedPairs, [
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyClass"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/SideKit/UncuratedClass/angle"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/Test-Bundle/Default-Code-Listing-Syntax"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/Test-Bundle/article"),
                ("doc://org.swift.docc.example/documentation/MyKit", "doc://org.swift.docc.example/documentation/Test-Bundle/article2"),
                ("doc://org.swift.docc.example/documentation/MyKit/MyClass", "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-33vaw"),
                ("doc://org.swift.docc.example/documentation/MyKit/MyClass", "doc://org.swift.docc.example/documentation/MyKit/MyClass/init()-3743d"),
                ("doc://org.swift.docc.example/documentation/MyKit/MyClass", "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()"),
                ("doc://org.swift.docc.example/documentation/MyKit/MyProtocol", "doc://org.swift.docc.example/documentation/MyKit/MyClass"),
                ("doc://org.swift.docc.example/documentation/Test-Bundle/article", "doc://org.swift.docc.example/documentation/Test-Bundle/article2"),
                ("doc://org.swift.docc.example/documentation/Test-Bundle/article", "doc://org.swift.docc.example/documentation/Test-Bundle/article3"),
                ("doc://org.swift.docc.example/documentation/Test-Bundle/article", "doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial"),
            ].map { ParentChild($0.0, $0.1) }
        )
    }
    
    func testCrawlDiagnostics() throws {
        let (tempCatalogURL, bundle, context) = try testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests") { url in
            let extensionFile = url.appendingPathComponent("documentation/myfunction.md")
            
            try """
            # ``MyKit/MyClass/myFunction()``
            
            myFunction abstract.
            
            ## Topics
            
            ### Invalid curation
            
            A few different curations that should each result in warnings.
            The first is a reference to the parent, the second is a reference to self, and the last is an unresolved reference.
            
             - ``MyKit``
             - ``myFunction()``
             - ``UnknownSymbol``
            """.write(to: extensionFile, atomically: true, encoding: .utf8)
        }
        let extensionFile = tempCatalogURL.appendingPathComponent("documentation/myfunction.md")
        
        var crawler = DocumentationCurator(in: context, bundle: bundle)
        let mykit = try context.entity(with: ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift))
        
        XCTAssertNoThrow(try crawler.crawlChildren(of: mykit.reference, prepareForCuration: { _ in }, relateNodes: { _, _ in }))
        
        let myClassProblems = crawler.problems.filter({ $0.diagnostic.source?.standardizedFileURL == extensionFile.standardizedFileURL })
        XCTAssertEqual(myClassProblems.count, 2)
        
        let moduleCurationProblem = myClassProblems.first(where: { $0.diagnostic.identifier == "org.swift.docc.ModuleCuration" })
        XCTAssertNotNil(moduleCurationProblem)
        XCTAssertNotNil(moduleCurationProblem?.diagnostic.source, "This diagnostics should have a source")
        XCTAssertEqual(
            moduleCurationProblem?.diagnostic.range,
            SourceLocation(line: 12, column: 4, source: moduleCurationProblem?.diagnostic.source)..<SourceLocation(line: 12, column: 13, source: moduleCurationProblem?.diagnostic.source)
        )
        XCTAssertEqual(
            moduleCurationProblem?.diagnostic.summary,
            "Organizing the module 'MyKit' under 'MyKit/MyClass/myFunction()' isn't allowed"
        )
        XCTAssertEqual(moduleCurationProblem?.diagnostic.explanation, """
            Links in a "Topics section" are used to organize documentation into a hierarchy. Modules should be roots in the documentation hierarchy.
            """)
        
        let cyclicReferenceProblem = myClassProblems.first(where: { $0.diagnostic.identifier == "org.swift.docc.CyclicReference" })
        XCTAssertNotNil(cyclicReferenceProblem)
        XCTAssertNotNil(cyclicReferenceProblem?.diagnostic.source, "This diagnostics should have a source")
        XCTAssertEqual(
            cyclicReferenceProblem?.diagnostic.range,
            SourceLocation(line: 13, column: 4, source: moduleCurationProblem?.diagnostic.source)..<SourceLocation(line: 13, column: 20, source: moduleCurationProblem?.diagnostic.source)
        )
        XCTAssertEqual(
            cyclicReferenceProblem?.diagnostic.summary,
            "Organizing 'MyKit/MyClass/myFunction()' under itself forms a cycle"
        )
        XCTAssertEqual(cyclicReferenceProblem?.diagnostic.explanation, """
            Links in a "Topics section" are used to organize documentation into a hierarchy. The documentation hierarchy shouldn't contain cycles.
            """)
    }
    
    func testCyclicCurationDiagnostic() throws {
        let (_, context) = try loadBundle(catalog:
            Folder(name: "unit-test.docc", content: [
                // A number of articles with this cyclic curation:
                //
                // Root──▶First──▶Second──▶Third─┐
                //          ▲                    │
                //          └────────────────────┘
                TextFile(name: "Root.md", utf8Content: """
                # Root
                
                @Metadata {
                  @TechnologyRoot
                }
                
                Curate the first article
                
                ## Topics
                - <doc:First>
                """),
                
                TextFile(name: "First.md", utf8Content: """
                # First
                
                Curate the second article
                
                ## Topics
                - <doc:Second>
                """),
                
                TextFile(name: "Second.md", utf8Content: """
                # Second
                
                Curate the third article
                
                ## Topics
                - <doc:Third>
                """),
                
                TextFile(name: "Third.md", utf8Content: """
                # Third
                
                Form a cycle by curating the first article
                ## Topics
                - <doc:First>
                """),
            ])
        )
        
        XCTAssertEqual(context.problems.map(\.diagnostic.identifier), ["org.swift.docc.CyclicReference"])
        let curationProblem = try XCTUnwrap(context.problems.first)
        
        XCTAssertEqual(curationProblem.diagnostic.source?.lastPathComponent, "Third.md")
        XCTAssertEqual(curationProblem.diagnostic.summary, "Organizing 'unit-test/First' under 'unit-test/Third' forms a cycle")
        
        XCTAssertEqual(curationProblem.diagnostic.explanation, """
            Links in a "Topics section" are used to organize documentation into a hierarchy. The documentation hierarchy shouldn't contain cycles.
            If this link contributed to the documentation hierarchy it would introduce this cycle:
            ╭─▶︎ Third ─▶︎ First ─▶︎ Second ─╮
            ╰─────────────────────────────╯
            """)
        
        XCTAssertEqual(curationProblem.possibleSolutions.map(\.summary), ["Remove '- <doc:First>'"])
    }
    
    func testModuleUnderTechnologyRoot() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "SourceLocations") { url in
            try """
            # Root curating a module

            @Metadata {
               @TechnologyRoot
            }
            
            Curating a module from a technology root should not generated any warnings.
            
            ## Topics
            
            - ``SourceLocations``
            
            """.write(to: url.appendingPathComponent("Root.md"), atomically: true, encoding: .utf8)
        }
        
        let crawler = DocumentationCurator.init(in: context, bundle: bundle)
        XCTAssert(context.problems.isEmpty, "Expected no problems. Found: \(context.problems.map(\.diagnostic.summary))")
        
        guard let moduleNode = context.documentationCache["SourceLocations"],
              let pathToRoot = context.finitePaths(to: moduleNode.reference).first,
              let root = pathToRoot.first else {
            
            XCTFail("Module doesn't have technology root as a predecessor in its path")
            return
        }
        
        XCTAssertEqual(root.path, "/documentation/Root")
        XCTAssertEqual(crawler.problems.count, 0)
            
    }
        
    func testModuleUnderAncestorOfTechnologyRoot() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "SourceLocations") { url in
            try """
            # Root with ancestor curating a module
            
            This is a root article that enables testing the behavior of it's ancestors.
            
            @Metadata {
               @TechnologyRoot
            }
            
            ## Topics
            - <doc:Ancestor>
            
            
            """.write(to: url.appendingPathComponent("Root.md"), atomically: true, encoding: .utf8)
            
            try """
            # Ancestor of root
            
            Linking to a module shouldn't raise errors due to this article being an ancestor of a technology root.

            ## Topics
            - ``SourceLocations``

            """.write(to: url.appendingPathComponent("Ancestor.md"), atomically: true, encoding: .utf8)
        }
        
        let _ = DocumentationCurator.init(in: context, bundle: bundle)
        XCTAssert(context.problems.isEmpty, "Expected no problems. Found: \(context.problems.map(\.diagnostic.summary))")
        
        guard let moduleNode = context.documentationCache["SourceLocations"],
              let pathToRoot = context.shortestFinitePath(to: moduleNode.reference),
              let root = pathToRoot.first else {
            
            XCTFail("Module doesn't have technology root as a predecessor in its path")
            return
        }
        
        XCTAssertEqual(root.path, "/documentation/Root")
    }

    func testSymbolLinkResolving() throws {
        let (bundle, context) = try testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        let crawler = DocumentationCurator.init(in: context, bundle: bundle)
        
        // Resolve top-level symbol in module parent
        do {
            let symbolLink = SymbolLink(destination: "MyClass")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let reference = crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent)
            XCTAssertEqual(reference?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass")
        }
        
        // Resolve top-level symbol in self
        do {
            let symbolLink = SymbolLink(destination: "MyClass")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
            let reference = crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent)
            XCTAssertEqual(reference?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass")
        }

        // Resolve top-level symbol in a child
        do {
            let symbolLink = SymbolLink(destination: "MyClass")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit/MyClass/myFunction()", sourceLanguage: .swift)
            let reference = crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent)
            XCTAssertEqual(reference?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass")
        }

        // Resolve child in its parent
        do {
            let symbolLink = SymbolLink(destination: "myFunction()")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
            let reference = crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent)
            XCTAssertEqual(reference?.absoluteString, "doc://org.swift.docc.example/documentation/MyKit/MyClass/myFunction()")
        }

        // Do not resolve when not found
        do {
            let symbolLink = SymbolLink(destination: "myFunction")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            let reference = crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent)
            XCTAssertEqual(reference?.absoluteString, nil)
        }

        // Fail to resolve across modules
        do {
            let symbolLink = SymbolLink(destination: "MyClass")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift)
            XCTAssertNil(crawler.referenceFromSymbolLink(link: symbolLink, resolved: parent))
        }
    }
    
    func testLinkResolving() throws {
        let (sourceRoot, bundle, context) = try testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        
        var crawler = DocumentationCurator.init(in: context, bundle: bundle)
        
        // Resolve and curate an article in module root (absolute link)
        do {
            let link = Link(destination: "doc:article")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            guard let reference = crawler.referenceFromLink(link: link, resolved: parent, source: sourceRoot) else {
                XCTFail("Did not resolve reference from link")
                return
            }
            XCTAssertEqual(reference.absoluteString, "doc://org.swift.docc.example/documentation/Test-Bundle/article")
            
            // Verify the curated article is moved in the documentation cache
            XCTAssertNotNil(try context.entity(with: reference))
        }

        // Resolve/curate an article in module root (relative link)
        do {
            let link = Link(destination: "doc:article")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", sourceLanguage: .swift)
            guard let reference = crawler.referenceFromLink(link: link, resolved: parent, source: sourceRoot) else {
                XCTFail("Did not resolve reference from link")
                return
            }
            XCTAssertEqual(reference.absoluteString, "doc://org.swift.docc.example/documentation/Test-Bundle/article")
            
            // Verify the curated article is moved in the documentation cache
            XCTAssertNotNil(try context.entity(with: reference))
        }

        // Resolve/curate article in the module root from within a child symbol
        do {
            let link = Link(destination: "doc:article")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit/MyClass", sourceLanguage: .swift)
            guard let reference = crawler.referenceFromLink(link: link, resolved: parent, source: sourceRoot) else {
                XCTFail("Did not resolve reference from link")
                return
            }
            XCTAssertEqual(reference.absoluteString, "doc://org.swift.docc.example/documentation/Test-Bundle/article")
            
            // Verify the curated article is moved in the documentation cache
            XCTAssertNotNil(try context.entity(with: reference))
        }
        
        // Resolve/curate absolute link from a different module parent
        do {
            let link = Link(destination: "doc:documentation/Test-Bundle/article")
            let parent = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit/SideClass", sourceLanguage: .swift)
            XCTAssertNotNil(crawler.referenceFromLink(link: link, resolved: parent, source: sourceRoot))
        }
    }
    
    func testGroupLinkValidation() throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "LegacyBundle_DoNotUseInNewTests", excludingPaths: []) { root in
            // Create a sidecar with invalid group links
            try! """
            # ``SideKit``
            ## Topics
            ### Basics
            - <doc:api-collection>
            - <doc:MyKit>
            - <doc:MyKit
            ### Advanced
            - <doc:MyKit/MyClass>
            - ![](featured.png)
            ### Extraneous list item content
            - <doc:MyKit/MyClass>.
            - <doc:MyKit/MyClass> ![](featured.png) and *more* content...
            - <doc:MyKit/MyClass> @Comment { We (unfortunately) expect a warning here because DocC doesn't support directives in the middle of a line. }
            - <doc:MyKit/MyClass>   <!-- This is a valid comment -->
            - <doc:MyKit/MyClass> <!-- This is a valid comment --> but this is extra content :(
            - <doc:MyKit/MyClass> This is extra content <!-- even if this is a valid comment -->
            ## See Also
            - <doc:MyKit/MyClass>
            - Blip blop!
            """.write(to: root.appendingPathComponent("documentation").appendingPathComponent("sidekit.md"), atomically: true, encoding: .utf8)

            // Create an api collection article with invalid group links
            try! """
            # My API Collection
            ## Topics
            ### Basics
            - <doc:MyKit>
            - <doc:MyKit
            ### Advanced
            - <doc:MyKit/MyClass>
            - ![](featured.png)
            ## See Also
            - <doc:MyKit/MyClass>
            - Blip blop!
            """.write(to: root.appendingPathComponent("documentation").appendingPathComponent("api-collection.md"), atomically: true, encoding: .utf8)
        }
        
        var crawler = DocumentationCurator.init(in: context, bundle: bundle)
        let reference = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/SideKit", sourceLanguage: .swift)
        
        try crawler.crawlChildren(of: reference, prepareForCuration: {_ in }) { (_, _) in }

        // Verify the crawler emitted warnings for the 3 invalid links in the sidekit Topics/See Alsos groups
        // in both the sidecar and the api collection article
        XCTAssertEqual(crawler.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.UnexpectedTaskGroupItem" }).count, 6)
        XCTAssertTrue(crawler.problems
            .filter({ $0.diagnostic.identifier == "org.swift.docc.UnexpectedTaskGroupItem" })
            .compactMap({ $0.diagnostic.source?.path })
            .allSatisfy({ $0.hasSuffix("documentation/sidekit.md") || $0.hasSuffix("documentation/api-collection.md") })
        )
        // Verify we emit a fix-it to remove the non link items
        XCTAssertTrue(crawler.problems
            .filter({ $0.diagnostic.identifier == "org.swift.docc.UnexpectedTaskGroupItem" })
            .allSatisfy({ $0.possibleSolutions.first?.replacements.first?.replacement == "" })
        )
        // Verify we emit the correct ranges
        XCTAssertEqual(
            crawler.problems
                .filter({ $0.diagnostic.identifier == "org.swift.docc.UnexpectedTaskGroupItem" })
                .compactMap({ $0.possibleSolutions.first?.replacements.first?.range })
                .map({ "\($0.lowerBound.line):\($0.lowerBound.column)..<\($0.upperBound.line):\($0.upperBound.column)" }),
            ["6:1..<6:13", "9:1..<9:20", "19:1..<19:13", "5:1..<5:13", "8:1..<8:20", "11:1..<11:13"]
        )
        
        // Verify the crawler emitted warnings for the 5 items with trailing content.
        XCTAssertEqual(crawler.problems.filter({ $0.diagnostic.identifier == "org.swift.docc.ExtraneousTaskGroupItemContent" }).count, 5)
        XCTAssertTrue(crawler.problems
            .filter({ $0.diagnostic.identifier == "org.swift.docc.ExtraneousTaskGroupItemContent" })
            .compactMap({ $0.diagnostic.source?.path })
            .allSatisfy({ $0.hasSuffix("documentation/sidekit.md") })
        )

        // Verify we emit a fix-it to remove the trailing content
        XCTAssertTrue(crawler.problems
            .filter({ $0.diagnostic.identifier == "org.swift.docc.ExtraneousTaskGroupItemContent" })
            .allSatisfy({ $0.possibleSolutions.first != nil })
        )
    }
    
    /// This test verifies that when the manual curation is mixed with automatic and then manual again
    /// we do crawl all of the nodes in the source bundle.
    ///
    /// We specifically test this scenario in the "MixedManualAutomaticCuration.docc" test bundle:
    /// ```
    /// Framework
    ///  +-- TopClass (Manually curated)
    ///    +-- NestedEnum (Automatically curated)
    ///      +-- SecondLevelNesting (Manually curated)
    ///        +-- MyArticle ( <--- This should be crawled even if we've mixed manual and automatic curation)
    /// ```
    func testMixedManualAndAutomaticCuration() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedManualAutomaticCuration")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/TestBed/TopClass/NestedEnum/SecondLevelNesting", sourceLanguage: .swift)
        let entity = try context.entity(with: reference)
        let symbol = try XCTUnwrap(entity.semantic as? Symbol)
        
        // Verify the link was resolved and it's found in the node's topics task group.
        XCTAssertEqual("doc://com.test.TestBed/documentation/TestBed/MyArticle", symbol.topics?.taskGroups.first?.links.first?.destination)
        
        let converter = DocumentationNodeConverter(bundle: bundle, context: context)
        let renderNode = converter.convert(entity)
        
        // Verify the article identifier is included in the task group for the render node.
        XCTAssertEqual("doc://com.test.TestBed/documentation/TestBed/MyArticle", renderNode.topicSections.first?.identifiers.first)
        
        // Verify that the ONLY curation for `TopClass/name` is the manual curation under `MyArticle`
        // and the automatic curation under `TopClass` is not present.
        let nameReference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/TestBed/TopClass/name", sourceLanguage: .swift)
        XCTAssertEqual(context.finitePaths(to: nameReference).map({ $0.map(\.path) }), [
            ["/documentation/TestBed", "/documentation/TestBed/TopClass", "/documentation/TestBed/TopClass-API-Collection"],
            ["/documentation/TestBed", "/documentation/TestBed/TopClass", "/documentation/TestBed/TopClass/NestedEnum", "/documentation/TestBed/TopClass/NestedEnum/SecondLevelNesting", "/documentation/TestBed/MyArticle"],
        ])

        // Verify that the BOTH manual curations for `TopClass/age` are preserved
        // even if one of the manual curations overlaps with the inheritance edge from the symbol graph.
        let ageReference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/TestBed/TopClass/age", sourceLanguage: .swift)
        XCTAssertEqual(context.finitePaths(to: ageReference).map({ $0.map(\.path) }), [
            ["/documentation/TestBed", "/documentation/TestBed/TopClass"],
            ["/documentation/TestBed", "/documentation/TestBed/TopClass", "/documentation/TestBed/TopClass-API-Collection"],
            ["/documentation/TestBed", "/documentation/TestBed/TopClass", "/documentation/TestBed/TopClass/NestedEnum", "/documentation/TestBed/TopClass/NestedEnum/SecondLevelNesting", "/documentation/TestBed/MyArticle"],
        ])
    }
    
    /// In case a symbol has automatically curated children and is manually curated multiple times,
    /// the hierarchy should be created as it's authored. rdar://75453839
    func testMultipleManualCurationIsPreserved() throws {
        let (bundle, context) = try testBundleAndContext(named: "MixedManualAutomaticCuration")
        
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/TestBed/DoublyManuallyCuratedClass/type()", sourceLanguage: .swift)
        
        XCTAssertEqual(context.finitePaths(to: reference).map({ $0.map({ $0.path }) }), [
            [
                "/documentation/TestBed",
                "/documentation/TestBed/TopClass",
                "/documentation/TestBed/TopClass/NestedEnum",
                "/documentation/TestBed/TopClass/NestedEnum/SecondLevelNesting",
                "/documentation/TestBed/MyArticle",
                "/documentation/TestBed/NestedArticle",
                "/documentation/TestBed/DoublyManuallyCuratedClass",
            ],
            [
                "/documentation/TestBed",
                "/documentation/TestBed/TopClass",
                "/documentation/TestBed/TopClass/NestedEnum",
                "/documentation/TestBed/TopClass/NestedEnum/SecondLevelNesting",
                "/documentation/TestBed/MyArticle",
                "/documentation/TestBed/NestedArticle",
                "/documentation/TestBed/SecondArticle",
                "/documentation/TestBed/DoublyManuallyCuratedClass",
            ],
        ])
    }
}
