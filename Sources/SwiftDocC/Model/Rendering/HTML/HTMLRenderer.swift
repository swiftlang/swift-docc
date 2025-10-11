/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
#if canImport(FoundationXML)
// FIXME: See if we can avoid depending on XMLNode/XMLParser to avoid needing to import FoundationXML
import FoundationXML
#endif
import HTML
import Markdown
import SymbolKit

private struct ContextLinkProvider: HTML.LinkProvider {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    
    func element(for url: URL) -> HTML.LinkedElement? {
        guard url.scheme == "doc",
              let rawBundleID = url.host,
              let node = context.documentationCache[ResolvedTopicReference(bundleID: .init(rawValue: rawBundleID), path: url.path, fragment: url.fragment, sourceLanguage: .swift /* The reference's language doesn't matter */)]
        else {
            return nil
        }
        
        let names: HTML.LinkedElement.Names
        if let symbol = node.semantic as? Symbol,
           case .symbol(let primaryTitle) = node.name
        {
            let titles = symbol.titleVariants.allValues
            
            if titles.contains(where: { _, title in title != primaryTitle }) {
               // This symbol has multiple unique names
                let titles = [String: String](
                    titles.map { trait, title in
                        ((trait.interfaceLanguage.map { SourceLanguage(id: $0) } ?? .swift).id, title)
                    },
                    uniquingKeysWith: { _, new in new }
                )
                
                names = .languageSpecificSymbol(titles)
            } else {
                // There are multiple names, but the're all the same
                names = .single(.symbol(primaryTitle))
            }
        } else {
            let name: HTML.LinkedElement.Name = switch node.name {
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
            return result
        }
        
        let subheadings: HTML.LinkedElement.Subheadings
        if let symbol = node.semantic as? Symbol {
            let primarySubheading = symbol.subHeading
            let allSubheadings = symbol.subHeadingVariants.allValues
            
            if allSubheadings.contains(where: { _, title in title != primarySubheading }) {
                // This symbol has multiple unique names
                subheadings = .languageSpecificSymbol(.init(
                    allSubheadings.map { trait, subheading in (
                        key:   (trait.interfaceLanguage.map { SourceLanguage(id: $0) } ?? .swift).id,
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
    
    func assetNamed(_ assetName: String) -> HTML.LinkedAsset? {
        guard let asset = context.resolveAsset(named: assetName, in: reference) else {
            return nil
        }
        
        var images = [HTML.LinkedAsset.ColorStyle: [Int: URL]]()
        for (traits, url) in asset.variants {
            let scale = (traits.displayScale ?? .standard).scaleFactor
            
            images[traits.userInterfaceStyle == .dark ? .dark : .light, default: [:]][scale] = url
        }
        
        return .init(images: images)
    }
    
    static func filePath(for reference: ResolvedTopicReference) -> URL {
        reference.url.withoutHostAndPortAndScheme().appendingPathComponent("index.html")
    }
}

struct HTMLRenderer {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    let renderContext: RenderContext
    
    private let linkProvider: ContextLinkProvider
    private let filePath: URL
    
    private let renderer: MarkupRenderer<ContextLinkProvider>
    
    init(reference: ResolvedTopicReference, context: DocumentationContext, renderContext: RenderContext) {
        self.reference = reference
        self.context = context
        self.renderContext = renderContext
        let linkProvider = ContextLinkProvider(reference: reference, context: context)
        self.linkProvider = linkProvider
        let filePath = reference.url.withoutHostAndPortAndScheme().appendingPathComponent("index.html")
        self.filePath = filePath
        self.renderer = MarkupRenderer(path: filePath, linkProvider: linkProvider)
    }
    
    private func path(to destination: ResolvedTopicReference) -> String {
        (destination.url.relative(to: reference.url)?.path
            ?? destination.path) + "/index.html"
    }
    
    
    mutating func renderArticle(_ article: Article) -> XMLNode {
        let node = context.documentationCache[reference]!
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        articleElement.addChild(
            .element(named: "div", children: [hero], attributes: ["id": article.topics != nil ? "hero-api" : "hero-article"])
        )
        
        // Breadcrumbs and Eyebrow
        hero.addChild(
            .element(named: "header", children: [
                renderer.breadcrumbs(
                    references: (context.shortestFinitePath(to: reference) ?? [context.soleRootModuleReference!]).map { ContextLinkProvider.filePath(for: $0) }
                ),
                
                .element(
                    named: "span",
                    children: [.text(article.topics == nil ? "Article": "API Collection")],
                    attributes: ["class": "eyebrow"]
                ),
            ])
        )
        
        
        // FIXME: Add a background for articles
        // FIXME: Then add a background for the Framework page
        
        // Title
        hero.addChild(
            .element(
                named: "h1",
                children: [.text(node.name.plainText)],
                attributes: ["class": "title"]
            )
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
            articleElement.addChild(makeDiscussion(discussion, isSymbol: false))
        }
        
        var hasMadeSeparatedCuration = false
        
        func separateCurationIfNeeded() {
            guard !hasMadeSeparatedCuration else {
                return
            }
            
            guard let section: XMLElement = (articleElement.children ?? []).reversed().mapFirst(where: {
                guard let element = $0 as? XMLElement, element.name == "section" else { return nil }
                return element
            }) else {
                return
            }
            
            hasMadeSeparatedCuration = true
            section.setAttributesWith(["class": "separated"])
        }
        
        // Topics
        if let topics = article.topics {
            separateCurationIfNeeded()
            articleElement.addChild(makeGroupedSection(topics))
        }
        // Articles don't have automatic topic sections
        
        // See Also
        if let seeAlso = article.seeAlso {
            separateCurationIfNeeded()
            articleElement.addChild(makeGroupedSection(seeAlso))
        }
        if let taskGroup = AutomaticCuration.seeAlso(for: node, withTraits: [.swift, .objectiveC], context: context, renderContext: renderContext, renderer: .init(context: context)) {
            separateCurationIfNeeded()
            // Automatice SeeAlso
            let section = XMLElement(name: "section")
            
            if let title = SeeAlsoSection.title {
                section.addChild(
                    .selfReferencingHeader(title: title)
                )
            }
            if let heading = taskGroup.title {
                section.addChild(
                    .selfReferencingHeader(level: 3, title: heading)
                )
            }
            
            for link in taskGroup.references {
                if let element = self.makeTopicSectionItem(for: link) {
                    section.addChild(element)
                }
            }
            
            articleElement.addChild(section)
        }
        
        return makePage(main: main, title: article.title?.plainText ?? node.name.plainText, plainDescription: article.abstract?.plainText)
    }
    
    mutating func renderSymbol(_ symbol: Symbol) -> XMLNode {
        let node = context.documentationCache[reference]!
        
        let isDeprecated = symbol.isDeprecated
        
        let main = XMLElement(name: "main")
        let articleElement = XMLElement(name: "article")
        main.addChild(articleElement)
        
        let hero = XMLElement(name: "section")
        if symbol.kind.identifier == .module {
            articleElement.addChild(
                .element(named: "div", children: [hero], attributes: ["id": "hero-module"])
            )
        } else {
            hero.setAttributesWith(["class": "separated"])
            articleElement.addChild(hero)
        }
        
        // Breadcrumbs and Eyebrow
        hero.addChild(
            .element(named: "header", children: [
                renderer.breadcrumbs(
                    references: (context.linkResolver.localResolver.breadcrumbs(of: reference, in: reference.sourceLanguage) ?? []).map { ContextLinkProvider.filePath(for: $0) }
                ),
                
                .element(
                    named: "span",
                    children: [.text(symbol.roleHeading)],
                    attributes: ["class": "eyebrow"]
                ),
            ])
        )
        
        // Title
        let titleVariants = symbol.titleVariants.allValues.sorted(by: { $0.trait < $1.trait})
        for (trait, variant) in titleVariants {
            guard let lang = trait.interfaceLanguage else { continue }
            
            var classes: [String] = []
            if titleVariants.count > 1 {
                classes.append("\(lang)-only")
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
                    children: RenderHelpers.wordBreak(symbolName: variant),
                    attributes: attributes
                )
            )
        }
        
        // Abstract
        if let abstract = symbol.abstract {
            let paragraph = renderer.visit(abstract) as! XMLElement
            
            paragraph.addAttribute(
                XMLNode.attribute(withName: "id", stringValue: "abstract") as! XMLNode
            )
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
            
            var fragmentsByLanguageID = [String: [SymbolGraph.Symbol.DeclarationFragments.Fragment]]()
            for (trait, variant) in symbol.declarationVariants.allValues {
                guard let languageID = trait.interfaceLanguage else { continue }
                fragmentsByLanguageID[languageID] = variant.values.first?.declarationFragments
            }
            
            hero.addChild( renderer.declaration(fragmentsByLanguageID) )
        }
        
        for (trait, variant) in symbol.declarationVariants.allValues.sorted(by: { $0.trait < $1.trait}) {
            guard let lang = trait.interfaceLanguage else { continue }
            
            for (/*platforms*/_, declaration) in variant {
                // FIXME: Pretty print declarations for Swift and Objective-C
                
                hero.addChild(
                    .element(named: "pre", children: [
                        .element(named: "code", children: declaration.declarationFragments.map { fragment in
                            // ???: Do `.text` tokens need to be wrapped in a span?
                            if fragment.kind == .typeIdentifier,
                               let symbolID = fragment.preciseIdentifier,
                               let reference = context.localOrExternalReference(symbolID: symbolID)
                            {
                                // Make a link
                                return .element(named: "span", children: [
                                    .element(
                                        named: "a",
                                        children: [.text(fragment.spelling)],
                                        attributes: ["href": path(to: reference)]
                                    )
                                ], attributes: ["class": "type-identifier-link"])
                            }
                            else {
                                return .element(named: "span", children: [.text(fragment.spelling)], attributes: ["class": "token-\(fragment.kind.rawValue)"])
                            }
                        })
                    ], attributes: ["class": "\(lang)-only"])
                )
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
            articleElement.addChild(
                renderer.parameters(
                    .init(
                        symbol.parametersSectionVariants.allValues.map { trait, parameters in (
                            key:   trait.interfaceLanguage ?? "swift",
                            value: parameters.parameters.map {
                                .init(name: $0.name, content: $0.contents)
                            }
                        )},
                        uniquingKeysWith: { _, new in new }
                    )
                )
            )
        }
        
        // Return value
        if let returnsSection = symbol.returnsSection {
            let section = XMLElement(name: "section")
            section.addAttribute(
                XMLNode.attribute(withName: "class", stringValue: "return-value") as! XMLNode
            )
            
            if let title = ReturnsSection.title {
                section.addChild(
                    .selfReferencingHeader(title: title)
                )
            }
            
            for markup in returnsSection.content {
                section.addChild(
                    renderer.visit(markup)
                )
            }
            
            articleElement.addChild(section)
        }
        
        // Discussion
        if let discussion = symbol.discussion {
            articleElement.addChild(makeDiscussion(discussion, isSymbol: true))
        }
        
        var hasMadeSeparatedCuration = false
        
        func separateCurationIfNeeded() {
            guard !hasMadeSeparatedCuration else {
                return
            }
            
            guard let section: XMLElement = (articleElement.children ?? []).reversed().mapFirst(where: {
                guard let element = $0 as? XMLElement, element.name == "section" else { return nil }
                return element
            }) else {
                return
            }
            
            hasMadeSeparatedCuration = true
            section.setAttributesWith(["class": "separated"])
        }
        
        // Topics
        if let topics = symbol.topics {
            separateCurationIfNeeded()
            
            articleElement.addChild(makeGroupedSection(topics))
        }
        if let automaticTopics = try? AutomaticCuration.topics(for: node, withTraits: [.swift, .objectiveC], context: context) {
            // Automatice SeeAlso
            let section = XMLElement(name: "section")
            
            var didAddAnyLink = false
            
            if let title = TopicsSection.title {
                section.addChild(
                    .selfReferencingHeader(title: title)
                )
            }
            
            for automaticTopic in automaticTopics {
                if let heading = automaticTopic.title {
                    section.addChild(
                        .selfReferencingHeader(level: 3, title: heading)
                    )
                }
                
                for link in automaticTopic.references {
                    if let element = self.makeTopicSectionItem(for: link) {
                        didAddAnyLink = true
                        section.addChild(element)
                    }
                }
            }
            
            if didAddAnyLink {
                separateCurationIfNeeded()
                articleElement.addChild(section)
            }
        }
        
        // See Also
        if let seeAlso = symbol.seeAlso {
            separateCurationIfNeeded()
            articleElement.addChild(makeGroupedSection(seeAlso))
        }
        
        if let taskGroup = AutomaticCuration.seeAlso(for: node, withTraits: [.swift, .objectiveC], context: context, renderContext: renderContext, renderer: .init(context: context)) {
            // Automatice SeeAlso
            let section = XMLElement(name: "section")
            separateCurationIfNeeded()
            
            if let title = SeeAlsoSection.title {
                section.addChild(
                    .selfReferencingHeader(title: title)
                )
            }
            
            if let heading = taskGroup.title {
                section.addChild(
                    .selfReferencingHeader(level: 3, title: heading)
                )
            }
            
            for link in taskGroup.references {
                if let element = self.makeTopicSectionItem(for: link) {
                    section.addChild(element)
                }
            }
            
            articleElement.addChild(section)
        }
        
        return makePage(main: main, title: symbol.title, plainDescription: symbol.abstract?.plainText)
    }
    
    private func makeDiscussion(_ discussion: DiscussionSection, isSymbol: Bool) -> XMLNode {
        let section = XMLElement(name: "section")
        
        // Don't add a heading if it's already authored
        if (discussion.content.first as? Heading)?.level != 2 {
            section.addChild(
                .selfReferencingHeader(title: isSymbol ? "Discussion" : "Overview")
            )
        }
        
        var remaining = discussion.content[...]
        if let heading = discussion.content.first as? Heading, heading.level == 2 {
            _ = remaining.removeFirst()
            section.addChild(
                .selfReferencingHeader(title: heading.title)
            )
        }
        
        for markup in remaining {
            section.addChild(
                renderer.visit(markup)
            )
        }
        
        return section
    }
    
    private func makeGroupedSection<Grouped: GroupedSection>(_ groupedSection: Grouped) -> XMLNode {
        let section = XMLElement(name: "section")
        
        if let title = Grouped.title {
            section.addChild(
                .selfReferencingHeader(title: title)
            )
        }
        
        for taskGroup in groupedSection.taskGroups {
            if let heading = taskGroup.heading {
                section.addChild(
                    .selfReferencingHeader(level: 3, title: heading.title)
                )
            }
            
            for link in taskGroup.links {
                guard let destination = link.destination,
                      let reference = context.referenceIndex[destination]
                else {
                    // Unresolved links wouldn't be found here
                    continue
                }
                
                if let element = self.makeTopicSectionItem(for: reference) {
                    section.addChild(element)
                }
            }
        }
        
        return section
    }
    
    private func makeTopicSectionItem(for reference: ResolvedTopicReference) -> XMLNode? {
        if let local = context.documentationCache[reference] {
            let container = XMLNode.element(named: "div")//, attributes: ["class": className])
            var className = "link-block"
             
            // Title
            var titles: [XMLNode]? = nil
            if let symbol = local.semantic as? Symbol {
                if symbol.isDeprecated {
                    className += " deprecated"
                }
                
                if case .conceptual(let title) = local.name {
                    // FIXME: What element and class should this be?
                    titles = [.element(named: "span", children: [.text(title)])]
                    
                }
                else  {
                    titles = symbol.subHeadingVariants
                        .allValues.sorted(by: { $0.trait < $1.trait})
                        .compactMap { trait, variant in
                            guard let lang = trait.interfaceLanguage else { return nil }
                            
                            return .element(
                                named: "code",
                                children: variant.map { fragment in
                                    let className = switch fragment.kind {
                                        case .identifier, .externalParameter:
                                            "identifier"
                                        default:
                                            "decorator"
                                    }
                                    
                                    return .element(named: "span", children: RenderHelpers.wordBreak(symbolName: fragment.spelling), attributes: ["class": className])
                                },
                                attributes: ["class": "\(lang)-only"]
                            )
                        }
                }
                
            } else if let article = local.semantic as? Article {
                if let heading = article.title {
                    // FIXME: What element and class should this be?
                    titles = [.element(named: "span", children: [.text(heading.title)])]
                }
            }
            container.setAttributesWith(["class": className])
            if let titles {
                container.addChild(
                    .element(named: "a", children: titles, attributes: ["href": path(to: reference)])
                )
            }
            
            // Abstract
            if let abstract = (local.semantic as? any Abstracted)?.abstract {
                container.addChild(renderer.visit(abstract))
            }
            
            return container
        } else if let external = context.externalCache[reference] {
            let container = XMLNode.element(named: "div", attributes: ["class": "link-block"])
            
            let title: XMLNode
            if external.kind.isSymbol, let fragments = external.subheadingDeclarationFragments {
                title = .element(named: "code", children: fragments.map { fragment in
                    let className = fragment.kind == .identifier ? "identifier" : "decorator"
                    return .element(named: "span", children: [.text(fragment.text)], attributes: ["class": className])
                })
            } else {
                // FIXME: What element and class should this be?
                title = .element(named: "span", children: [.text(external.title)])
            }
            
            container.addChild(
                .element(named: "a", children: [title], attributes: ["href": path(to: reference)])
            )
            
            // TODO: Support external abstracts as well
            
            return container
        }
        return nil
    }
    
    private func makePage(main: XMLNode, title: String, plainDescription: String?) -> XMLNode {
        let head = XMLElement(name: "head")
        head.setChildren([
            // <meta charset="utf-8">
            .element(named: "meta", attributes: ["charset": "utf-8"]),
            
            // <meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
            .metaElement(name: "viewport", content: "width=device-width,initial-scale=1,viewport-fit=cover"),
            
            // <link rel="icon" href="/favicon.ico">
            .element(named: "link", attributes: [
                "rel": "icon",
                "href": "/favicon.ico", // ???: Should this be relative to the page?
            ]),
            
            // <link rel="mask-icon" href="/apple-logo.svg" color="#333333">
            .element(named: "link", attributes: [
                "rel": "mask-icon",
                "href": "/apple-logo.svg", // ???: Should this be relative to the page?
                "color": "#333333",
            ]),
            
            .element(named: "title", children: [
                .text(title)
            ]),
            
            // <link rel="stylesheet" href="styles.css" />
            .element(named: "link", attributes: [
                "rel": "stylesheet",
                "href": String(repeating: "../", count: reference.url.pathComponents.count - 1) + "styles.css"
            ]),
            
            .element(named: "script", attributes: [
                "type": "text/javascript",
                "src": String(repeating: "../", count: reference.url.pathComponents.count - 1) + "reference.js"
            ]),
            
            // FIXME: Include OpenGraph metadata
        ])
        if let abstract = plainDescription {
            head.addChild(
                .metaElement(name: "description", content: abstract)
            )
        }
        
        // FIXME: Add the page header here
        let header = XMLNode.element(
            named: "header",
            children: [
                .element(named: "button", attributes: ["id": "sidebar-toggle", "onclick": "toggleSidebar()"]),
                
                .element(
                    named: "span",
                    children: [.text("Documentation")],
                    attributes: ["id": "header-title"]
                ),
                
                .element(named: "div", children: [
                    .element(named: "label", children: [.text("Language: ")], attributes: ["for": "language-toggle"]),
                    
                    .element(
                        named: "select",
                        children: [
                            .element(named: "option", children: [.text("Swift")], attributes: ["value": "swift"]),
                            .element(named: "option", children: [.text("Objective-C")], attributes: ["value": "occ"]),
                        ],
                        attributes: ["id": "language-toggle", "onchange": "languageChanged()"]
                    ),
                ])
            ]
        )
        
        // Wrap up the page
        let document = XMLDocument(rootElement: .element(
            named: "html",
            children: [
                head,
                .element(named: "body", children: [
                    header,
                    main // Passes as an argument
                ])
            ],
            attributes: ["lang": "en-US"]
        ))
        document.documentContentKind = .xhtml
        
        let docTypeDefinition = XMLDTD()
        docTypeDefinition.publicID = "-//W3C//DTD XHTML 1.0 Strict//EN"
        docTypeDefinition.systemID = "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"
        docTypeDefinition.name = "html"
        document.dtd = docTypeDefinition
        
        return document
    }
    
}

extension XMLNode {
    static func metaElement(name: String, content: String) -> XMLElement {
        .element(named: "meta", attributes: ["name": name, "content": content])
    }
    
    static func metaElement(property: String, content: String) -> XMLElement {
        .element(named: "meta", attributes: ["property": property, "content": content])
    }
    
    static func selfReferencingHeader(level: Int = 2, title: String) -> XMLElement {
        let id = urlReadableFragment(title)
        return .element(
            named: "h\(level)",
            children: [
                .element(
                    named: "a",
                    children: [.text(title)],
                    attributes: ["href": "#\(id)"]
                )
            ],
            attributes: ["id": id]
        )
    }
}

// Note; this isn't a Comparable conformance because I wanted it to be private to this file.
private extension DocumentationDataVariantsTrait {
    static func < (lhs: DocumentationDataVariantsTrait, rhs: DocumentationDataVariantsTrait) -> Bool {
        (lhs.interfaceLanguage ?? "") < (rhs.interfaceLanguage ?? "")
    }
}
