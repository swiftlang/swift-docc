/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import SymbolKit
import DocCTestUtilities
@testable import SwiftDocC

@Suite struct ProseSymbolNameTests {

    // MARK: - Helpers

    private func makeMethod(
        title: String,
        prose: String?,
        language: SourceLanguage = .swift
    ) -> SymbolGraph.Symbol {
        var symbol = makeSymbol(
            id: "method-id",
            language: language,
            kind: .func,
            pathComponents: ["Canopy", title]
        )
        symbol.names = SymbolGraph.Symbol.Names(
            title: title,
            navigator: symbol.names.navigator,
            subHeading: symbol.names.subHeading,
            prose: prose
        )
        return symbol
    }

    private func loadedContext(swiftProse: String?, objcProse: String?) async throws -> DocumentationContext {
        let swiftMethod = makeMethod(
            title: "calculateLightPenetration(_:)",
            prose: swiftProse,
            language: .swift
        )
        let objcMethod = makeMethod(
            title: "calculateLightPenetrationWithAngle:",
            prose: objcProse,
            language: .objectiveC
        )
        return try await load(catalog: Folder(name: "unit-test.docc") {
            JSONFile(name: "unit-test.symbols.json",
                     content: makeSymbolGraph(moduleName: "unit-test", symbols: [swiftMethod]))
            JSONFile(name: "unit-test.occ.symbols.json",
                     content: makeSymbolGraph(moduleName: "unit-test", symbols: [objcMethod]))
        })
    }

    // MARK: - Data interface language

    private func makeDataMethod(title: String, prose: String?) -> SymbolGraph.Symbol {
        var symbol = makeSymbol(
            id: "method-id",
            language: .data,
            kind: .func,
            pathComponents: ["Canopy", title]
        )
        symbol.names = SymbolGraph.Symbol.Names(
            title: title,
            navigator: symbol.names.navigator,
            subHeading: symbol.names.subHeading,
            prose: prose
        )
        return symbol
    }

    private func loadedDataContext(prose: String?) async throws -> DocumentationContext {
        let method = makeDataMethod(title: "calculateLightPenetration(sunAngle)", prose: prose)
        return try await load(catalog: Folder(name: "unit-test.docc") {
            JSONFile(name: "unit-test.data.symbols.json",
                     content: makeSymbolGraph(moduleName: "unit-test", symbols: [method]))
        })
    }

    @Test func dataSymbolProseNameIsUsedForInlineLinkTitle() async throws {
        let context = try await loadedDataContext(prose: "calculateLightPenetration")
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let variants = try #require(resolver.title(for: node))

        let dataTrait = DocumentationDataVariantsTrait(interfaceLanguage: SourceLanguage.data.id)
        #expect(variants[dataTrait] == "calculateLightPenetration")
    }

    @Test func dataSymbolTitleIsUsedWhenProseIsNotSet() async throws {
        let context = try await loadedDataContext(prose: nil)
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let variants = try #require(resolver.title(for: node))

        let dataTrait = DocumentationDataVariantsTrait(interfaceLanguage: SourceLanguage.data.id)
        #expect(variants[dataTrait] == "calculateLightPenetration(sunAngle)")
    }

    // MARK: - LinkTitleResolver

    @Test func proseNameIsUsedForInlineLinkTitle() async throws {
        let context = try await loadedContext(swiftProse: "calculateLightPenetration", objcProse: nil)
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let variants = try #require(resolver.title(for: node))

        // Swift variant has prose — should use it.
        #expect(variants[.swift] == "calculateLightPenetration")
        // ObjC variant has no prose — should fall back to its title.
        #expect(variants[.objectiveC] == "calculateLightPenetrationWithAngle:")
    }

    @Test func titleIsUsedForAllVariantsWhenProseIsNotSet() async throws {
        let context = try await loadedContext(swiftProse: nil, objcProse: nil)
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let variants = try #require(resolver.title(for: node))

        #expect(variants[.swift] == "calculateLightPenetration(_:)")
        #expect(variants[.objectiveC] == "calculateLightPenetrationWithAngle:")
    }

