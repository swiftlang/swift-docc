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
                This is the first root page.
                """),

                TextFile(name: "SecondRoot.md", utf8Content: """
                # Second Root
                @Metadata {
                   @TechnologyRoot
                }
                This is the second root page.
                """),

                TextFile(name: "ThirdRoot.md", utf8Content: """
                # Third Root
                @Metadata {
                   @TechnologyRoot
                }
                This is the third root page.
                """),
            ])
        )

        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
        #expect(multipleRootsProblems.count == 3, "Expected warnings for all three TechnologyRoot directives, got: \(multipleRootsProblems.count)")

        let problemSources = multipleRootsProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        #expect(problemSources == ["FirstRoot.md", "SecondRoot.md", "ThirdRoot.md"])

        for problem in multipleRootsProblems {
            let solution = try #require(problem.possibleSolutions.first, "Expected a solution for removing the directive")
            #expect(solution.summary == "Remove the 'TechnologyRoot' directive")
            #expect(solution.replacements.count == 1)
        }

        // Verify mutually exclusive: no other root-related warnings
        let otherRootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules"
        }
        #expect(otherRootProblems.isEmpty, "Unexpected root-related warnings: \(otherRootProblems.map(\.diagnostic.summary))")
    }

    @Test
    func warnsAboutTechnologyRootWithSymbols() async throws {
        let context = try await load(catalog:
            Folder(name: "symbols-with-root.docc", content: [
                JSONFile(name: "MyModule.symbols.json", content: makeSymbolGraph(moduleName: "MyModule")),

                TextFile(name: "GettingStarted.md", utf8Content: """
                # Getting Started
                @Metadata {
                   @TechnologyRoot
                }
                Learn how to use MyModule.
                """),
            ])
        )

        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" }
        #expect(symbolsWithRootProblems.count == 1, "Expected one warning for @TechnologyRoot with symbols")

        let problem = try #require(symbolsWithRootProblems.first)
        #expect(problem.diagnostic.source?.lastPathComponent == "GettingStarted.md")
        #expect(problem.diagnostic.severity == .warning)

        let solution = try #require(problem.possibleSolutions.first)
        #expect(solution.summary == "Remove the 'TechnologyRoot' directive")

        // Verify mutually exclusive: no MultipleTechnologyRoots warning
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
        #expect(multipleRootsProblems.isEmpty, "Should not emit MultipleTechnologyRoots when symbols provide the root")
    }

    @Test
    func emitsTechnologyRootWithSymbolsNotMultipleTechnologyRoots() async throws {
        // When symbols exist AND multiple @TechnologyRoot directives are present,
        // only TechnologyRootWithSymbols warnings should be emitted (not MultipleTechnologyRoots).
        // This tests the mutually exclusive warning logic.
        let context = try await load(catalog:
            Folder(name: "symbols-with-multiple-roots.docc", content: [
                JSONFile(name: "MyModule.symbols.json", content: makeSymbolGraph(moduleName: "MyModule")),

                TextFile(name: "FirstRoot.md", utf8Content: """
                # First Root
                @Metadata {
                   @TechnologyRoot
                }
                First root page.
                """),

                TextFile(name: "SecondRoot.md", utf8Content: """
                # Second Root
                @Metadata {
                   @TechnologyRoot
                }
                Second root page.
                """),
            ])
        )

        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" }
        #expect(symbolsWithRootProblems.count == 2, "Expected TechnologyRootWithSymbols for each @TechnologyRoot directive")

        let problemSources = symbolsWithRootProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        #expect(problemSources == ["FirstRoot.md", "SecondRoot.md"])

        // Mutually exclusive: no MultipleTechnologyRoots warnings
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
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

        let multipleModulesProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" }
        #expect(multipleModulesProblems.count == 1, "Expected one warning about multiple main modules")

        let problem = try #require(multipleModulesProblems.first)
        #expect(problem.diagnostic.severity == .warning)
        #expect(problem.diagnostic.summary.contains("ModuleA"), "Summary should list ModuleA")
        #expect(problem.diagnostic.summary.contains("ModuleB"), "Summary should list ModuleB")
    }

    @Test
    func noWarningForSingleModule() async throws {
        let context = try await load(catalog:
            Folder(name: "single-module.docc", content: [
                JSONFile(name: "MyModule.symbols.json", content: makeSymbolGraph(moduleName: "MyModule")),
            ])
        )

        let rootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" ||
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots"
        }
        #expect(rootProblems.isEmpty, "Single module should not trigger root-related warnings: \(rootProblems.map(\.diagnostic.summary))")
    }

    @Test
    func noWarningForSingleTechnologyRoot() async throws {
        let context = try await load(catalog:
            Folder(name: "single-root.docc", content: [
                TextFile(name: "Root.md", utf8Content: """
                # My Documentation
                @Metadata {
                   @TechnologyRoot
                }
                Welcome to the documentation.
                """),
            ])
        )

        let rootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" ||
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots"
        }
        #expect(rootProblems.isEmpty, "Single @TechnologyRoot should not trigger warnings: \(rootProblems.map(\.diagnostic.summary))")
    }
}
