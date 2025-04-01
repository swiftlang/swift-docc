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
        let (_, context) = try loadBundle(
            catalog:
                Folder(
                    name: "no-sgf-test.docc",
                    content: [
                        // Root page for the collection
                        TextFile(
                            name: "ReleaseNotes.md",
                            utf8Content: """
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
                        TextFile(
                            name: "ReleaseNotes 1.2.md",
                            utf8Content: """
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
        XCTAssertEqual(
            context.topicGraph.edges[
                ResolvedTopicReference(
                    bundleID: "com.test.example", path: "/documentation/ReleaseNotes",
                    sourceLanguage: .swift)]?.map({ $0.url.path }),
            ["/documentation/TestBundle/ReleaseNotes-1.2"])
    }

    func testWarnsAboutExtensionFileTechnologyRoot() throws {
        let (_, context) = try loadBundle(
            catalog:
                Folder(
                    name: "no-sgf-test.docc",
                    content: [
                        // Root page for the collection
                        TextFile(
                            name: "ReleaseNotes.md",
                            utf8Content: """
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
                        TextFile(
                            name: "MyClass.md",
                            utf8Content: """
                                # ``ReleaseNotes/MyClass``
                                @Metadata {
                                   @TechnologyRoot
                                }
                                """),
                        InfoPlist(displayName: "TestBundle", identifier: "com.test.example"),
                    ])
        )

        // Verify that we emit a warning when trying to make a symbol a root page
        let technologyRootProblem = try XCTUnwrap(
            context.problems.first(where: {
                $0.diagnostic.identifier == "org.swift.docc.UnexpectedTechnologyRoot"
            }))
        XCTAssertEqual(
            technologyRootProblem.diagnostic.source,
            URL(fileURLWithPath: "/no-sgf-test.docc/MyClass.md"))
        XCTAssertEqual(technologyRootProblem.diagnostic.range?.lowerBound.line, 3)
        let solution = try XCTUnwrap(technologyRootProblem.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.first?.range.lowerBound.line, 3)
        XCTAssertEqual(solution.replacements.first?.range.upperBound.line, 3)
    }

    func testSingleArticleWithoutTechnologyRootDirective() throws {
        let (_, context) = try loadBundle(
            catalog:
                Folder(
                    name: "Something.docc",
                    content: [
                        TextFile(
                            name: "Article.md",
                            utf8Content: """
                                # My article

                                A regular article without an explicit `@TechnologyRoot` directive.
                                """)
                    ])
        )

        XCTAssertEqual(
            context.knownPages.map(\.absoluteString), ["doc://Something/documentation/Article"])
        XCTAssertEqual(
            context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Article"])

        XCTAssertEqual(context.problems.count, 0)
    }

    func testMultipleArticlesWithoutTechnologyRootDirective() throws {
        let (_, context) = try loadBundle(
            catalog:
                Folder(
                    name: "Something.docc",
                    content: [
                        TextFile(
                            name: "First.md",
                            utf8Content: """
                                # My first article

                                A regular article without an explicit `@TechnologyRoot` directive.
                                """),

                        TextFile(
                            name: "Second.md",
                            utf8Content: """
                                # My second article

                                Another regular article without an explicit `@TechnologyRoot` directive.
                                """),

                        TextFile(
                            name: "Third.md",
                            utf8Content: """
                                # My third article

                                Yet another regular article without an explicit `@TechnologyRoot` directive.
                                """),
                    ])
        )

        XCTAssertEqual(
            context.knownPages.map(\.absoluteString).sorted(),
            [
                "doc://Something/documentation/Something",  // A synthesized root
                "doc://Something/documentation/Something/First",
                "doc://Something/documentation/Something/Second",
                "doc://Something/documentation/Something/Third",
            ])
        XCTAssertEqual(
            context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Something"],
            "If no single article is a clear root, the root page is synthesized")

        XCTAssertEqual(context.problems.count, 0)
    }

    func testMultipleArticlesWithoutTechnologyRootDirectiveWithOneMatchingTheCatalogName() throws {
        let (_, context) = try loadBundle(
            catalog:
                Folder(
                    name: "Something.docc",
                    content: [
                        TextFile(
                            name: "Something.md",
                            utf8Content: """
                                # Some article

                                A regular article without an explicit `@TechnologyRoot` directive.

                                The name of this article file matches the name of the catalog.
                                """),

                        TextFile(
                            name: "Second.md",
                            utf8Content: """
                                # My second article

                                Another regular article without an explicit `@TechnologyRoot` directive.
                                """),

                        TextFile(
                            name: "Third.md",
                            utf8Content: """
                                # My third article

                                Yet another regular article without an explicit `@TechnologyRoot` directive.
                                """),
                    ])
        )

        XCTAssertEqual(
            context.knownPages.map(\.absoluteString).sorted(),
            [
                "doc://Something/documentation/Something",  // This article became the root
                "doc://Something/documentation/Something/Second",
                "doc://Something/documentation/Something/Third",
            ])
        XCTAssertEqual(
            context.rootModules.map(\.absoluteString), ["doc://Something/documentation/Something"])

        XCTAssertEqual(context.problems.count, 0)
    }

    //Multiple Root Warnings Tests

    func testMultipleSymbolGraphModulesWarning() throws {
        //created a test bundle with two symbol graph files for different modules
        let tempURL = try createTemporaryDirectory()
        let bundleURL = tempURL.appendingPathComponent("test.docc")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        //created two symbol graph files for different modules
        let module1GraphURL = bundleURL.appendingPathComponent("Module1.symbols.json")
        let module2GraphURL = bundleURL.appendingPathComponent("Module2.symbols.json")

        // Symbol graph content for Module1
        let module1Graph = makeSymbolGraph(
            moduleName: "Module1",
            symbols: [],
            relationships: []
        )

        //symbol graph content for Module2
        let module2Graph = makeSymbolGraph(
            moduleName: "Module2",
            symbols: [],
            relationships: []
        )

        //symbol graphs to files
        try JSONEncoder().encode(module1Graph).write(to: module1GraphURL)
        try JSONEncoder().encode(module2Graph).write(to: module2GraphURL)

        //created the Info.plist file
        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        let infoPlist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleIdentifier</key>
                <string>org.swift.docc.example</string>
                <key>CFBundleName</key>
                <string>Test Bundle</string>
                <key>CFBundleVersion</key>
                <string>1.0.0</string>
            </dict>
            </plist>
            """
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)

        //bundle
        let (_, _, context) = try loadBundle(from: bundleURL)

        //checks for the warning about multiple symbol graph modules
        let multipleModuleWarning = context.problems.first {
            $0.diagnostic.identifier == "org.swift.docc.MultipleSymbolGraphRoots"
        }
        XCTAssertNotNil(
            multipleModuleWarning, "Should emit warning about multiple symbol graph modules")
        XCTAssertEqual(
            multipleModuleWarning?.diagnostic.summary,
            "Documentation has multiple symbol graph modules as root pages")
        XCTAssertTrue(multipleModuleWarning?.diagnostic.explanation?.contains("Module1") ?? false)
        XCTAssertTrue(multipleModuleWarning?.diagnostic.explanation?.contains("Module2") ?? false)
    }

    func testMixedRootTypesWarning() throws {
        //create a test bundle with both a symbol graph module and a manual technology root article
        let tempURL = try createTemporaryDirectory()
        let bundleURL = tempURL.appendingPathComponent("mixed-roots.docc")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        //create a manual technology root article
        let articleURL = bundleURL.appendingPathComponent("Article.md")
        let articleContent = """
            # My Documentation
            @Metadata {
               @TechnologyRoot
            }
            Learn about this technology.
            """
        try articleContent.write(to: articleURL, atomically: true, encoding: .utf8)

        //create a symbol graph file
        let symbolGraphURL = bundleURL.appendingPathComponent("MyModule.symbols.json")

        //create a simple symbol graph with a class
        let symbolGraph = makeSymbolGraph(
            moduleName: "MyModule",
            symbols: [
                makeSymbol(
                    id: "swift.class.MyClass",
                    language: .swift,
                    kind: .class,
                    pathComponents: ["MyModule", "MyClass"]
                )
            ],
            relationships: []
        )

        try JSONEncoder().encode(symbolGraph).write(to: symbolGraphURL)

        //create Info.plist
        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        let infoPlist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleIdentifier</key>
                <string>com.test.myframework</string>
                <key>CFBundleName</key>
                <string>MyFramework</string>
                <key>CFBundleVersion</key>
                <string>1.0.0</string>
            </dict>
            </plist>
            """
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)

        //load the bundle
        let (_, _, context) = try loadBundle(from: bundleURL)

        // Check for the warning about mixed root types
        let mixedRootsWarning = context.problems.first {
            $0.diagnostic.identifier == "org.swift.docc.MixedRootTypes"
        }
        XCTAssertNotNil(mixedRootsWarning, "Should emit warning about mixed root types")
        XCTAssertEqual(
            mixedRootsWarning?.diagnostic.summary,
            "Documentation has both symbol graph modules and manual technology roots")
        XCTAssertTrue(
            mixedRootsWarning?.diagnostic.explanation?.contains("symbol graph modules") ?? false)
        XCTAssertTrue(
            mixedRootsWarning?.diagnostic.explanation?.contains("manual technology roots") ?? false)
    }

    func testMultipleTechnologyRootsWarning() throws {
        //create a test bundle with multiple manual technology roots
        let tempURL = try createTemporaryDirectory()
        let bundleURL = tempURL.appendingPathComponent("multiple-tech-roots.docc")
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        //create first manual technology root
        let gettingStartedURL = bundleURL.appendingPathComponent("GettingStarted.md")
        let gettingStartedContent = """
            # Getting Started
            @Metadata {
               @TechnologyRoot
            }
            Learn how to get started.
            """
        try gettingStartedContent.write(to: gettingStartedURL, atomically: true, encoding: .utf8)

        //create second manual technology root
        let apiReferenceURL = bundleURL.appendingPathComponent("APIReference.md")
        let apiReferenceContent = """
            # API Reference
            @Metadata {
               @TechnologyRoot
            }
            Reference documentation for the API.
            """
        try apiReferenceContent.write(to: apiReferenceURL, atomically: true, encoding: .utf8)

        //create Info.plist
        let infoPlistURL = bundleURL.appendingPathComponent("Info.plist")
        let infoPlist = """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
            <plist version="1.0">
            <dict>
                <key>CFBundleIdentifier</key>
                <string>com.test.myframework</string>
                <key>CFBundleName</key>
                <string>MyFramework</string>
                <key>CFBundleVersion</key>
                <string>1.0.0</string>
            </dict>
            </plist>
            """
        try infoPlist.write(to: infoPlistURL, atomically: true, encoding: .utf8)

        //load the bundle
        let (_, _, context) = try loadBundle(from: bundleURL)

        // Check for the warning about multiple technology roots
        let multipleTechRootsWarning = context.problems.first {
            $0.diagnostic.identifier == "org.swift.docc.MultipleTechnologyRoots"
        }
        XCTAssertNotNil(
            multipleTechRootsWarning, "Should emit warning about multiple technology roots")
        XCTAssertEqual(
            multipleTechRootsWarning?.diagnostic.summary,
            "Documentation has multiple manual technology roots")
        XCTAssertTrue(
            multipleTechRootsWarning?.diagnostic.explanation?.contains("GettingStarted") ?? false)
        XCTAssertTrue(
            multipleTechRootsWarning?.diagnostic.explanation?.contains("APIReference") ?? false)
    }
}
