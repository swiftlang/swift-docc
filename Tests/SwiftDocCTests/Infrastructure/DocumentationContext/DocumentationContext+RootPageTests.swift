/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon
import Markdown

class DocumentationContext_RootPageTests: XCTestCase {
    func testArticleOnlyCatalogWithExplicitTechnologyRoot() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "no-sgf-test.docc", content: [
                // Root page for the collection
                TextFile(name: "ReleaseNotes.md", utf8Content: """
                # Release Notes
                @Metadata {
                   @TechnologyRoot
                }
                Learn about recent changes.
                ## Topics
                ### Release Notes
                 - <doc:documentation/TechnologyX/ReleaseNotes-1.2>
                """),
                // A curated article
                TextFile(name: "ReleaseNotes 1.2.md", utf8Content: """
                # Release Notes for version 1.2
                Learn about changes in version 1.2
                ## See Also
                 - <doc:documentation/TechnologyX/ReleaseNotes>
                """),
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ])
        )
        
        // Verify all articles were loaded in the context
        XCTAssertEqual(context.knownIdentifiers.count, 2)
        
        // Verify /documentation/ReleaseNotes is a root node
        XCTAssertEqual(context.rootModules.map({ $0.url.path }), ["/documentation/ReleaseNotes"])
        
        // Verify the root was crawled
        XCTAssertEqual(context.topicGraph.edges[ResolvedTopicReference(bundleID: "com.test.example", path: "/documentation/ReleaseNotes", sourceLanguage: .swift)]?.map({ $0.url.path }),
                       ["/documentation/TestBundle/ReleaseNotes-1.2"])
    }

    func testWarnsAboutExtensionFileTechnologyRoot() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "no-sgf-test.docc", content: [
                // Root page for the collection
                TextFile(name: "ReleaseNotes.md", utf8Content: """
                # Release Notes
                @Metadata {
                   @TechnologyRoot
                }
                Learn about recent changes.
                ## Topics
                ### Release Notes
                 - <doc:documentation/TechnologyX/ReleaseNotes-1.2>
                """),
                // A documentation extension file
                TextFile(name: "MyClass.md", utf8Content: """
                # ``ReleaseNotes/MyClass``
                @Metadata {
                   @TechnologyRoot
                }
                """),
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ])
        )
        
        // Verify that we emit a warning when trying to make a symbol a root page
        let technologyRootProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.UnexpectedTechnologyRoot" }))
        XCTAssertEqual(technologyRootProblem.diagnostic.source, URL(fileURLWithPath: "/no-sgf-test.docc/MyClass.md"))
        XCTAssertEqual(technologyRootProblem.diagnostic.range?.lowerBound.line, 3)
        let solution = try XCTUnwrap(technologyRootProblem.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.first?.range.lowerBound.line, 3)
        XCTAssertEqual(solution.replacements.first?.range.upperBound.line, 3)
    }
    
    func testSingleArticleWithoutTechnologyRootDirective() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "Something.docc", content: [
                TextFile(name: "Article.md", utf8Content: """
                # My article
                
                A regular article without an explicit `@TechnologyRoot` directive.
                """)
            ])
        )
        
        XCTAssertEqual(context.knownPages.map(\.absoluteString), ["doc://Something/documentation/Article"])
        XCTAssertEqual(context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Article"])
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testMultipleArticlesWithoutTechnologyRootDirective() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "Something.docc", content: [
                TextFile(name: "First.md", utf8Content: """
                # My first article
                
                A regular article without an explicit `@TechnologyRoot` directive.
                """),
                
                TextFile(name: "Second.md", utf8Content: """
                # My second article
                
                Another regular article without an explicit `@TechnologyRoot` directive.
                """),
                
                TextFile(name: "Third.md", utf8Content: """
                # My third article
                
                Yet another regular article without an explicit `@TechnologyRoot` directive.
                """),
            ])
        )
        
        XCTAssertEqual(context.knownPages.map(\.absoluteString).sorted(), [
            "doc://Something/documentation/Something", // A synthesized root
            "doc://Something/documentation/Something/First",
            "doc://Something/documentation/Something/Second",
            "doc://Something/documentation/Something/Third",
        ])
        XCTAssertEqual(context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Something"], "If no single article is a clear root, the root page is synthesized")
        
        XCTAssertEqual(context.problems.count, 0)
    }
    
    func testMultipleArticlesWithoutTechnologyRootDirectiveWithOneMatchingTheCatalogName() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "Something.docc", content: [
                TextFile(name: "Something.md", utf8Content: """
                # Some article
                
                A regular article without an explicit `@TechnologyRoot` directive.
                
                The name of this article file matches the name of the catalog.
                """),
                
                TextFile(name: "Second.md", utf8Content: """
                # My second article
                
                Another regular article without an explicit `@TechnologyRoot` directive.
                """),
                
                TextFile(name: "Third.md", utf8Content: """
                # My third article
                
                Yet another regular article without an explicit `@TechnologyRoot` directive.
                """),
            ])
        )
        
        XCTAssertEqual(context.knownPages.map(\.absoluteString).sorted(), [
            "doc://Something/documentation/Something", // This article became the root
            "doc://Something/documentation/Something/Second",
            "doc://Something/documentation/Something/Third",
        ])
        XCTAssertEqual(context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Something"])
        
        XCTAssertEqual(context.problems.count, 0)
    }
}

