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
        
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
        
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
        let diagnostics = context.diagnostics.sorted(by: { $0.source?.lastPathComponent ?? "" < $1.source?.lastPathComponent ?? "" })
        #expect(diagnostics.map(\.identifier) == ["TechnologyRootInExtensionFile", "TechnologyRootInExtensionFile"],
                "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
        
        // Verify the diagnostic about the module extension file
        do {
            let diagnostic = try #require(diagnostics.first)
            #expect(diagnostic.summary == "TechnologyRoot directive has no effect in documentation extension")
            #expect(diagnostic.explanation == """
                Symbols inherently belong to a module (in this case 'SomeModule') which is already the root of the documentation hierarchy.
                A documentation extension file doesn't define its own page but instead associates additional content with one of the symbol pages (in this case the 'SomeModule' module).
                The 'SomeModule' module is already the root of the documentation hierarchy. Specifying a TechnologyRoot directive has no effect.
                """)
            #expect(diagnostic.source?.lastPathComponent == "Root.md")
            let modulePage = try #require(context.soleRootModuleReference.flatMap { context.documentationCache[$0] })
            #expect(diagnostic.range == modulePage.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(diagnostic.possibleSolutions.count == 1)
            let solution = try #require(diagnostic.possibleSolutions.first)
            #expect(solution.summary == "Remove TechnologyRoot directive")
            #expect(solution.replacements.count == 1)
            #expect(solution.replacements.first?.range == modulePage.metadata?.technologyRoot?.originalMarkup.range)
            #expect(solution.replacements.first?.replacement == "", "Should suggest to remove the TechnologyRoot directive")
        }
        
        // Verify the diagnostic about the class extension file
        do {
            let diagnostic = try #require(diagnostics.last)
            #expect(diagnostic.summary == "TechnologyRoot directive has no effect in documentation extension")
            #expect(diagnostic.explanation == """
                Symbols inherently belong to a module (in this case 'SomeModule') which is already the root of the documentation hierarchy.
                A documentation extension file doesn't define its own page but instead associates additional content with one of the symbol pages (in this case the 'SomeClass' class).
                If the 'SomeClass' class became a root page it would move out of the 'SomeModule' module, creating a disjoint documentation hierarchy with two possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                """)
            #expect(diagnostic.source?.lastPathComponent == "SomeClass.md")
            let classPage = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SomeClass" }).flatMap { context.documentationCache[$0] })
            #expect(diagnostic.range == classPage.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(diagnostic.possibleSolutions.count == 1)
            let solution = try #require(diagnostic.possibleSolutions.first)
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
        
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
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
        
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
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
        
        #expect(context.diagnostics.isEmpty, "Encountered unexpected problems: \(context.diagnostics.map(\.summary))")
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
        let diagnostics = context.diagnostics.sorted(by: { $0.source?.lastPathComponent ?? "" < $1.source?.lastPathComponent ?? "" })
        #expect(diagnostics.map(\.identifier) == ["MultipleTechnologyRoots", "MultipleTechnologyRoots", "MultipleTechnologyRoots"],
                "Unexpected problems: \(diagnostics.map(\.summary))")

        let rootPageNames = ["FirstRoot", "SecondRoot", "ThirdRoot"]
        for (thisName, diagnostic) in zip(rootPageNames, diagnostics) {
            let otherNames = rootPageNames.filter { $0 != thisName }
            
            #expect(diagnostic.summary == "Documentation hierarchy cannot have multiple root pages")
            #expect(diagnostic.explanation == """
                A single article-only documentation catalog ('docc' directory) covers a single technology, with a single root page.
                This TechnologyRoot directive defines an additional root page, creating a disjoint documentation hierarchy with multiple possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                To resolve this issue; remove all TechnologyRoot directives except for one to use that as the root of your documentation hierarchy.
                """)
            
            #expect(diagnostic.source?.lastPathComponent == "\(thisName).md")
            let page = try #require(context.knownPages.first(where: { $0.lastPathComponent == thisName }).flatMap { context.documentationCache[$0] })
            #expect(diagnostic.range == page.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(diagnostic.notes.map(\.message) == ["Root page also defined here", "Root page also defined here"])
            #expect(diagnostic.notes.map(\.source.lastPathComponent) == otherNames.map { "\($0).md" })
            
            #expect(diagnostic.possibleSolutions.count == 1)
            let solution = try #require(diagnostic.possibleSolutions.first)
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

        let diagnostics = context.diagnostics.sorted(by: { $0.source?.lastPathComponent ?? "" < $1.source?.lastPathComponent ?? "" })
        // When there are _both_ multiple technology roots and also symbol roots,
        // we should _only_ warn about there being technology roots when there's symbols, not about there being _multiple_ technology roots.
        #expect(diagnostics.map(\.identifier) == ["TechnologyRootWithSymbols", "TechnologyRootWithSymbols"],
                "Unexpected problems: \(diagnostics.map(\.summary))")
        
        let rootPageNames = ["FirstRoot", "SecondRoot"]
        for (thisName, diagnostic) in zip(rootPageNames, diagnostics) {
            let otherNames = rootPageNames.filter { $0 != thisName }
            
            #expect(diagnostic.summary == "Documentation hierarchy cannot have additional root page; already has a symbol root")
            #expect(diagnostic.explanation == """
                A single DocC build covers either a single module (for example a framework, library, or executable) or an article-only technology.
                Because DocC is passed symbol inputs; the documentation hierarchy already gets its root page ('SomeModule') from those symbols.
                This TechnologyRoot directive defines an additional root page, creating a disjoint documentation hierarchy with multiple possible starting points, \
                resulting in undefined behavior for core DocC features that rely on a consistent and well defined documentation hierarchy.
                To resolve this issue; remove all TechnologyRoot directives to use 'SomeModule' as the root page.
                """)
            
            #expect(diagnostic.source?.lastPathComponent == "\(thisName).md")
            let page = try #require(context.knownPages.first(where: { $0.lastPathComponent == thisName }).flatMap { context.documentationCache[$0] })
            #expect(diagnostic.range == page.metadata?.technologyRoot?.originalMarkup.range, "Should highlight the TechnologyRoot directive")
            
            #expect(diagnostic.notes.map(\.message) == ["Root page also defined here"])
            #expect(diagnostic.notes.map(\.source.lastPathComponent) == otherNames.map { "\($0).md" })
            
            #expect(diagnostic.possibleSolutions.count == 1)
            let solution = try #require(diagnostic.possibleSolutions.first)
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

        let symbolsWithRootDiagnostics = context.diagnostics.filter { $0.identifier == "TechnologyRootWithSymbols" }
        #expect(symbolsWithRootDiagnostics.count == 2, "Expected TechnologyRootWithSymbols for each @TechnologyRoot directive")

        let diagnosticSources = symbolsWithRootDiagnostics.compactMap { $0.source?.lastPathComponent }.sorted()
        #expect(diagnosticSources == ["FirstRoot.md", "SecondRoot.md"])

        // Mutually exclusive: no MultipleTechnologyRoots warnings
        let multipleRootsDiagnostics = context.diagnostics.filter { $0.identifier == "MultipleTechnologyRoots" }
        #expect(multipleRootsDiagnostics.isEmpty, "MultipleTechnologyRoots should not be emitted when symbols provide a root")
    }

    @Test
    func warnsAboutMultipleMainModules() async throws {
        let context = try await load(catalog:
            Folder(name: "multiple-modules.docc", content: [
                JSONFile(name: "ModuleA.symbols.json", content: makeSymbolGraph(moduleName: "ModuleA")),
                JSONFile(name: "ModuleB.symbols.json", content: makeSymbolGraph(moduleName: "ModuleB")),
            ])
        )

        let diagnostics = context.diagnostics.sorted(by: { $0.source?.lastPathComponent ?? "" < $1.source?.lastPathComponent ?? "" })
        #expect(diagnostics.map(\.identifier) == ["MultipleModules"],
                "Unexpected problems: \(diagnostics.map(\.summary))")
        
        let diagnostic = try #require(diagnostics.first)
        
        #expect(diagnostic.summary == "Input files cannot describe more than one main module; got inputs for 'ModuleA' and 'ModuleB'")
        #expect(diagnostic.explanation == """
            A single DocC build covers a single module (for example a framework, library, or executable).
            To produce a documentation archive that covers 'ModuleA' and 'ModuleB'; \
            first document each module separately and then combine their individual archives into a single combined archive by running:
            $ docc merge /path/to/ModuleA.doccarchive /path/to/ModuleB.doccarchive
            For more information, see the `docc merge --help` text.
            """)
    }
}
