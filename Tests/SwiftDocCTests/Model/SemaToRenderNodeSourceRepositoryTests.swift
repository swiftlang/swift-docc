/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import Testing
import DocCTestUtilities

struct SemaToRenderNodeSourceRepositoryTests {
    private func node(in context: DocumentationContext, ofKind kind: DocumentationNode.Kind) throws -> DocumentationNode {
        let reference = try #require(context.knownPages.first { (try? context.entity(with: $0))?.kind == kind })
        return try context.entity(with: reference)
    }

    private func renderNode(
        for documentationNode: DocumentationNode,
        in context: DocumentationContext,
        sourceRepository: SourceRepository?
    ) throws -> RenderNode {
        let converter = DocumentationContextConverter(
            context: context,
            renderContext: .init(documentationContext: context),
            sourceRepository: sourceRepository
        )
        return try #require(converter.renderNode(for: documentationNode))
    }

    // MARK: - Symbols

    private func makeSymbolCatalog() -> Folder {
        Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(
                    id: "some-symbol-id",
                    kind: .class,
                    pathComponents: ["MyStruct"],
                    location: (
                        position: .init(line: 9, character: 14),
                        url: URL(fileURLWithPath: "/path/to/checkout/SourceLocations/MyStruct.swift")
                    )
                )
            ]))
        }
    }

    @Test
    func doesNotEmitsSourceRepositoryInformationWhenNoSourceIsGiven() async throws {
        let context = try await load(catalog: makeSymbolCatalog())
        let node = try #require(context.documentationCache["some-symbol-id"])

        let renderNode = try renderNode(for: node, in: context, sourceRepository: nil)

        #expect(renderNode.metadata.remoteSource == nil)
    }

    @Test
    func emitsSourceRepositoryInformationForSymbolsWhenPresent() async throws {
        let context = try await load(catalog: makeSymbolCatalog())
        let node = try #require(context.documentationCache["some-symbol-id"])

        let renderNode = try renderNode(
            for: node,
            in: context,
            sourceRepository: .github(
                checkoutPath: "/path/to/checkout",
                sourceServiceBaseURL: URL(string: "https://example.com/my-repo")!
            )
        )

        #expect(renderNode.metadata.remoteSource == RenderMetadata.RemoteSource(
            fileName: "MyStruct.swift",
            url: URL(string: "https://example.com/my-repo/SourceLocations/MyStruct.swift#L10")!
        ))
    }

    @Test
    func doesNotEmitRemoteSourceForDocumentationExtensionFiles() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"])
            ]))

            TextFile(name: "SomeClass.md", utf8Content: """
            # ``SomeClass``

            An extension to the in-source documentation.
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")
        let symbol = try #require(context.documentationCache["some-symbol-id"])

        let renderNode = try renderNode(
            for: symbol,
            in: context,
            sourceRepository: .github(
                checkoutPath: "/Users/username/path/to",
                sourceServiceBaseURL: URL(string: "https://example.com/repo")!
            )
        )

        #expect(renderNode.kind == .symbol)
        // The symbol's remote source still comes from its symbol graph location, not the doc extension markdown file.
        #expect(renderNode.metadata.remoteSource?.fileName == "SomeFile.swift")
    }

    // MARK: - Articles

    private func makeArticleCatalog() -> Folder {
        Folder(name: "unit-test.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .class, pathComponents: ["SomeClass"])
            ]))

            TextFile(name: "Article.md", utf8Content: """
            # Some Article

            An abstract for the article.
            """)
        }
    }

    @Test
    func emitsRemoteSourceForArticleWhenSourceRepositoryIsConfigured() async throws {
        let context = try await load(catalog: makeArticleCatalog())
        let article = try node(in: context, ofKind: .article)

        let renderNode = try renderNode(
            for: article,
            in: context,
            sourceRepository: .github(checkoutPath: "/", sourceServiceBaseURL: URL(string: "https://example.com/repo")!)
        )

        #expect(renderNode.metadata.remoteSource == RenderMetadata.RemoteSource(
            fileName: "Article.md",
            url: URL(string: "https://example.com/repo/unit-test.docc/Article.md")!
        ))
    }

    @Test
    func doesNotEmitRemoteSourceForArticleWhenNoSourceRepositoryIsConfigured() async throws {
        let context = try await load(catalog: makeArticleCatalog())
        let article = try node(in: context, ofKind: .article)

        let renderNode = try renderNode(for: article, in: context, sourceRepository: nil)

        #expect(renderNode.metadata.remoteSource == nil)
    }

    // MARK: - Tutorials

    @Test
    func emitsRemoteSourceForTutorialContent() async throws {
        let catalog = Folder(name: "unit-test.docc") {
            TextFile(name: "TableOfContents.tutorial", utf8Content: """
            @Tutorials(name: "TechnologyX") {
               @Intro(title: "Technology X") {
                  You'll learn all about Technology X.
               }

               @Chapter(name: "Chapter 1") {
                  In this chapter, you'll follow the tutorial and the tutorial article below.

                  @Image(source: figure1.png, alt: "Figure 1")

                  @TutorialReference(tutorial: "doc:BasicTutorial")
                  @TutorialReference(tutorial: "doc:TutorialArticle")
               }
            }
            """)

            TextFile(name: "BasicTutorial.tutorial", utf8Content: """
            @Tutorial(time: 20) {
               @Intro(title: "Basic Tutorial") {
                  This is the tutorial abstract.
               }

               @Section(title: "Create a New Project") {
                  @ContentAndMedia {
                     This is a section.
                  }

                  @Steps {
                     @Step {
                        This is a step.

                        @Image(source: step.png, alt: "Step image")
                     }
                  }
               }
            }
            """)

            TextFile(name: "TutorialArticle.tutorial", utf8Content: """
            @Article(time: 20) {
               @Intro(title: "A Tutorial Article") {
                  This is an abstract.
               }

               Some content.
            }
            """)

            DataFile(name: "figure1.png", data: Data())
            DataFile(name: "step.png", data: Data())
        }
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")

        let sourceRepository = SourceRepository.github(checkoutPath: "/", sourceServiceBaseURL: URL(string: "https://example.com/repo")!)

        let tableOfContents = try node(in: context, ofKind: .tutorialTableOfContents)
        let tableOfContentsRenderNode = try renderNode(for: tableOfContents, in: context, sourceRepository: sourceRepository)
        #expect(tableOfContentsRenderNode.metadata.remoteSource == RenderMetadata.RemoteSource(
            fileName: "TableOfContents.tutorial",
            url: URL(string: "https://example.com/repo/unit-test.docc/TableOfContents.tutorial")!
        ))
        // The link points at the top of the page; there's no single meaningful line to anchor to.
        #expect(tableOfContentsRenderNode.metadata.remoteSource?.url.fragment == nil)

        let tutorial = try node(in: context, ofKind: .tutorial)
        let tutorialRenderNode = try renderNode(for: tutorial, in: context, sourceRepository: sourceRepository)
        #expect(tutorialRenderNode.metadata.remoteSource == RenderMetadata.RemoteSource(
            fileName: "BasicTutorial.tutorial",
            url: URL(string: "https://example.com/repo/unit-test.docc/BasicTutorial.tutorial")!
        ))

        let tutorialArticle = try node(in: context, ofKind: .tutorialArticle)
        let tutorialArticleRenderNode = try renderNode(for: tutorialArticle, in: context, sourceRepository: sourceRepository)
        #expect(tutorialArticleRenderNode.metadata.remoteSource == RenderMetadata.RemoteSource(
            fileName: "TutorialArticle.tutorial",
            url: URL(string: "https://example.com/repo/unit-test.docc/TutorialArticle.tutorial")!
        ))
    }
}
