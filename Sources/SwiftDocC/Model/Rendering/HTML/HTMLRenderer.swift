/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif
import DocCHTML
import Markdown
import SymbolKit

/// A link provider that provider structured information about resolved links and assets to the underlying HTML renderer.
private struct ContextLinkProvider: LinkProvider {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    let goal: RenderGoal
    
    func element(for url: URL) -> LinkedElement? {
        guard url.scheme == "doc",
              let rawBundleID = url.host,
              // TODO: Support returning information about external pages (rdar://165912415)
              let node = context.documentationCache[ResolvedTopicReference(bundleID: .init(rawValue: rawBundleID), path: url.path, fragment: url.fragment, sourceLanguage: .swift /* The reference's language doesn't matter */)]
        else {
            return nil
        }
        
        // A helper function that transforms SymbolKit fragments into renderable identifier/decorator fragments
        func convert(_ fragments: [SymbolGraph.Symbol.DeclarationFragments.Fragment]) -> [LinkedElement.SymbolNameFragment] {
            func convert(kind: SymbolGraph.Symbol.DeclarationFragments.Fragment.Kind) -> LinkedElement.SymbolNameFragment.Kind {
                switch kind {
                    case .identifier, .externalParameter: .identifier
                    default:                              .decorator
                }
            }
            guard var current = fragments.first.map({ LinkedElement.SymbolNameFragment(text: $0.spelling, kind: convert(kind: $0.kind)) }) else {
                return []
            }
            
            // Join together multiple fragments of the same identifier/decorator kind to produce a smaller output.
            var result: [LinkedElement.SymbolNameFragment] = []
            for fragment in fragments.dropFirst() {
                let kind = convert(kind: fragment.kind)
                if kind == current.kind  {
                    current.text += fragment.spelling
                } else {
                    result.append(current)
                    current = .init(text: fragment.spelling, kind: kind)
                }
            }
            result.append(current)
            return result
        }
        
        let subheadings: LinkedElement.Subheadings = if let symbol = node.semantic as? Symbol {
            switch symbol.subHeadingVariants.values(goal: goal) {
                case .single(let subHeading):
                    .single(.symbol(convert(subHeading)))
                case .languageSpecific(let subHeadings):
                    .languageSpecificSymbol(subHeadings.mapValues(convert))
                case .empty:
                    // This shouldn't happen but because of a shortcoming in the API design of `DocumentationDataVariants`, it can't be guaranteed.
                    .single(.symbol([]))
            }
        } else {
            .single(.conceptual(node.name.plainText))
        }
        
        return .init(
            path: Self.filePath(for: node.reference),
            names: node.makeNames(goal: goal),
            subheadings: subheadings,
            abstract: (node.semantic as? (any Abstracted))?.abstract
        )
    }
    
    func pathForSymbolID(_ usr: String) -> URL? {
        context.localOrExternalReference(symbolID: usr).map {
            Self.filePath(for: $0)
        }
    }
    
    func assetNamed(_ assetName: String) -> LinkedAsset? {
        guard let asset = context.resolveAsset(named: assetName, in: reference) else {
            // The context
            return nil
        }
        
        var files = [LinkedAsset.ColorStyle: [Int: URL]]()
        for (traits, url) in asset.variants {
            let scale = (traits.displayScale ?? .standard).scaleFactor
            
            files[traits.userInterfaceStyle == .dark ? .dark : .light, default: [:]][scale] = url
        }
        
        return .init(files: files)
    }
    
    func fallbackLinkText(linkString: String) -> String {
        // For unresolved links, especially to symbols, prefer to display only the the last link component without its disambiguation
        PathHierarchy.PathParser.parse(path: linkString).components.last.map { String($0.name) } ?? linkString
    }
    
    static func filePath(for reference: ResolvedTopicReference) -> URL {
        reference.url.withoutHostAndPortAndScheme().appendingPathComponent("index.html")
    }
}

