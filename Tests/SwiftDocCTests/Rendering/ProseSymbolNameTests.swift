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

struct ProseSymbolNameTests {
    // The symbol has the same precise identifier in both languages so that the
    // Swift and Objective-C symbol graphs merge into a single multi-language symbol.
    // The titles and prose names are deliberately self-identifying (and share no common
    // substring across languages) so that each assertion is unambiguous.
    static let symbolID = "method-id"
    static let swiftTitle = "swiftSymbolTitle(with:)"
    static let objcTitle = "objcSymbolTitle:"

    // MARK: - Setups

    // Each setup is verified across *all* output formats (see `assertAllFormats`) so that
    // it's easy to see that the same behavior is covered consistently for every format,
    // and so that a future output format only needs to be added in one place.

    /// A symbol that has both a Swift and an Objective-C representation.
    struct MultiLanguageSetup: CustomTestStringConvertible {
        let name: String
        let swiftProse: String?
        let objcProse: String?
        /// The Swift-only `<code>` contents (with `<wbr>` word breaks) expected in the static HTML.
        let expectedSwiftHTML: String
        /// The Objective-C-only `<code>` contents (with `<wbr>` word breaks) expected in the static HTML.
        let expectedObjCHTML: String

        var expectedSwiftText: String { swiftProse ?? swiftTitle }
        var expectedObjCText: String { objcProse ?? objcTitle }
        /// The markdown renderer accesses `firstValue` of a multi-language symbol, so an
        /// Objective-C-only prose name bleeds into the Swift rendering path.
        var markdownHasKnownIssue: Bool { swiftProse == nil && objcProse != nil }

        var testDescription: String { name }
    }

    /// A symbol that only has a single-language representation.
    struct SingleLanguageSetup: CustomTestStringConvertible {
        let name: String
        let prose: String?
        /// The `<code>` contents (with `<wbr>` word breaks) expected in the static HTML.
        let expectedHTML: String

        var expectedText: String { prose ?? swiftTitle }

        var testDescription: String { name }
    }

    // MARK: - Tests

    @Test(arguments: [
        MultiLanguageSetup(name: "Swift prose only",
                           swiftProse: "swiftProseName", objcProse: nil,
                           expectedSwiftHTML: "swift<wbr></wbr>Prose<wbr></wbr>Name",
                           expectedObjCHTML: "objc<wbr></wbr>Symbol<wbr></wbr>Title:"),
        MultiLanguageSetup(name: "Objective-C prose only",
                           swiftProse: nil, objcProse: "objcProseName",
                           expectedSwiftHTML: "swift<wbr></wbr>Symbol<wbr></wbr>Title(<wbr></wbr>with:)",
                           expectedObjCHTML: "objc<wbr></wbr>Prose<wbr></wbr>Name"),
        MultiLanguageSetup(name: "Both languages have prose",
                           swiftProse: "swiftProseName", objcProse: "objcProseName",
                           expectedSwiftHTML: "swift<wbr></wbr>Prose<wbr></wbr>Name",
                           expectedObjCHTML: "objc<wbr></wbr>Prose<wbr></wbr>Name"),
        MultiLanguageSetup(name: "Neither language has prose",
                           swiftProse: nil, objcProse: nil,
                           expectedSwiftHTML: "swift<wbr></wbr>Symbol<wbr></wbr>Title(<wbr></wbr>with:)",
                           expectedObjCHTML: "objc<wbr></wbr>Symbol<wbr></wbr>Title:"),
    ])
    func usesProseNameForInlineLinkTextInAllOutputFormats(_ setup: MultiLanguageSetup) async throws {
        let (context, reference) = try await loadMultiLanguageContext(
            swiftProse: setup.swiftProse, objcProse: setup.objcProse
        )
        try assertAllFormats(
            context: context, reference: reference,
            expectedSwift: (setup.expectedSwiftText, setup.expectedSwiftHTML),
            expectedObjC: (setup.expectedObjCText, setup.expectedObjCHTML),
            markdownHasKnownIssue: setup.markdownHasKnownIssue
        )
    }

    @Test(arguments: [
        SingleLanguageSetup(name: "Prose set",
                            prose: "singleProseName",
                            expectedHTML: "single<wbr></wbr>Prose<wbr></wbr>Name"),
        SingleLanguageSetup(name: "Prose not set",
                            prose: nil,
                            expectedHTML: "swift<wbr></wbr>Symbol<wbr></wbr>Title(<wbr></wbr>with:)"),
    ])
    func usesProseNameForSingleLanguageSymbolInAllOutputFormats(_ setup: SingleLanguageSetup) async throws {
        let (context, reference) = try await loadSingleLanguageContext(prose: setup.prose)
        try assertAllFormats(
            context: context, reference: reference,
            expectedSwift: (setup.expectedText, setup.expectedHTML),
            expectedObjC: nil,
            markdownHasKnownIssue: false
        )
    }

    // MARK: - Shared assertions

