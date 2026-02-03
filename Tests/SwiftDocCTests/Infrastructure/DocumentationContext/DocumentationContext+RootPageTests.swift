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

    // MARK: - Multiple Root Page Warnings

    func testWarnsAboutMultipleTechnologyRootDirectives() async throws {
        let (_, context) = try await loadBundle(catalog:
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

        // Verify that we emit warnings for multiple TechnologyRoot directives
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
        XCTAssertEqual(multipleRootsProblems.count, 3, "Should emit warnings for all three TechnologyRoot directives")

        // Verify the warnings are associated with the correct files
        let problemSources = multipleRootsProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        XCTAssertEqual(problemSources, ["FirstRoot.md", "SecondRoot.md", "ThirdRoot.md"])

        // Verify each warning has a solution to remove the TechnologyRoot directive
        for problem in multipleRootsProblems {
            XCTAssertEqual(problem.possibleSolutions.count, 1)
            let solution = try XCTUnwrap(problem.possibleSolutions.first)
            XCTAssertEqual(solution.summary, "Remove the 'TechnologyRoot' directive")
            XCTAssertEqual(solution.replacements.count, 1)
        }

        // Verify no other root-related warnings were emitted
        let otherRootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules"
        }
        XCTAssertEqual(otherRootProblems.count, 0, "Should not emit other root-related warnings")
    }

    func testWarnsAboutTechnologyRootWithSymbols() async throws {
        let (_, context) = try await loadBundle(catalog:
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

        // Verify that we emit a warning for @TechnologyRoot when symbols are present
        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" }
        XCTAssertEqual(symbolsWithRootProblems.count, 1, "Should emit warning for @TechnologyRoot when symbols are present")

        let problem = try XCTUnwrap(symbolsWithRootProblems.first)
        XCTAssertEqual(problem.diagnostic.source?.lastPathComponent, "GettingStarted.md")
        XCTAssertEqual(problem.diagnostic.severity, .warning)

        // Verify the warning has a solution
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        XCTAssertEqual(solution.summary, "Remove the 'TechnologyRoot' directive")

        // Verify diagnostic notes point to the symbol graph file
        XCTAssertEqual(problem.diagnostic.notes.count, 1, "Should have a note pointing to the symbol graph file")
        let note = try XCTUnwrap(problem.diagnostic.notes.first)
        XCTAssertTrue(note.source.lastPathComponent.hasSuffix(".symbols.json"), "Note should point to a symbol graph file")

        // Verify no "MultipleTechnologyRoots" warning was emitted (mutually exclusive)
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
        XCTAssertEqual(multipleRootsProblems.count, 0, "Should not emit MultipleTechnologyRoots when symbols are present")
    }

    func testWarnsAboutMultipleTechnologyRootsWithSymbols() async throws {
        // Test that when we have symbols AND multiple @TechnologyRoot,
        // we only get TechnologyRootWithSymbols warnings (not also MultipleTechnologyRoots)
        let (_, context) = try await loadBundle(catalog:
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

        // Should only emit TechnologyRootWithSymbols warnings, not MultipleTechnologyRoots
        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" }
        XCTAssertEqual(symbolsWithRootProblems.count, 2, "Should emit TechnologyRootWithSymbols for each @TechnologyRoot")

        let problemSources = symbolsWithRootProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        XCTAssertEqual(problemSources, ["FirstRoot.md", "SecondRoot.md"])

        // Verify no MultipleTechnologyRoots warnings (mutually exclusive logic)
        let multipleRootsProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots" }
        XCTAssertEqual(multipleRootsProblems.count, 0, "Should not emit MultipleTechnologyRoots when symbols are present")
    }

    func testWarnsAboutMultipleMainModules() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "multiple-modules.docc", content: [
                JSONFile(name: "ModuleA.symbols.json", content: makeSymbolGraph(moduleName: "ModuleA")),
                JSONFile(name: "ModuleB.symbols.json", content: makeSymbolGraph(moduleName: "ModuleB")),
            ])
        )

        // Verify that we emit a warning for multiple main modules
        let multipleModulesProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" }
        XCTAssertEqual(multipleModulesProblems.count, 1, "Should emit one warning about multiple main modules")

        let problem = try XCTUnwrap(multipleModulesProblems.first)
        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertTrue(problem.diagnostic.summary.contains("ModuleA"), "Summary should mention ModuleA")
        XCTAssertTrue(problem.diagnostic.summary.contains("ModuleB"), "Summary should mention ModuleB")
    }

    func testNoWarningForSingleModule() async throws {
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "single-module.docc", content: [
                JSONFile(name: "MyModule.symbols.json", content: makeSymbolGraph(moduleName: "MyModule")),
            ])
        )

        // No root-related warnings should be emitted for a single module
        let rootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" ||
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots"
        }
        XCTAssertEqual(rootProblems.count, 0, "Should not emit any root-related warnings for a single module")
    }

    func testNoWarningForSingleTechnologyRoot() async throws {
        let (_, context) = try await loadBundle(catalog:
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

        // No root-related warnings should be emitted for a single @TechnologyRoot
        let rootProblems = context.problems.filter {
            $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" ||
            $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" ||
            $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots"
        }
        XCTAssertEqual(rootProblems.count, 0, "Should not emit any root-related warnings for a single @TechnologyRoot")
    }
}