// MARK: HTML Renderer

/// A type that renders documentation pages into semantic HTML elements.
struct HTMLRenderer {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    let goal: RenderGoal
    
    private let renderer: MarkdownRenderer<ContextLinkProvider>
    
    init(reference: ResolvedTopicReference, context: DocumentationContext, goal: RenderGoal) {
        self.reference = reference
        self.context = context
        self.goal = goal
        self.renderer = MarkdownRenderer(
            path: ContextLinkProvider.filePath(for: reference),
            goal: goal,
            linkProvider: ContextLinkProvider(reference: reference, context: context, goal: goal)
        )
    }
    
    /// Information about a rendered page
    struct RenderedPageInfo {
        /// The HTML content of the page as an XMLNode hierarchy.
        ///
        /// The string representation of this node hierarchy is intended to be inserted _somewhere_ inside the `<body>` HTML element.
        /// It _doesn't_ include a page header, footer, navigator, etc. and may be an insufficient representation of the "entire" page
        var content: XMLNode
        /// The title and description/abstract of the page.
        var metadata: Metadata
        /// Meta information about the page that belongs in the HTML `<head>` element.
        struct Metadata {
            /// The plain text title of this page, suitable as content for the HTML `<title>` element.
            var title: String
            /// The plain text description/abstract of this page, suitable a data for a `<meta>` element for sharing purposes.
            var plainDescription: String?
        }
    }
    
    mutating func renderArticle(_ article: Article) -> RenderedPageInfo {
        let node = context.documentationCache[reference]!
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        articleElement.addChild(hero)
        
        // Title
        hero.addChild(
            .element(named: "h1", children: [.text(node.name.plainText)])
        )
        
        // Abstract
        if let abstract = article.abstract {
            let paragraph = renderer.visit(abstract) as! XMLElement
            if goal == .richness {
                paragraph.addAttribute(XMLNode.attribute(withName: "id", stringValue: "abstract") as! XMLNode)
            }
            hero.addChild(paragraph)
        }
        
        // Discussion
        if let discussion = article.discussion {
            articleElement.addChildren(
                renderer.discussion(discussion.content, fallbackSectionName: "Overview")
            )
        }
        
        return RenderedPageInfo(
            content: goal == .richness ? main : articleElement,
            metadata: .init(
                title: article.title?.plainText ?? node.name.plainText,
                plainDescription: article.abstract?.plainText
            )
        )
    }
    
    mutating func renderSymbol(_ symbol: Symbol) -> RenderedPageInfo {
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        articleElement.addChild(hero)
        
        // Title
        switch symbol.titleVariants.values(goal: goal) {
            case .single(let title):
                hero.addChild(
                    .element(named: "h1", children: renderer.wordBreak(symbolName: title))
                )
            case .languageSpecific(let languageSpecificTitles):
                for (language, languageSpecificTitle) in languageSpecificTitles.sorted(by: { $0.key < $1.key }) {
                    hero.addChild(
                        .element(named: "h1", children: renderer.wordBreak(symbolName: languageSpecificTitle), attributes: ["class": "\(language.id)-only"])
                    )
                }
            case .empty:
                // This shouldn't happen but because of a shortcoming in the API design of `DocumentationDataVariants`, it can't be guaranteed.
                hero.addChild(
                    .element(named: "h1", children: renderer.wordBreak(symbolName: symbol.title /* This is internally force unwrapped */))
                )
        }
        
        // Abstract
        if let abstract = symbol.abstract {
            let paragraph = renderer.visit(abstract) as! XMLElement
            if goal == .richness {
                paragraph.addAttribute(XMLNode.attribute(withName: "id", stringValue: "abstract") as! XMLNode)
            }
            hero.addChild(paragraph)
        }
        
        // Discussion
        if let discussion = symbol.discussion {
            articleElement.addChildren(
                renderer.discussion(discussion.content, fallbackSectionName: symbol.kind.identifier.swiftSymbolCouldHaveChildren ? "Overview" : "Discussion")
            )
        }
        
        return RenderedPageInfo(
            content: goal == .richness ? main : articleElement,
            metadata: .init(
                title: symbol.title,
                plainDescription: symbol.abstract?.plainText
            )
        )
    }
    
