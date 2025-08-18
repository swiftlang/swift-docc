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
import SwiftDocCTestUtilities

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
    }
    
    func testWarnsAboutSymbolsWithTechnologyRootPages() async throws {
        // Test the third case: documentation contains symbols (has a module) and also has @TechnologyRoot pages
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "symbols-with-root.docc", content: [
                // Symbol graph with a module
                JSONFile(name: "MyModule.symbols.json", content: makeSymbolGraph(moduleName: "MyModule")),
                
                // Article with @TechnologyRoot directive
                TextFile(name: "GettingStarted.md", utf8Content: """
                # Getting Started
                @Metadata {
                   @TechnologyRoot
                }
                Learn how to use MyModule.
                """),
                
                // Another article with @TechnologyRoot directive
                TextFile(name: "Overview.md", utf8Content: """
                # Overview
                @Metadata {
                   @TechnologyRoot
                }
                Overview of the technology.
                """),
            ])
        )
        
        // Verify that we emit warnings for @TechnologyRoot directives when symbols are present
        let symbolsWithRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.TechnologyRootWithSymbols" }
        XCTAssertEqual(symbolsWithRootProblems.count, 2, "Should emit warnings for both @TechnologyRoot directives when symbols are present")
        
        // Verify the warnings are associated with the correct files
        let problemSources = symbolsWithRootProblems.compactMap { $0.diagnostic.source?.lastPathComponent }.sorted()
        XCTAssertEqual(problemSources, ["GettingStarted.md", "Overview.md"])
        
        // Verify each warning has a solution to remove the TechnologyRoot directive
        for problem in symbolsWithRootProblems {
            XCTAssertEqual(problem.possibleSolutions.count, 1)
            let solution = try XCTUnwrap(problem.possibleSolutions.first)
            XCTAssertEqual(solution.summary, "Remove the 'TechnologyRoot' directive")
            XCTAssertEqual(solution.replacements.count, 1)
        }
    }
    
    func testWarnsAboutMultipleMainModules() async throws {
        // Create a bundle with multiple symbol graphs for different modules
        let (_, context) = try await loadBundle(catalog:
            Folder(name: "multiple-modules.docc", content: [
                // First module symbol graph
                JSONFile(name: "ModuleA.symbols.json", content: makeSymbolGraph(moduleName: "ModuleA")),
                
                // Second module symbol graph
                JSONFile(name: "ModuleB.symbols.json", content: makeSymbolGraph(moduleName: "ModuleB")),
                
                InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
            ])
        )
        
        // Verify that we emit a warning for multiple main modules
        let multipleModulesProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.MultipleMainModules" }))
        XCTAssertEqual(multipleModulesProblem.diagnostic.severity, .warning)
        XCTAssertTrue(multipleModulesProblem.diagnostic.summary.contains("more than one main module"))
        XCTAssertTrue(multipleModulesProblem.diagnostic.explanation?.contains("ModuleA, ModuleB") == true)
        
        // Verify the warning doesn't have a source location since it's about the overall input structure
        XCTAssertNil(multipleModulesProblem.diagnostic.source)
        XCTAssertNil(multipleModulesProblem.diagnostic.range)
    }
}