    /// Verifies that the inline-link text for the loaded symbol matches the expected title/prose
    /// name in every output format.
    ///
    /// A new output format should be verified by adding a section to this method so that every
    /// setup automatically covers it.
    ///
    /// - Parameters:
    ///   - expectedSwift: The expected inline-link text and static-HTML `<code>` contents for the
    ///     Swift representation (or the single language representation).
    ///   - expectedObjC: The same for the Objective-C representation, or `nil` for a symbol that
    ///     only has a single-language representation.
    ///   - markdownHasKnownIssue: Whether the markdown output is expected to be incorrect because
    ///     the markdown renderer doesn't support multi-language symbols.
    private func assertAllFormats(
        context: DocumentationContext,
        reference: ResolvedTopicReference,
        expectedSwift: (text: String, html: String),
        expectedObjC: (text: String, html: String)?,
        markdownHasKnownIssue: Bool
    ) throws {
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)

        // A. RenderNode inline link.
        let inlineLinkReference = try #require(
            renderNode.references[reference.absoluteString] as? TopicRenderReference
        )
        assertTitleVariants(inlineLinkReference, expectedSwift: expectedSwift.text, expectedObjC: expectedObjC?.text)

        // B. External reference (LinkDestinationSummary).
        let summary = try #require(
            node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first
        )
        assertTitleVariants(summary.makeTopicRenderReference(), expectedSwift: expectedSwift.text, expectedObjC: expectedObjC?.text)

        // C. Static HTML — verify the word breaks land in the expected locations whether the link
        // text uses the symbol's title or its prose name.
        let symbol = try #require(node.semantic as? Symbol)
        var renderer = HTMLRenderer(reference: reference, context: context, goal: .richness, featureFlags: .init())
        let html = renderer.renderSymbol(symbol).content.xmlString
        if let expectedObjC {
            #expect(html.contains(#"<code class="swift-only">\#(expectedSwift.html)</code>"#),
                    "Swift-only HTML missing expected code \(expectedSwift.html); got: \(html)")
            #expect(html.contains(#"<code class="occ-only">\#(expectedObjC.html)</code>"#),
                    "Objective-C-only HTML missing expected code \(expectedObjC.html); got: \(html)")
        } else {
            #expect(html.contains(#"<code>\#(expectedSwift.html)</code>"#),
                    "HTML missing expected code \(expectedSwift.html); got: \(html)")
        }

        // D. Markdown output.
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: node)
        let output = visitor.createOutput()
        let markdown = try #require(output).markdown
        func assertMarkdown() {
            #expect(markdown.contains("`\(expectedSwift.text)`"),
                    "Markdown missing expected inline code `\(expectedSwift.text)`; got: \(markdown)")
            // When a prose name replaces the title, the full title should not appear.
            if expectedSwift.text != Self.swiftTitle {
                #expect(!markdown.contains("`\(Self.swiftTitle)`"),
                        "Markdown unexpectedly contains the full title `\(Self.swiftTitle)`; got: \(markdown)")
            }
        }
        if markdownHasKnownIssue {
            withKnownIssue("Markdown renderer does not support multi-language symbols") {
                assertMarkdown()
            }
        } else {
            assertMarkdown()
        }
    }

    private func assertTitleVariants(
        _ reference: TopicRenderReference,
        expectedSwift: String,
        expectedObjC: String?
    ) {
        if let expectedObjC {
            #expect(reference.titleVariants.value(for: .swift) == expectedSwift,
                    "Unexpected Swift link text: \(reference.titleVariants.value(for: .swift))")
            #expect(reference.titleVariants.value(for: .objectiveC) == expectedObjC,
                    "Unexpected Objective-C link text: \(reference.titleVariants.value(for: .objectiveC))")
        } else {
            #expect(reference.titleVariants.defaultValue == expectedSwift,
                    "Unexpected link text: \(reference.titleVariants.defaultValue)")
        }
    }

    // MARK: - Context loading

    private func loadMultiLanguageContext(
        swiftProse: String?,
        objcProse: String?
    ) async throws -> (context: DocumentationContext, reference: ResolvedTopicReference) {
        var swiftFunction = makeSymbol(id: Self.symbolID, language: .swift, kind: .func,
                                       pathComponents: [Self.swiftTitle],
                                       docComment: "Call ``\(Self.swiftTitle)`` to do something.")
        swiftFunction.names.prose = swiftProse
        var objcFunction = makeSymbol(id: Self.symbolID, language: .objectiveC, kind: .func,
                                      pathComponents: [Self.objcTitle])
        objcFunction.names.prose = objcProse

        let context = try await load(catalog: Folder(name: "ModuleName.docc") {
            JSONFile(name: "ModuleName.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [swiftFunction]))
            JSONFile(name: "ModuleName.occ.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [objcFunction]))
        })
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")

        let reference = try #require(context.documentationCache.reference(symbolID: Self.symbolID))
        return (context, reference)
    }

    private func loadSingleLanguageContext(
        prose: String?
    ) async throws -> (context: DocumentationContext, reference: ResolvedTopicReference) {
        var function = makeSymbol(id: Self.symbolID, language: .swift, kind: .func,
                                  pathComponents: [Self.swiftTitle],
                                  docComment: "Call ``\(Self.swiftTitle)`` to do something.")
        function.names.prose = prose

        let context = try await load(catalog: Folder(name: "ModuleName.docc") {
            JSONFile(name: "ModuleName.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [function]))
        })
        #expect(context.diagnostics.isEmpty, "Unexpected problems: \(context.diagnostics.map(\.summary))")

        let reference = try #require(context.documentationCache.reference(symbolID: Self.symbolID))
        return (context, reference)
    }
}
