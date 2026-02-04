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
private import DocCCommon

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
        
        let articleElement = XMLElement(name: "article")
        let hero = XMLElement(name: "section")
        articleElement.addChild(hero)
        
        // Breadcrumbs and Eyebrow
        hero.addChild(renderer.breadcrumbs(
            references: (context.shortestFinitePath(to: reference) ?? [context.soleRootModuleReference!]).map { $0.url },
            currentPageNames: .single(.conceptual(node.name.plainText))
        ))
        addEyebrow(text: article.topics == nil ? "Article": "API Collection", to: hero)
        
        // Title
        hero.addChild(
            .element(named: "h1", children: [.text(node.name.plainText)])
        )
        
        // Abstract
        if let abstract = article.abstract {
            addAbstract(abstract, to: hero)
        }
        
        // Deprecation message
        if let deprecationMessage = article.deprecationSummary?.elements {
            addDeprecationSummary(markup: deprecationMessage, to: hero)
        }
        
        // Discussion
        if let discussion = article.discussion {
            articleElement.addChildren(
                renderer.discussion(discussion.content, fallbackSectionName: "Overview")
            )
        }
        
        // Topics
        if let topics = article.topics {
            separateSectionsIfNeeded(in: articleElement)
            
            // TODO: Support language specific topic sections, indicated using @SupportedLanguage directives (rdar://166308418)
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
        // Articles don't have _automatic_ topic sections.
        
        // See Also
        if let seeAlso = article.seeAlso {
            addSeeAlso(seeAlso, to: articleElement)
        }
        // _Automatic_ See Also sections are very heavily tied into the RenderJSON model and require information from the JSON to determine.
        
        return RenderedPageInfo(
            content: articleElement,
            metadata: .init(
                title: article.title?.plainText ?? node.name.plainText,
                plainDescription: article.abstract?.plainText
            )
        )
    }
    
    mutating func renderSymbol(_ symbol: Symbol) -> RenderedPageInfo {
        let node = context.documentationCache[reference]!
        
        let articleElement = XMLElement(name: "article")
        let hero = XMLElement(name: "section")
        articleElement.addChild(hero)
        
        // Breadcrumbs and Eyebrow
        hero.addChild(renderer.breadcrumbs(
            references: (context.linkResolver.localResolver.breadcrumbs(of: reference, in: reference.sourceLanguage) ?? []).map { $0.url },
            currentPageNames: node.makeNames(goal: goal)
        ))
        addEyebrow(text: symbol.roleHeading, to: hero)
        
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
            addAbstract(abstract, to: hero)
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
                            isBeta: false // TODO: Derive and pass beta information
                    )
                })
            )
        }
        
        // Declaration
        if !symbol.declarationVariants.allValues.isEmpty {
            // TODO: Display platform specific declarations
            
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
        if let deprecationMessage = symbol.deprecatedSummary?.content {
            addDeprecationSummary(markup: deprecationMessage, to: hero)
        }
        
        // Parameters
        if let parameterSections = symbol.parametersSectionVariants
            .values(goal: goal, by: { $0.parameters.elementsEqual($1.parameters, by: { $0.name == $1.name }) })
            .valuesByLanguage()
        {
            articleElement.addChildren(renderer.parameters(
                parameterSections.mapValues { section in
                    section.parameters.map {
                        MarkdownRenderer<ContextLinkProvider>.ParameterInfo(name: $0.name, content: $0.contents)
                    }
                }
            ))
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
        
        // Mentioned In
        if FeatureFlags.current.isMentionedInEnabled {
            articleElement.addChildren(
                renderer.groupedListSection(named: "Mentioned In", groups: [
                    .swift: [.init(title: nil, references: context.articleSymbolMentions.articlesMentioning(reference).map(\.url))]
                ])
            )
        }

        // Discussion
        if let discussion = symbol.discussion {
            articleElement.addChildren(
                renderer.discussion(discussion.content, fallbackSectionName: symbol.kind.identifier.swiftSymbolCouldHaveChildren ? "Overview" : "Discussion")
            )
        }
        
        // Topics
        do {
            // TODO: Support language specific topic sections, indicated using @SupportedLanguage directives (rdar://166308418)
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
                separateSectionsIfNeeded(in: articleElement)
                
                articleElement.addChildren(renderer.groupedSection(named: "Topics", groups: [.swift: taskGroupInfo]))
            }
        }
        
        // Relationships
        if let relationships = symbol.relationshipsVariants
            .values(goal: goal, by: { $0.groups.elementsEqual($1.groups, by: { $0 == $1 }) })
            .valuesByLanguage()
        {
            articleElement.addChildren(
                renderer.groupedListSection(named: "Relationships", groups: relationships.mapValues { section in
                    section.groups.map {
                        .init(title: $0.sectionTitle, references: $0.destinations.compactMap { topic in
                            switch topic {
                                case .resolved(.success(let reference)): reference.url
                                case .unresolved, .resolved(.failure):   nil
                            }
                        })
                    }
                })
            )
        }
        
        // See Also
        if let seeAlso = symbol.seeAlso {
            addSeeAlso(seeAlso, to: articleElement)
        }
        
        return RenderedPageInfo(
            content: articleElement,
            metadata: .init(
                title: symbol.title,
                plainDescription: symbol.abstract?.plainText
            )
        )
    }
   
    private func addEyebrow(text: String, to element: XMLElement) {
        element.addChild(
            .element(named: "p", children: [.text(text)], attributes: goal == .richness ? ["id": "eyebrow"] : [:])
        )
    }
    
    private func addAbstract(_ abstract: Paragraph, to element: XMLElement) {
        let paragraph = renderer.visit(abstract) as! XMLElement
        if goal == .richness {
            paragraph.addAttribute(XMLNode.attribute(withName: "id", stringValue: "abstract") as! XMLNode)
        }
        element.addChild(paragraph)
    }
    
    private func addDeprecationSummary(markup: [any Markup], to element: XMLElement) {
        var children: [XMLNode] = [
            .element(named: "p", children: [.text("Deprecated")], attributes: ["class": "label"])
        ]
        for child in markup {
            children.append(renderer.visit(child))
        }
        
        element.addChild(
            .element(named: "blockquote", children: children, attributes: ["class": "aside deprecated"])
        )
    }
    
    private func separateSectionsIfNeeded(in element: XMLElement) {
        guard goal == .richness, ((element.children ?? []).last as? XMLElement)?.name == "section" else {
            return
        }
        
        element.addChild(.element(named: "hr")) // Separate the sections with a thematic break
    }
    
    private func addSeeAlso(_ seeAlso: SeeAlsoSection, to element: XMLElement) {
        separateSectionsIfNeeded(in: element)
        
        element.addChildren(
            renderer.groupedSection(named: "See Also", groups: [
                .swift: seeAlso.taskGroups.map { group in
                    .init(title: group.heading?.title, content: group.content, references: group.links.compactMap {
                        $0.destination.flatMap { URL(string: $0) }
                    })
                }
            ])
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

private extension RelationshipsGroup {
    static func == (lhs: RelationshipsGroup, rhs: RelationshipsGroup) -> Bool {
        lhs.kind == rhs.kind && lhs.destinations == rhs.destinations // Everything else is derived from the `kind`
    }
}

private enum VariantValues<Value> {
    case single(Value)
    case languageSpecific([SourceLanguage: Value])
    // This is necessary because of a shortcoming in the API design of `DocumentationDataVariants`.
    case empty
    
    func valuesByLanguage() -> [SourceLanguage: Value]? {
        switch self {
            case .single(let value):
                [.swift: value] // The language doesn't matter when there's only one
            case .languageSpecific(let values):
                values
            case .empty:
                nil
        }
    }
}

// Both `DocumentationDataVariants` and `VariantCollection` are really hard to work with correctly and neither offer a good API that both:
// - Makes a clear distinction between when a value will always exist and when the "values" can be empty.
// - Allows the caller to iterate over all the values.
// TODO: Design and implement a better solution for representing language specific variations of a value (rdar://166211961)
private extension DocumentationDataVariants {
    func values(goal: RenderGoal, by areEquivalent: (Variant, Variant) -> Bool) -> VariantValues<Variant> {
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
        if values.contains(where: { _, value in !areEquivalent(value, primaryValue) }) {
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

private extension DocumentationDataVariants where Variant: Equatable {
    func values(goal: RenderGoal) -> VariantValues<Variant> {
        values(goal: goal, by: ==)
    }
}
