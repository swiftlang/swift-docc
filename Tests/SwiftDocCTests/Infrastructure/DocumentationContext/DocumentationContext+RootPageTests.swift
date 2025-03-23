/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC
import SwiftDocCTestUtilities

class DocumentationContext_RootPageTests: XCTestCase {
    func testArticleOnlyCatalogWithExplicitTechnologyRoot() throws {
        let (_, context) = try loadBundle(catalog:
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

    func testWarnsAboutExtensionFileTechnologyRoot() throws {
        let (_, context) = try loadBundle(catalog:
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
    
    func testSingleArticleWithoutTechnologyRootDirective() throws {
        let (_, context) = try loadBundle(catalog:
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
    
    func testMultipleArticlesWithoutTechnologyRootDirective() throws {
        let (_, context) = try loadBundle(catalog:
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
    
    func testMultipleArticlesWithoutTechnologyRootDirectiveWithOneMatchingTheCatalogName() throws {
        let (_, context) = try loadBundle(catalog:
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
    
    func testWarnsAboutMultipleModuleRoots() throws {
        let moduleOneSymbolGraph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.FormatVersion(major: 1, minor: 0, patch: 0),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "ModuleOne",
                platform: .init(architecture: nil, vendor: nil, operatingSystem: nil, environment: nil),
                version: nil
            ),
            symbols: [],
            relationships: []
        )
        
        let moduleTwoSymbolGraph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.FormatVersion(major: 1, minor: 0, patch: 0),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "ModuleTwo",
                platform: .init(architecture: nil, vendor: nil, operatingSystem: nil, environment: nil),
                version: nil
            ),
            symbols: [],
            relationships: []
        )
        
        let moduleOneSymbolGraphURL = try createTempFile(name: "module-one.symbols.json", content: try JSONEncoder().encode(moduleOneSymbolGraph))
        let moduleTwoSymbolGraphURL = try createTempFile(name: "module-two.symbols.json", content: try JSONEncoder().encode(moduleTwoSymbolGraph))
        
        let (_, context) = try loadBundle(copying: "TestBundle", excludingPaths: ["TestBundle.symbols.json"], additionalSymbolGraphs: [moduleOneSymbolGraphURL, moduleTwoSymbolGraphURL])
        
        // Verify warning about multiple roots
        let multipleRootsProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.MultipleModuleRoots" }))
        XCTAssertEqual(multipleRootsProblem.diagnostic.severity, .warning)
        XCTAssertTrue(multipleRootsProblem.diagnostic.summary.contains("ModuleOne") && multipleRootsProblem.diagnostic.summary.contains("ModuleTwo"), "The warning should mention both module names")
        
        // Verify diagnostic notes
        XCTAssertEqual(multipleRootsProblem.diagnostic.notes.count, 2, "There should be a note for each module")
        XCTAssertTrue(multipleRootsProblem.diagnostic.notes.contains { $0.message.contains("ModuleOne") })
        XCTAssertTrue(multipleRootsProblem.diagnostic.notes.contains { $0.message.contains("ModuleTwo") })
    }
    
    func testWarnsAboutMultipleManualRoots() throws {
        let (_, context) = try loadBundle(catalog:
            Folder(name: "MultipleRoots.docc", content: [
                TextFile(name: "RootOne.md", utf8Content: """
                # Root One
                @Metadata {
                   @TechnologyRoot
                }
                First root article
                """),
                
                TextFile(name: "RootTwo.md", utf8Content: """
                # Root Two
                @Metadata {
                   @TechnologyRoot
                }
                Second root article
                """),
                
                InfoPlist(displayName: "MultipleRoots", identifier: "com.test.multipleroots"),
            ])
        )
        
        // Verify warning about multiple manual roots
        let multipleManualRootProblems = context.problems.filter { $0.diagnostic.identifier == "org.swift.docc.MultipleManualRoots" }
        XCTAssertEqual(multipleManualRootProblems.count, 2, "There should be a warning for each manual root page")
        
        for problem in multipleManualRootProblems {
            XCTAssertEqual(problem.diagnostic.severity, .warning)
            XCTAssertTrue(problem.diagnostic.source?.lastPathComponent == "RootOne.md" || problem.diagnostic.source?.lastPathComponent == "RootTwo.md")
            XCTAssertEqual(problem.possibleSolutions.count, 1, "There should be a solution to remove the TechnologyRoot directive")
            
            // Verify diagnostic notes
            XCTAssertEqual(problem.diagnostic.notes.count, 1, "There should be a note for the other root page")
            let otherRootName = problem.diagnostic.source?.lastPathComponent == "RootOne.md" ? "Root Two" : "Root One"
            XCTAssertTrue(problem.diagnostic.notes.first?.message.contains(otherRootName) ?? false, "The note should mention the other root page")
        }
    }
    
    func testWarnsAboutManualRootWithModuleRoot() throws {
        let symbolGraph = SymbolGraph(
            metadata: SymbolGraph.Metadata(
                formatVersion: SymbolGraph.FormatVersion(major: 1, minor: 0, patch: 0),
                generator: "unit-test"
            ),
            module: SymbolGraph.Module(
                name: "TestModule",
                platform: .init(architecture: nil, vendor: nil, operatingSystem: nil, environment: nil),
                version: nil
            ),
            symbols: [],
            relationships: []
        )
        
        let symbolGraphURL = try createTempFile(name: "test-module.symbols.json", content: try JSONEncoder().encode(symbolGraph))
        
        let tempFolder = try createTempFolder(content: [
            Folder(name: "MixedRoots.docc", content: [
                TextFile(name: "ManualRoot.md", utf8Content: """
                # Manual Root
                @Metadata {
                   @TechnologyRoot
                }
                A manual root page
                """),
                
                InfoPlist(displayName: "MixedRoots", identifier: "com.test.mixedroots"),
            ])
        ])
        
        let (_, context) = try loadBundle(from: URL(fileURLWithPath: tempFolder).appendingPathComponent("MixedRoots.docc"), additionalSymbolGraphs: [symbolGraphURL])
        
        //verify warning about manual root with module root
        let manualWithModuleProblem = try XCTUnwrap(context.problems.first(where: { $0.diagnostic.identifier == "org.swift.docc.ManualRootWithModuleRoot" }))
        XCTAssertEqual(manualWithModuleProblem.diagnostic.severity, .warning)
        XCTAssertEqual(manualWithModuleProblem.diagnostic.source?.lastPathComponent, "ManualRoot.md")
        XCTAssertTrue(manualWithModuleProblem.diagnostic.summary.contains("Manual @TechnologyRoot found with a module root"))
        XCTAssertTrue(manualWithModuleProblem.diagnostic.explanation.contains("TestModule"))
        XCTAssertEqual(manualWithModuleProblem.possibleSolutions.count, 1, "There should be a solution to remove the TechnologyRoot directive")
        
        //verify diagnostic notes
        XCTAssertEqual(manualWithModuleProblem.diagnostic.notes.count, 1, "There should be a note about the module")
        XCTAssertTrue(manualWithModuleProblem.diagnostic.notes.first?.message.contains("TestModule") ?? false, "The note should mention the module name")
    }
}