    // TODO: As a future enhancement, add another layer on top of this that creates complete HTML pages (both `<head>` and `<body>`) (rdar://165912669)
}

// MARK: Helpers

// Note; this isn't a Comparable conformance so that it can remain private to this file.
private extension DocumentationDataVariantsTrait {
    static func < (lhs: DocumentationDataVariantsTrait, rhs: DocumentationDataVariantsTrait) -> Bool {
        if let lhs = lhs.sourceLanguage {
            if let rhs = rhs.sourceLanguage {
                return lhs < rhs
            }
            return true // nil is after anything
        }
        return false // nil is after anything
    }
}

private extension XMLElement {
    func addChildren(_ nodes: [XMLNode]) {
        for node in nodes {
            addChild(node)
        }
    }
}

private extension DocumentationNode {
    func makeNames(goal: RenderGoal) -> LinkedElement.Names {
        switch name {
        case .conceptual(let title):
            // This node has a single "conceptual" name.
            // It could either be an article or a symbol with an authored `@DisplayName`.
            .single(.conceptual(title))
        case .symbol(let nodeTitle):
            if let symbol = semantic as? Symbol {
                symbol.makeNames(goal: goal, fallbackTitle: nodeTitle)
            } else {
                // This node has a symbol name, but for some reason doesn't have a symbol semantic.
                // That's a bit strange and unexpected, but we can still make a single name for it.
                .single(.symbol(nodeTitle))
            }
        }
    }
}

private extension Symbol {
    func makeNames(goal: RenderGoal, fallbackTitle: String) -> LinkedElement.Names {
        switch titleVariants.values(goal: goal) {
            case .single(let title):
                .single(.symbol(title))
            case .languageSpecific(let titles):
                .languageSpecificSymbol(titles)
            case .empty:
                // This shouldn't happen but because of a shortcoming in the API design of `DocumentationDataVariants`, it can't be guaranteed.
                .single(.symbol(fallbackTitle))
        }
    }
}

private enum VariantValues<Value> {
    case single(Value)
    case languageSpecific([SourceLanguage: Value])
    // This is necessary because of a shortcoming in the API design of `DocumentationDataVariants`.
    case empty
}

// Both `DocumentationDataVariants` and `VariantCollection` are really hard to work with correctly and neither offer a good API that both:
// - Makes a clear distinction between when a value will always exist and when the "values" can be empty.
// - Allows the caller to iterate over all the values.
// TODO: Design and implement a better solution for representing language specific variations of a value (rdar://166211961)
private extension DocumentationDataVariants where Variant: Equatable {
    func values(goal: RenderGoal) -> VariantValues<Variant> {
        guard let primaryValue = firstValue else {
            return .empty
        }
               
        guard goal == .richness else {
            // On the rendered page, language specific symbol information _could_ be hidden through CSS but that wouldn't help the tool that reads the raw HTML.
            // So that tools don't need to filter out language specific information themselves, include only the primary language's value.
            return .single(primaryValue)
        }
        
        let values = allValues
        guard allValues.count > 1 else {
            // Return a single value to simplify the caller's code
            return .single(primaryValue)
        }
        
        // Check if the variants has any language-specific values (that are _actually_ different from the primary value)
        if values.contains(where: { _, value in value != primaryValue }) {
            // There are multiple distinct values
            return .languageSpecific([SourceLanguage: Variant](
                values.map { trait, value in
                    (trait.sourceLanguage ?? .swift, value)
                }, uniquingKeysWith: { _, new in new }
            ))
        } else {
            // There are multiple values, but the're all the same
            return .single(primaryValue)
        }
    }
}