    @Test func proseIsUsedForAllVariantsWhenAllHaveProse() async throws {
        let context = try await loadedContext(
            swiftProse: "calculateLightPenetration",
            objcProse: "calculateLightPenetration"
        )
        let resolver = LinkTitleResolver(context: context, source: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let variants = try #require(resolver.title(for: node))

        #expect(variants[.swift] == "calculateLightPenetration")
        #expect(variants[.objectiveC] == "calculateLightPenetration")
    }

    // MARK: - LinkDestinationSummary

    @Test func linkDestinationSummaryUsesProseName() async throws {
        let context = try await loadedContext(swiftProse: "calculateLightPenetration", objcProse: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(
            node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first
        )

        // The summary title should use the prose form, not the full title.
        #expect(summary.title == "calculateLightPenetration")
    }

    @Test func linkDestinationSummaryUsesTitleWhenProseNotSet() async throws {
        let context = try await loadedContext(swiftProse: nil, objcProse: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(
            node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first
        )

        #expect(summary.title == "calculateLightPenetration(_:)")
    }

    // MARK: - Static HTML (HTMLRenderer.makeNames)

    @Test func staticHTMLInlineLinkUsesProseName() async throws {
        // Create a container symbol whose docComment links to the method.
        let container = makeSymbol(id: "canopy-id", kind: .class, pathComponents: ["Canopy"],
                                   docComment: "Call ``calculateLightPenetration(_:)`` to measure light.")
        let method = makeMethod(title: "calculateLightPenetration(_:)", prose: "calculateLightPenetration")

        let context = try await load(catalog: Folder(name: "unit-test.docc") {
            JSONFile(name: "unit-test.symbols.json", content: makeSymbolGraph(
                moduleName: "unit-test",
                symbols: [container, method],
                relationships: [.init(source: "method-id", target: "canopy-id", kind: .memberOf, targetFallback: nil)]
            ))
        })

        let canopyReference = try #require(context.documentationCache.reference(symbolID: "canopy-id"))
        let canopyNode = try context.entity(with: canopyReference)
        let canopySemantic = try #require(canopyNode.semantic as? Symbol)

        var renderer = HTMLRenderer(reference: canopyReference, context: context, goal: .richness,
                                    featureFlags: .init())
        let rendered = renderer.renderSymbol(canopySemantic)

        // HTMLRenderer inserts <wbr> word-break elements inside long identifiers.
        // Strip them before checking so we can match the plain text of the link.
        let html = rendered.content.xmlString.replacingOccurrences(of: "<wbr></wbr>", with: "")

        // The inline link in the prose paragraph should use the prose form (no parameter label).
        // It appears as: <code>calculateLightPenetration</code> inside an <a> tag.
        #expect(html.contains(">calculateLightPenetration<"))
    }

    // MARK: - Markdown output (MarkdownOutputMarkdownWalker)

    @Test func markdownOutputInlineLinkUsesProseName() async throws {
        // Create a container with a docComment that links to the method.
        let container = makeSymbol(id: "canopy-id", kind: .class, pathComponents: ["Canopy"],
                                   docComment: "Call ``calculateLightPenetration(_:)`` to measure light.")
        let method = makeMethod(title: "calculateLightPenetration(_:)", prose: "calculateLightPenetration")

        let context = try await load(catalog: Folder(name: "unit-test.docc") {
            JSONFile(name: "unit-test.symbols.json", content: makeSymbolGraph(
                moduleName: "unit-test",
                symbols: [container, method],
                relationships: [.init(source: "method-id", target: "canopy-id", kind: .memberOf, targetFallback: nil)]
            ))
        })

        let canopyReference = try #require(context.documentationCache.reference(symbolID: "canopy-id"))
        let canopyNode = try context.entity(with: canopyReference)
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: canopyNode)
        let visitorOutput = visitor.createOutput()
        let markdownNode = try #require(visitorOutput)

        // The markdown link text should use the prose form of the method name.
        #expect(markdownNode.markdown.contains("`calculateLightPenetration`"))
        #expect(!markdownNode.markdown.contains("`calculateLightPenetration(_:)`"))
    }
}