// MARK: - Multiple Root Page Warnings (Swift Testing)

import Testing

struct DocumentationContext_MultipleRootPageTests {

    @Test
    func warnsAboutMultipleTechnologyRootDirectives() async throws {
        let context = try await load(catalog:
            Folder(name: "multiple-roots.docc", content: [
                TextFile(name: "FirstRoot.md", utf8Content: """
                # First Root
                @Metadata {
                   @TechnologyRoot
                }
                """),

                TextFile(name: "SecondRoot.md", utf8Content: """
                # Second Root
                @Metadata {
                   @TechnologyRoot
                }
                """),

                TextFile(name: "ThirdRoot.md", utf8Content: """
                # Third Root
                @Metadata {
                   @TechnologyRoot
                }
                """),
            ])
        )
        let problems = context.problems.sorted(by: { $0.diagnostic.source?.lastPathComponent ?? "" < $1.diagnostic.source?.lastPathComponent ?? "" })
        #expect(problems.map(\.diagnostic.identifier) == ["MultipleTechnologyRoots", "MultipleTechnologyRoots", "MultipleTechnologyRoots"],
                "Unexpected problems: \(problems.map(\.diagnostic.summary))")

        let rootPageNames = ["FirstRoot", "SecondRoot", "ThirdRoot"]
        for (thisName, problem) in zip(rootPageNames, problems) {
            let otherNames = rootPageNames.filter { $0 != thisName }
            
            #expect(problem.diagnostic.summary == "Documentation hierarchy cannot have multiple root pages")
            #expect(problem.diagnostic.explanation == """
                A single article-only documentation catalog ('docc' directory) covers a single technology, with a single root page.
                This TechnologyRoot directive defines an additional root page, creating a disjoint documentation hierarchy with multiple possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                To resolve this issue; remove all TechnologyRoot directives except for one to use that as the root of your documentation hierarchy.
                """)
            
            #expect(problem.diagnostic.source?.lastPathComponent == "\(thisName).md")
            let page = try #require(context.knownPages.first(where: { $0.lastPathComponent == thisName }).flatMap { context.documentationCache[$0] })
            #expect(problem.diagnostic.range == page.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(problem.diagnostic.notes.map(\.message) == ["Root page also defined here", "Root page also defined here"])
            #expect(problem.diagnostic.notes.map(\.source.lastPathComponent) == otherNames.map { "\($0).md" })
            
            #expect(problem.possibleSolutions.count == 1)
            let solution = try #require(problem.possibleSolutions.first)
            #expect(solution.summary == "Remove TechnologyRoot directive")
            #expect(solution.replacements.count == 1)
            #expect(solution.replacements.first?.range == page.metadata?.technologyRoot?.originalMarkup.range)
            #expect(solution.replacements.first?.replacement == "", "Should suggest to remove the TechnologyRoot directive")
        }
    }

    @Test
    func warnsAboutTechnologyRootsWhenThereAreSymbols() async throws {
        let context = try await load(catalog:
            Folder(name: "symbols-with-multiple-technology-roots.docc", content: [
                JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule")),

                TextFile(name: "FirstRoot.md", utf8Content: """
                # First Root
                @Metadata {
                   @TechnologyRoot
                }
                """),

                TextFile(name: "SecondRoot.md", utf8Content: """
                # Second Root
                @Metadata {
                   @TechnologyRoot
                }
                """),
            ])
        )

        let problems = context.problems.sorted(by: { $0.diagnostic.source?.lastPathComponent ?? "" < $1.diagnostic.source?.lastPathComponent ?? "" })
        // When there are _both_ multiple technology roots and also symbol roots,
        // we should _only_ warn about there being technology roots when there's symbols, not about there being _multiple_ technology roots.
        #expect(problems.map(\.diagnostic.identifier) == ["TechnologyRootWithSymbols", "TechnologyRootWithSymbols"],
                "Unexpected problems: \(problems.map(\.diagnostic.summary))")
        
        let rootPageNames = ["FirstRoot", "SecondRoot"]
        for (thisName, problem) in zip(rootPageNames, problems) {
            let otherNames = rootPageNames.filter { $0 != thisName }
            
            #expect(problem.diagnostic.summary == "Documentation hierarchy cannot have additional root page; already has a symbol root")
            #expect(problem.diagnostic.explanation == """
                A single DocC build covers either a single module (for example a framework, library, or executable) or an article-only technology.
                Because DocC is passed symbol inputs; the documentation hierarchy already gets its root page ('SomeModule') from those symbols.
                This TechnologyRoot directive defines an additional root page, creating a disjoint documentation hierarchy with multiple possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                To resolve this issue; remove all TechnologyRoot directives to use 'SomeModule' as the root page.
                """)
            
            #expect(problem.diagnostic.source?.lastPathComponent == "\(thisName).md")
            let page = try #require(context.knownPages.first(where: { $0.lastPathComponent == thisName }).flatMap { context.documentationCache[$0] })
            #expect(problem.diagnostic.range == page.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(problem.diagnostic.notes.map(\.message) == ["Root page also defined here"])
            #expect(problem.diagnostic.notes.map(\.source.lastPathComponent) == otherNames.map { "\($0).md" })
            
            #expect(problem.possibleSolutions.count == 1)
            let solution = try #require(problem.possibleSolutions.first)
            #expect(solution.summary == "Remove TechnologyRoot directive")
            #expect(solution.replacements.count == 1)
            #expect(solution.replacements.first?.range == page.metadata?.technologyRoot?.originalMarkup.range)
            #expect(solution.replacements.first?.replacement == "", "Should suggest to remove the TechnologyRoot directive")
        }
    }

    @Test
    func emitsTechnologyRootWithSymbolsNotMultipleTechnologyRoots() async throws {
        // When symbols exist AND multiple @TechnologyRoot directives are present,
        // only TechnologyRootWithSymbols warnings should be emitted (not MultipleTechnologyRoots).
        // This tests the mutually exclusive warning logic.
        let context = try await load(catalog:
            Folder(name: "symbols-with-multiple-roots.docc", content: [
                JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule")),

                TextFile(name: "FirstRoot.md", utf8Content: """
                # First Root
                @Metadata {
                   @TechnologyRoot
                }
                """),

                TextFile(name: "SecondRoot.md", utf8Content: """
                # Second Root
                @Metadata {
                   @TechnologyRoot
                }
                """),
            ])
        )

        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "TechnologyRootWithSymbols" }
        #expect(symbolsWithRootProblems.count == 2, "Expected TechnologyRootWithSymbols for each @TechnologyRoot directive")

        let problemSources = symbolsWithRootProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        #expect(problemSources == ["FirstRoot.md", "SecondRoot.md"])

        // Mutually exclusive: no MultipleTechnologyRoots warnings
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "MultipleTechnologyRoots" }
        #expect(multipleRootsProblems.isEmpty, "MultipleTechnologyRoots should not be emitted when symbols provide a root")
    }

    @Test
    func warnsAboutMultipleMainModules() async throws {
        let context = try await load(catalog:
            Folder(name: "multiple-modules.docc", content: [
                JSONFile(name: "ModuleA.symbols.json", content: makeSymbolGraph(moduleName: "ModuleA")),
                JSONFile(name: "ModuleB.symbols.json", content: makeSymbolGraph(moduleName: "ModuleB")),
            ])
        )

        let problems = context.problems.sorted(by: { $0.diagnostic.source?.lastPathComponent ?? "" < $1.diagnostic.source?.lastPathComponent ?? "" })
        #expect(problems.map(\.diagnostic.identifier) == ["MultipleModules"],
                "Unexpected problems: \(problems.map(\.diagnostic.summary))")
        
        let problem = try #require(problems.first)
        
        #expect(problem.diagnostic.summary == "Input files cannot describe more than one main module; got inputs for 'ModuleA' and 'ModuleB'")
        #expect(problem.diagnostic.explanation == """
            A single DocC build covers a single module (for example a framework, library, or executable).
            To produce a documentation archive that covers 'ModuleA' and 'ModuleB'; \
            first document each module separately and then combine their individual archives into a single combined archive by running:
            $ docc merge /path/to/ModuleA.doccarchive /path/to/ModuleB.doccarchive
            For more information, see the `docc merge --help` text.
            """)
    }
}
