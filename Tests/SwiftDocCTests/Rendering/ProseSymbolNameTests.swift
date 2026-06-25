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
    // MARK: - Helpers

    private func loadedContext(swiftProse: String?, objcProse: String?) async throws -> DocumentationContext {
        var swiftFunction = makeSymbol(id: "method-id", language: .swift, kind: .func, pathComponents: ["doSomething(with:)"])
        swiftFunction.names.prose = swiftProse
        var objcFunction = makeSymbol(id: "method-id", language: .objectiveC, kind: .func, pathComponents: ["doSomethingWith:"])
        objcFunction.names.prose = objcProse
        return try await load(catalog: Folder(name: "ModuleName.docc") {
            JSONFile(name: "ModuleName.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [swiftFunction]))
            JSONFile(name: "ModuleName.occ.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [objcFunction]))
        })
    }

    private func loadedContextWithLinkedFunction(
        swiftProse: String?,
        objcProse: String?
    ) async throws -> (context: DocumentationContext, functionRef: ResolvedTopicReference) {
        var swiftFunction = makeSymbol(id: "method-id", language: .swift, kind: .func,
                                       pathComponents: ["doSomething(with:)"],
                                       docComment: "Call ``doSomething(with:)`` to do something.")
        swiftFunction.names.prose = swiftProse
        var objcFunction = makeSymbol(id: "method-id", language: .objectiveC, kind: .func, pathComponents: ["doSomethingWith:"])
        objcFunction.names.prose = objcProse

        let context = try await load(catalog: Folder(name: "ModuleName.docc") {
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName", symbols: [swiftFunction]
            ))
            JSONFile(name: "ModuleName.occ.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName", symbols: [objcFunction]
            ))
        })
        let functionRef = try #require(context.documentationCache.reference(symbolID: "method-id"))
        return (context, functionRef)
    }

    private func loadedSingleLanguageContextWithLinkedFunction(
        prose: String?
    ) async throws -> (context: DocumentationContext, functionRef: ResolvedTopicReference) {
        var function = makeSymbol(id: "method-id", language: .data, kind: .func,
                                  pathComponents: ["doSomething(with:)"],
                                  docComment: "Call ``doSomething(with:)`` to do something.")
        function.names.prose = prose

        let context = try await load(catalog: Folder(name: "ModuleName.docc") {
            JSONFile(name: "ModuleName.data.symbols.json",
                     content: makeSymbolGraph(moduleName: "ModuleName", symbols: [function]))
        })
        let functionRef = try #require(context.documentationCache.reference(symbolID: "method-id"))
        return (context, functionRef)
    }

    // MARK: - Single language presentation

    private func inlineLinkReferenceForSingleLanguage(prose: String?) async throws -> TopicRenderReference {
        let (context, functionRef) = try await loadedSingleLanguageContextWithLinkedFunction(prose: prose)
        let node = try context.entity(with: functionRef)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        return try #require(renderNode.references[functionRef.absoluteString] as? TopicRenderReference)
    }

    @Test
    func singleLanguageSymbolProseNameIsUsedForInlineLinkTitle() async throws {
        let ref = try await inlineLinkReferenceForSingleLanguage(prose: "doSomething")
        #expect(ref.titleVariants.defaultValue == "doSomething")
    }

    @Test
    func singleLanguageSymbolTitleIsUsedWhenProseIsNotSet() async throws {
        let ref = try await inlineLinkReferenceForSingleLanguage(prose: nil)
        #expect(ref.titleVariants.defaultValue == "doSomething(with:)")
    }

    // MARK: - Multi-language title variants

    private func inlineLinkReference(swiftProse: String?, objcProse: String?) async throws -> TopicRenderReference {
        let (context, functionRef) = try await loadedContextWithLinkedFunction(swiftProse: swiftProse, objcProse: objcProse)
        let node = try context.entity(with: functionRef)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        return try #require(renderNode.references[functionRef.absoluteString] as? TopicRenderReference)
    }

    @Test
    func proseNameIsUsedForInlineLinkTitle() async throws {
        let ref = try await inlineLinkReference(swiftProse: "doSomething", objcProse: nil)

        // Swift variant has prose — should use it.
        #expect(ref.titleVariants.value(for: .swift) == "doSomething")
        // ObjC variant has no prose — should fall back to its title.
        #expect(ref.titleVariants.value(for: .objectiveC) == "doSomethingWith:")
    }

    @Test
    func objcProseNameIsUsedForInlineLinkTitle() async throws {
        let ref = try await inlineLinkReference(swiftProse: nil, objcProse: "doSomethingWith")

        // Swift variant has no prose — should fall back to its title.
        #expect(ref.titleVariants.value(for: .swift) == "doSomething(with:)")
        // ObjC variant has prose — should use it.
        #expect(ref.titleVariants.value(for: .objectiveC) == "doSomethingWith")
    }

    @Test
    func titleIsUsedForAllVariantsWhenProseIsNotSet() async throws {
        let ref = try await inlineLinkReference(swiftProse: nil, objcProse: nil)

        #expect(ref.titleVariants.value(for: .swift) == "doSomething(with:)")
        #expect(ref.titleVariants.value(for: .objectiveC) == "doSomethingWith:")
    }

    @Test
    func proseIsUsedForAllVariantsWhenAllHaveProse() async throws {
        let ref = try await inlineLinkReference(swiftProse: "doSomething", objcProse: "doSomethingWith")

        #expect(ref.titleVariants.value(for: .swift) == "doSomething")
        #expect(ref.titleVariants.value(for: .objectiveC) == "doSomethingWith")
    }

    // MARK: - External references (LinkDestinationSummary)

    @Test
    func linkDestinationSummaryUsesProseName() async throws {
        let context = try await loadedContext(swiftProse: "doSomething", objcProse: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first)
        let topicRef = summary.makeTopicRenderReference()

        // Swift has prose — should use it.
        #expect(topicRef.titleVariants.value(for: .swift) == "doSomething")
        // ObjC has no prose — falls back to its own title.
        #expect(topicRef.titleVariants.value(for: .objectiveC) == "doSomethingWith:")
    }

    @Test
    func linkDestinationSummaryUsesObjcProseName() async throws {
        let context = try await loadedContext(swiftProse: nil, objcProse: "doSomethingWith")

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first)
        let topicRef = summary.makeTopicRenderReference()

        // Swift has no prose — falls back to its own title.
        #expect(topicRef.titleVariants.value(for: .swift) == "doSomething(with:)")
        // ObjC has prose — should use it.
        #expect(topicRef.titleVariants.value(for: .objectiveC) == "doSomethingWith")
    }

    @Test
    func linkDestinationSummaryUsesBothProseNames() async throws {
        let context = try await loadedContext(swiftProse: "doSomething", objcProse: "doSomethingWith")

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first)
        let topicRef = summary.makeTopicRenderReference()

        #expect(topicRef.titleVariants.value(for: .swift) == "doSomething")
        #expect(topicRef.titleVariants.value(for: .objectiveC) == "doSomethingWith")
    }

    @Test
    func linkDestinationSummaryUsesTitleWhenProseNotSet() async throws {
        let context = try await loadedContext(swiftProse: nil, objcProse: nil)

        let reference = try #require(context.documentationCache.reference(symbolID: "method-id"))
        let node = try context.entity(with: reference)
        let renderNode = DocumentationNodeConverter(context: context).convert(node)
        let summary = try #require(node.externallyLinkableElementSummaries(context: context, renderNode: renderNode).first)
        let topicRef = summary.makeTopicRenderReference()

        // Neither has prose — both fall back to their own full titles.
        #expect(topicRef.titleVariants.value(for: .swift) == "doSomething(with:)")
        #expect(topicRef.titleVariants.value(for: .objectiveC) == "doSomethingWith:")
    }

    // MARK: - Static HTML (HTMLRenderer.makeNames)

    private func renderedHTML(swiftProse: String?, objcProse: String?) async throws -> String {
        let (context, functionRef) = try await loadedContextWithLinkedFunction(swiftProse: swiftProse, objcProse: objcProse)
        let functionNode = try context.entity(with: functionRef)
        let functionSemantic = try #require(functionNode.semantic as? Symbol)
        var renderer = HTMLRenderer(reference: functionRef, context: context, goal: .richness, featureFlags: .init())
        let rendered = renderer.renderSymbol(functionSemantic)
        return rendered.content.xmlString
    }

    @Test
    func staticHTMLInlineLinkUsesSwiftProseName() async throws {
        let html = try await renderedHTML(swiftProse: "doSomething", objcProse: nil)
        #expect(html.contains(#"<code class="swift-only">do<wbr></wbr>Something</code>"#))
    }

    @Test
    func staticHTMLInlineLinkUsesSwiftTitleWhenOnlyObjcProseIsSet() async throws {
        let html = try await renderedHTML(swiftProse: nil, objcProse: "doSomethingWith")
        #expect(html.contains(#"<code class="swift-only">do<wbr></wbr>Something(<wbr></wbr>with:)</code>"#))
    }

    @Test
    func staticHTMLInlineLinkUsesSwiftProseWhenBothAreSet() async throws {
        let html = try await renderedHTML(swiftProse: "doSomething", objcProse: "doSomethingWith")
        #expect(html.contains(#"<code class="swift-only">do<wbr></wbr>Something</code>"#))
        #expect(html.contains(#"<code class="occ-only">do<wbr></wbr>Something<wbr></wbr>With</code>"#))
    }

    @Test
    func staticHTMLInlineLinkUsesTitleWhenProseNotSet() async throws {
        let html = try await renderedHTML(swiftProse: nil, objcProse: nil)
        #expect(html.contains(#"<code class="swift-only">do<wbr></wbr>Something(<wbr></wbr>with:)</code>"#))
        #expect(html.contains(#"<code class="occ-only">do<wbr></wbr>Something<wbr></wbr>With:</code>"#))
    }

    @Test
    func staticHTMLInlineLinkInSingleLanguageUsesProseName() async throws {
        let (context, functionRef) = try await loadedSingleLanguageContextWithLinkedFunction(prose: "doSomething")
        let functionNode = try context.entity(with: functionRef)
        let functionSemantic = try #require(functionNode.semantic as? Symbol)
        var renderer = HTMLRenderer(reference: functionRef, context: context, goal: .richness, featureFlags: .init())
        let html = renderer.renderSymbol(functionSemantic).content.xmlString
        #expect(html.contains(#"<code>do<wbr></wbr>Something</code>"#))
    }

    @Test
    func staticHTMLInlineLinkInSingleLanguageUsesTitleWhenProseNotSet() async throws {
        let (context, functionRef) = try await loadedSingleLanguageContextWithLinkedFunction(prose: nil)
        let functionNode = try context.entity(with: functionRef)
        let functionSemantic = try #require(functionNode.semantic as? Symbol)
        var renderer = HTMLRenderer(reference: functionRef, context: context, goal: .richness, featureFlags: .init())
        let html = renderer.renderSymbol(functionSemantic).content.xmlString
        #expect(html.contains(#"<code>do<wbr></wbr>Something(<wbr></wbr>with:)</code>"#))
    }

    // MARK: - Markdown output (MarkdownOutputMarkdownWalker)

    private func renderedMarkdown(swiftProse: String?, objcProse: String?) async throws -> String {
        let (context, functionRef) = try await loadedContextWithLinkedFunction(swiftProse: swiftProse, objcProse: objcProse)
        let functionNode = try context.entity(with: functionRef)
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: functionNode)
        let output = visitor.createOutput()
        return try #require(output).markdown
    }

    @Test
    func markdownOutputInlineLinkUsesSwiftProseName() async throws {
        let markdown = try await renderedMarkdown(swiftProse: "doSomething", objcProse: nil)
        #expect(markdown.contains("`doSomething`"))
        #expect(!markdown.contains("`doSomething(with:)`"))
    }

    @Test
    func markdownOutputInlineLinkUsesSwiftTitleWhenOnlyObjcProseIsSet() async throws {
        let markdown = try await renderedMarkdown(swiftProse: nil, objcProse: "doSomethingWith")
        // The markdown renderer does not support multi-language symbols and uses firstValue,
        // which bleeds ObjC-only prose into the Swift rendering path.
        withKnownIssue("Markdown renderer does not support multi-language symbols") {
            #expect(markdown.contains("`doSomething(with:)`"))
        }
    }

    @Test
    func markdownOutputInlineLinkUsesSwiftProseWhenBothAreSet() async throws {
        let markdown = try await renderedMarkdown(swiftProse: "doSomething", objcProse: "doSomethingWith")
        #expect(markdown.contains("`doSomething`"))
        #expect(!markdown.contains("`doSomething(with:)`"))
    }

    @Test
    func markdownOutputInlineLinkUsesTitleWhenProseNotSet() async throws {
        let markdown = try await renderedMarkdown(swiftProse: nil, objcProse: nil)
        #expect(markdown.contains("`doSomething(with:)`"))
    }

    @Test
    func markdownOutputInlineLinkInSingleLanguageUsesProseName() async throws {
        let (context, functionRef) = try await loadedSingleLanguageContextWithLinkedFunction(prose: "doSomething")
        let functionNode = try context.entity(with: functionRef)
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: functionNode)
        let output = visitor.createOutput()
        let markdown = try #require(output).markdown
        #expect(markdown.contains("`doSomething`"))
        #expect(!markdown.contains("`doSomething(with:)`"))
    }

    @Test
    func markdownOutputInlineLinkInSingleLanguageUsesTitleWhenProseNotSet() async throws {
        let (context, functionRef) = try await loadedSingleLanguageContextWithLinkedFunction(prose: nil)
        let functionNode = try context.entity(with: functionRef)
        var visitor = MarkdownOutputSemanticVisitor(context: context, node: functionNode)
        let output = visitor.createOutput()
        let markdown = try #require(output).markdown
        #expect(markdown.contains("`doSomething(with:)`"))
    }
}
