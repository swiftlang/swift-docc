/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities
import DocCCommon
import Markdown

struct DocumentationContext_RootPageTests {
    @Test
    func explicitTechnologyRootBecomesRootInArticleOnlyDocumentation() async throws {
        let context = try await load(catalog:
            Folder(name: "some-article-only-catalog.docc", content: [
                TextFile(name: "Something.md", utf8Content: """
                # Some title
                @Metadata {
                   @TechnologyRoot
                }
                This article is explicitly defined as the root of the documentation hierarchy
                
                ## Topics
                """),
                
                TextFile(name: "SomethingElse.md", utf8Content: """
                # Some other title
                """),
            ])
        )
        
        #expect(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        #expect(context.knownIdentifiers.count == 2)
        
        let rootReference = try #require(context.soleRootModuleReference)
        #expect(rootReference.path == "/documentation/Something")
        
        #expect(context.topicGraph.edges[rootReference]?.map(\.url.path) == ["/documentation/some-article-only-catalog/SomethingElse"])
    }

    @Test
    func warnsAboutTechnologyRootInExtensionFile() async throws {
        let context = try await load(catalog:
            Folder(name: "unit-test.docc", content: [
                JSONFile(name: "SomeModule.symbols.json", content: makeSymbolGraph(moduleName: "SomeModule", symbols: [
                    makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"])
                ])),
                
                // One incorrect technology root for the module
                TextFile(name: "Root.md", utf8Content: """
                # ``SomeModule``
                @Metadata {
                   @TechnologyRoot
                }
                Documentation extension files don't support TechnologyRoot directives
                """),
                
                // Another technology root for the symbol
                TextFile(name: "SomeClass.md", utf8Content: """
                # ``SomeModule/SomeClass``
                @Metadata {
                   @TechnologyRoot
                }
                Documentation extension files don't support TechnologyRoot directives
                """),
            ])
        )
        
        // Ensure a stable order of the diagnostics by sorting on their file names
        let problems = context.problems.sorted(by: { $0.diagnostic.source?.lastPathComponent ?? "" < $1.diagnostic.source?.lastPathComponent ?? "" })
        #expect(problems.map(\.diagnostic.identifier) == ["TechnologyRootInExtensionFile", "TechnologyRootInExtensionFile"],
                "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        // Verify the problem about the module extension file
        do {
            let problem = try #require(problems.first)
            #expect(problem.diagnostic.summary == "TechnologyRoot directive cannot modify documentation extension file")
            #expect(problem.diagnostic.explanation == """
                Symbols inherently belong to a module (in this case 'SomeModule') which is already the root of the documentation hierarchy.
                A documentation extension file doesn't define its own page but instead associates additional content with one of the symbol pages (in this case the 'SomeModule' module).
                The 'SomeModule' module is already the root of the documentation hierarchy. Specifying a TechnologyRoot directive has no effect.
                """)
            #expect(problem.diagnostic.source?.lastPathComponent == "Root.md")
            let modulePage = try #require(context.soleRootModuleReference.flatMap { context.documentationCache[$0] })
            #expect(problem.diagnostic.range == modulePage.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(problem.possibleSolutions.count == 1)
            let solution = try #require(problem.possibleSolutions.first)
            #expect(solution.summary == "Remove TechnologyRoot directive")
            #expect(solution.replacements.count == 1)
            #expect(solution.replacements.first?.range == modulePage.metadata?.technologyRoot?.originalMarkup.range)
            #expect(solution.replacements.first?.replacement == "", "Should suggest to remove the TechnologyRoot directive")
        }
        
        // Verify the problem about the class extension file
        do {
            let problem = try #require(problems.last)
            #expect(problem.diagnostic.summary == "TechnologyRoot directive cannot modify documentation extension file")
            #expect(problem.diagnostic.explanation == """
                Symbols inherently belong to a module (in this case 'SomeModule') which is already the root of the documentation hierarchy.
                A documentation extension file doesn't define its own page but instead associates additional content with one of the symbol pages (in this case the 'SomeClass' class).
                If the 'SomeClass' class became a root page it would move out of the 'SomeModule' module, creating a disjoint documentation hierarchy with two possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                """)
            #expect(problem.diagnostic.source?.lastPathComponent == "SomeClass.md")
            let classPage = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeClass" }).flatMap { context.documentationCache[$0] })
            #expect(problem.diagnostic.range == classPage.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(problem.possibleSolutions.count == 1)
            let solution = try #require(problem.possibleSolutions.first)
            #expect(solution.summary == "Remove TechnologyRoot directive")
            #expect(solution.replacements.count == 1)
            #expect(solution.replacements.first?.range == classPage.metadata?.technologyRoot?.originalMarkup.range)
            #expect(solution.replacements.first?.replacement == "", "Should suggest to remove the TechnologyRoot directive")
        }
    }
    
    @Test
    func loneArticleBecomesRootPageWithoutTechnologyRootDirective() async throws {
        let context = try await load(catalog:
            Folder(name: "Something.docc", content: [
                TextFile(name: "Article.md", utf8Content: """
                # My article
                
                A regular article without an explicit `@TechnologyRoot` directive.
                """)
            ])
        )
        
        #expect(context.knownPages.map(\.absoluteString) == ["doc://Something/documentation/Article"])
        #expect(context.rootModules.map(\.absoluteString) == ["doc://Something/documentation/Article"])
        
        #expect(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
    }
    
    @Test
    func synthesizedRootPageForMultipleArticlesWithoutTechnologyRootDirective() async throws {
        let context = try await load(catalog:
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
        
        #expect(context.knownPages.map(\.absoluteString).sorted() == [
            "doc://Something/documentation/Something", // A synthesized root
            "doc://Something/documentation/Something/First",
            "doc://Something/documentation/Something/Second",
            "doc://Something/documentation/Something/Third",
        ])
        #expect(context.rootModules.map(\.absoluteString) == ["doc://Something/documentation/Something"], "If no single article is a clear root, the root page is synthesized")
        
        #expect(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
    }
    
    @Test
    func promotesArticleMatchingTheCatalogNameToRootPage() async throws {
        let context = try await load(catalog:
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
        
        #expect(context.knownPages.map(\.absoluteString).sorted() == [
            "doc://Something/documentation/Something", // This article became the root
            "doc://Something/documentation/Something/Second",
            "doc://Something/documentation/Something/Third",
        ])
        #expect(context.rootModules.map(\.absoluteString) == ["doc://Something/documentation/Something"])
        
        #expect(context.problems.isEmpty, "Encountered unexpected problems: \(context.problems.map(\.diagnostic.summary))")
    }

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
