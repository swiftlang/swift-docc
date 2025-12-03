/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// FIXME: See if we can avoid depending on XMLNode/XMLParser to avoid needing to import FoundationXML
import FoundationXML
import FoundationEssentials
#else
import Foundation
#endif
import DocCHTML
import Markdown
import SymbolKit

private struct ContextLinkProvider: DocCHTML.LinkProvider {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    
    func element(for url: URL) -> DocCHTML.LinkedElement? {
        guard url.scheme == "doc",
              let rawBundleID = url.host,
              let node = context.documentationCache[ResolvedTopicReference(bundleID: .init(rawValue: rawBundleID), path: url.path, fragment: url.fragment, sourceLanguage: .swift /* The reference's language doesn't matter */)]
        else {
            return nil
        }
        
        let names: DocCHTML.LinkedElement.Names
        if let symbol = node.semantic as? Symbol,
           case .symbol(let primaryTitle) = node.name
        {
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
            let name: DocCHTML.LinkedElement.Name = switch node.name {
                case .conceptual(let title):   .conceptual(title)
                case .symbol(name: let title): .symbol(title)
            }
            names = .single(name)
        }
        
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
            let primarySubheading = symbol.subHeading
            let allSubheadings = symbol.subHeadingVariants.allValues
            
            if allSubheadings.contains(where: { _, title in title != primarySubheading }) {
                // This symbol has multiple unique names
                subheadings = .languageSpecificSymbol(.init(
                    allSubheadings.map { trait, subheading in (
                        key:   trait.sourceLanguage ?? .swift,
                        value: convert(subheading)
                    )},
                    uniquingKeysWith: { _, new in new }
                ))
            } else {
                // There are multiple names, but the're all the same
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
    
    func assetNamed(_ assetName: String) -> DocCHTML.LinkedAsset? {
        guard let asset = context.resolveAsset(named: assetName, in: reference) else {
            return nil
        }
        
        var images = [DocCHTML.LinkedAsset.ColorStyle: [Int: URL]]()
        for (traits, url) in asset.variants {
            let scale = (traits.displayScale ?? .standard).scaleFactor
            
            images[traits.userInterfaceStyle == .dark ? .dark : .light, default: [:]][scale] = url
        }
        
        return .init(images: images)
    }
    
    func fallbackLinkText(linkString: String) -> String {
        // For unresolved links, especially to symbols, prefer to display only the the last link component without its disambiguation
        PathHierarchy.PathParser.parse(path: linkString).components.last.map { String($0.name) } ?? linkString
    }
    
    static func filePath(for reference: ResolvedTopicReference) -> URL {
        reference.url.withoutHostAndPortAndScheme().appendingPathComponent("index.html")
    }
}

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
    
    struct RenderedPageInfo {
        var content: XMLNode
        var metadata: Metadata
        struct Metadata {
            var title: String
            var plainDescription: String?
        }
    }
    
    mutating func renderArticle(_ article: Article) -> RenderedPageInfo {
        let node = context.documentationCache[reference]!
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        switch goal {
        case .richness:
            articleElement.addChild(
                .element(named: "div", children: [hero], attributes: ["id": article.topics != nil ? "hero-api" : "hero-article"])
            )
        case .conciseness:
            articleElement.addChild(hero)
        }
        
        // Breadcrumbs and Eyebrow
        hero.addChild(renderer.breadcrumbs(
            references: (context.shortestFinitePath(to: reference) ?? [context.soleRootModuleReference!]).map { $0.url },
            currentPageNames: .single(.conceptual(node.name.plainText))
        ))
        hero.addChild(.element(
            named: "p",
            children: [.text(article.topics == nil ? "Article": "API Collection")],
            attributes: ["id": "eyebrow"]
        ))
        
        // Title
        hero.addChild(
            .element(named: "h1", children: [.text(node.name.plainText)])
        )
        
        // Abstract
        if let abstract = article.abstract {
            let paragraph = renderer.visit(abstract) as! XMLElement
            
            paragraph.addAttribute(
                XMLNode.attribute(withName: "id", stringValue: "abstract") as! XMLNode
            )
            hero.addChild(paragraph)
        }
        
        // Discussion
        if let discussion = article.discussion {
            articleElement.addChildren(makeDiscussion(discussion, isSymbol: false))
        }
        
        func separateCurationIfNeeded() {
            guard goal == .richness, ((articleElement.children ?? []).last as? XMLElement)?.name == "section" else {
                return
            }
            
            articleElement.addChild(.element(named: "hr")) // Separate the sections with a thematic break
        }
        
        // Topics
        if let topics = article.topics {
            separateCurationIfNeeded()
            
            // TODO: Support language specific topic sections
            articleElement.addChildren(
                renderer.groupedSection(named: "Topics", groups: [
                    .swift: topics.taskGroups.map { group in
                        .init(title: group.heading?.title, content: group.content, references: group.links.compactMap {
                            $0.destination.flatMap { URL(string: $0) }
                        })
                    }
                ])
            )
        }
        // Articles don't have automatic topic sections
        
        // See Also
        if let seeAlso = article.seeAlso {
            separateCurationIfNeeded()
            
            articleElement.addChildren(
                renderer.groupedSection(named: "See Also", groups: [
                    .swift: seeAlso.taskGroups.map { group in
                        .init(title: group.heading?.title, content: group.content, references: group.links.compactMap {
                            $0.destination.flatMap { URL(string: $0) }
                        })
                    }
                ])
            )
        }
        // TODO: Add a way of determining the _automatic_ SeeAlso sections that doesn't query the JSON RenderContext for information.
        
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
        
        let isDeprecated = symbol.isDeprecated
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        if symbol.kind.identifier == .module, goal == .richness {
            articleElement.addChild(
                .element(named: "div", children: [hero], attributes: ["id": "hero-module"])
            )
        } else {
            articleElement.addChild(hero)
        }
        
        let names: LinkedElement.Names
        if case .conceptual(title: let title) = node.name {
            names = .single(.conceptual(title))
        } else {
            names = .languageSpecificSymbol([SourceLanguage: String](
                symbol.titleVariants.allValues.compactMap({ trait, title in
                    guard let language = trait.sourceLanguage else { return nil }
                    return (key: language, value: title)
                }),
                uniquingKeysWith: { _, new in new }
            ))
        }
        
        // Breadcrumbs and Eyebrow
        hero.addChild(renderer.breadcrumbs(
            references: (context.linkResolver.localResolver.breadcrumbs(of: reference, in: reference.sourceLanguage) ?? []).map { $0.url },
            currentPageNames: names
        ))
        hero.addChild(.element(
            named: "p",
            children: [.text(symbol.roleHeading)],
            attributes: goal == .richness ? ["id": "eyebrow"] : [:]
        ))
        
        // Title
        let titleVariants = symbol.titleVariants.allValues.sorted(by: { $0.trait < $1.trait})
        for (trait, variant) in titleVariants {
            guard let language = trait.sourceLanguage else { continue }
            
            var classes: [String] = []
            if titleVariants.count > 1 {
                classes.append("\(language.id)-only")
            }
            if isDeprecated {
                classes.append("deprecated")
            }
            
            let attributes: [String: String]?
            if classes.isEmpty {
                attributes = nil
            } else {
                attributes = ["class": classes.joined(separator: " ")]
            }
            
            hero.addChild(
                .element(
                    named: "h1",
                    children: renderer.wordBreak(symbolName: variant),
                    attributes: attributes
                )
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
        
        // Availability
        if let availability = symbol.availability?.availability.filter({ $0.domain != nil }).sorted(by: \.domain!.rawValue),
           !availability.isEmpty
        {
            hero.addChild(
                renderer.availability(availability.map { item in
                    .init(
                        name: item.domain!.rawValue, // Verified non-empty above
                        introduced: item.introducedVersion.map { "\($0.major).\($0.minor)" },
                        deprecated: item.deprecatedVersion.map { "\($0.major).\($0.minor)" },
                        isBeta: false // FIXME: Derive and pass beta information
                    )
                })
            )
        }
        
        // Declaration
        if !symbol.declarationVariants.allValues.isEmpty {
            // FIXME: Display platform specific declarations
            
            var fragmentsByLanguage = [SourceLanguage: [SymbolGraph.Symbol.DeclarationFragments.Fragment]]()
            for (trait, variant) in symbol.declarationVariants.allValues {
                guard let language = trait.sourceLanguage else { continue }
                fragmentsByLanguage[language] = variant.values.first?.declarationFragments
            }
            
            if fragmentsByLanguage.values.contains(where: { !$0.isEmpty }) {
                hero.addChild( renderer.declaration(fragmentsByLanguage) )
            }
        }
        
        // Deprecation message
        if let deprecationSummary = symbol.deprecatedSummary {
            var children: [XMLNode] = [
                .element(named: "p", children: [.text("Deprecated")], attributes: ["class": "label"])
            ]
            for child in deprecationSummary.content {
                children.append(renderer.visit(child))
            }
            
            hero.addChild(
                .element(
                    named: "blockquote",
                    children: children,
                    attributes: ["class": "aside deprecated"]
                )
            )
        }
        
        // Parameters
        if !symbol.parametersSectionVariants.allValues.isEmpty {
            articleElement.addChildren(
                renderer.parameters(
                    [SourceLanguage: [MarkdownRenderer<ContextLinkProvider>.ParameterInfo]](
                        symbol.parametersSectionVariants.allValues.map { trait, parameters in (
                            key:   trait.sourceLanguage ?? .swift,
                            value: parameters.parameters.map {
                                MarkdownRenderer<ContextLinkProvider>.ParameterInfo(name: $0.name, content: $0.contents)
                            }
                        )},
                        uniquingKeysWith: { _, new in new }
                    )
                )
            )
        }
        
        // Return value
        if !symbol.returnsSectionVariants.allValues.isEmpty {
            articleElement.addChildren(
                renderer.returns(
                    .init(
                        symbol.returnsSectionVariants.allValues.map { trait, returnSection in (
                            key:   trait.sourceLanguage ?? .swift,
                            value: returnSection.content
                        )},
                        uniquingKeysWith: { _, new in new }
                    )
                )
            )
        }
        
        func separateCurationIfNeeded() {
            guard goal == .richness, ((articleElement.children ?? []).last as? XMLElement)?.name == "section" else {
                return
            }
            
            articleElement.addChild(.element(named: "hr")) // Separate the sections with a thematic break
        }
        
        if FeatureFlags.current.isMentionedInEnabled {
            separateCurationIfNeeded()
            
            let mentions = context.articleSymbolMentions.articlesMentioning(reference)
            if !mentions.isEmpty {
                articleElement.addChildren(
                    // FIXME: Create a dedicated MarkdownRenderer method for the "Mentioned In" section
                    renderer.selfReferencingSection(named: "Mentioned In", content: [
                        .element(named: "ul", children: mentions.compactMap { reference in
                            context.documentationCache[reference].map {
                                .element(named: "li", children: [
                                    .element(named: "a", children: [.text($0.name.description)], attributes: [
                                        "href": renderer.path(to: $0.reference.url) + "/index.html"
                                    ])
                                ])
                            }
                        })
                    ])
                )
            }
        }
        
        // Discussion
        if let discussion = symbol.discussion {
            separateCurationIfNeeded()
            
            articleElement.addChildren(makeDiscussion(discussion, isSymbol: true))
        }
        
        // Topics
        do {
            // TODO: Support language specific topic sections
            var taskGroupInfo: [MarkdownRenderer<ContextLinkProvider>.TaskGroupInfo] = []
            
            if let authored = symbol.topics?.taskGroups {
                taskGroupInfo.append(contentsOf: authored.map { group in
                    .init(title: group.heading?.title, content: group.content, references: group.links.compactMap {
                        $0.destination.flatMap { URL(string: $0) }
                    })
                })
            }
            if let automatic = try? AutomaticCuration.topics(for: node, withTraits: [.swift, .objectiveC], context: context) {
                taskGroupInfo.append(contentsOf: automatic.map { group in
                    .init(title: group.title, content: [], references: group.references.compactMap { $0.url })
                })
            }
            
            if !taskGroupInfo.isEmpty {
                separateCurationIfNeeded()
                
                articleElement.addChildren(renderer.groupedSection(named: "Topics", groups: [.swift: taskGroupInfo]))
            }
        }
        
        // See Also
        if let seeAlso = symbol.seeAlso {
            separateCurationIfNeeded()
            
            articleElement.addChildren(
                renderer.groupedSection(named: "See Also", groups: [
                    .swift: seeAlso.taskGroups.map { group in
                        .init(title: group.heading?.title, content: group.content, references: group.links.compactMap {
                            $0.destination.flatMap { URL(string: $0) }
                        })
                    }
                ])
            )
        }
        // TODO: Add a way of determining the _automatic_ SeeAlso sections that doesn't query the JSON RenderContext for information.
        
        return RenderedPageInfo(
            content: goal == .richness ? main : articleElement,
            metadata: .init(
                title: symbol.title,
                plainDescription: symbol.abstract?.plainText
            )
        )
    }
    
    private func makeDiscussion(_ discussion: DiscussionSection, isSymbol: Bool) -> [XMLNode] {
        var remaining = discussion.content[...]
        
        let title: String
        if let heading = remaining.first as? Heading, heading.level == 2 {
            _ = remaining.removeFirst() // Make the authored heading reference the section, not itself
            title = heading.title
        } else {
            title = isSymbol ? "Discussion" : "Overview"
        }
        
        return renderer.selfReferencingSection(named: title, content: remaining.map { renderer.visit($0) })
    }
    
    // TODO: As a future direction, build another layer on top of this that creates a full HTML page from scratch.
}

// Note; this isn't a Comparable conformance because I wanted it to be private to this file.
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
