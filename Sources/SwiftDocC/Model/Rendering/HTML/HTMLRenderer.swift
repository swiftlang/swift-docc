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
    
    func element(for url: URL) -> LinkedElement? {
        guard url.scheme == "doc",
              let rawBundleID = url.host,
              // TODO: Support returning information about external pages (rdar://165912415)
              let node = context.documentationCache[ResolvedTopicReference(bundleID: .init(rawValue: rawBundleID), path: url.path, fragment: url.fragment, sourceLanguage: .swift /* The reference's language doesn't matter */)]
        else {
            return nil
        }
        
        let names: LinkedElement.Names
        if let symbol = node.semantic as? Symbol,
           case .symbol(let primaryTitle) = node.name
        {
            // Check if this symbol has any language-specific titles
            let titles = symbol.titleVariants.allValues
            if titles.contains(where: { _, title in title != primaryTitle }) {
                // This symbol has multiple unique names
                let titles = [SourceLanguage: String](
                    titles.map { trait, title in
                        (trait.sourceLanguage ?? .swift, title)
                    },
                    uniquingKeysWith: { _, new in new }
                )
                
                names = .languageSpecificSymbol(titles)
            } else {
                // There are multiple names, but the're all the same
                names = .single(.symbol(primaryTitle))
            }
        } else {
            let name: LinkedElement.Name = switch node.name {
                case .conceptual(let title):   .conceptual(title)
                case .symbol(name: let title): .symbol(title)
            }
            names = .single(name)
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
        
        let subheadings: DocCHTML.LinkedElement.Subheadings
        if let symbol = node.semantic as? Symbol {
            // Check if this symbol has any language-specific _sub headings_
            let primarySubheading = symbol.subHeading
            let allSubheadings = symbol.subHeadingVariants.allValues
            
            if allSubheadings.contains(where: { _, title in title != primarySubheading }) {
                // This symbol has multiple unique subheadings
                subheadings = .languageSpecificSymbol(.init(
                    allSubheadings.map { trait, subheading in (
                        key:   trait.sourceLanguage ?? .swift,
                        value: convert(subheading)
                    )},
                    uniquingKeysWith: { _, new in new }
                ))
            } else {
                // There are multiple subheadings, but the're all the same
                subheadings = .single(.symbol(convert(primarySubheading ?? [])))
            }
        } else {
            subheadings = .single(.conceptual(node.name.plainText))
        }
        
        return .init(
            path: Self.filePath(for: node.reference),
            names: names,
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
            linkProvider: ContextLinkProvider(reference: reference, context: context)
        )
    }
    
    /// Information about a rendered page
    struct RenderedPageInfo {
        /// The HTML content of the page as an XMLNode hierarchy.
        ///
        /// The string representation of those node hierarchy is intended to be inserted _somewhere_ inside the `<body>` HTML element.
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
        
        return RenderedPageInfo(
            content: goal == .richness ? main : articleElement,
            metadata: .init(
                title: article.title?.plainText ?? node.name.plainText,
                plainDescription: article.abstract?.plainText
            )
        )
    }
    
    mutating func renderSymbol(_ symbol: Symbol) -> RenderedPageInfo {
        let node = context.documentationCache[reference]!
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        articleElement.addChild(hero)
        
        // Title
        let titleVariants = symbol.titleVariants.allValues.sorted(by: { $0.trait < $1.trait })
        for (trait, languageSpecificTitle) in titleVariants {
            guard let language = trait.sourceLanguage else { continue }
            
            let attributes: [String: String]?
            if goal == .richness, titleVariants.count < 1 {
                attributes = ["class": "\(language.id)-only"]
            } else {
                attributes = nil
            }
            
            hero.addChild(
                .element(named: "h1", children: renderer.wordBreak(symbolName: languageSpecificTitle), attributes: attributes)
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
