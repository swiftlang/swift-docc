/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation
import Markdown

/// A type that provides information about other pages, and on-page elements, that the rendered page references.
package protocol LinkProvider {
    /// Provide information about another page or on-page element, or `nil` if the other page can't be found.
    func element(for path: URL) -> LinkedElement?
    
    /// Provide information about an asset, or `nil` if the asset can't be found.
    func assetNamed(_ assetName: String) -> LinkedAsset?
}

package struct LinkedElement {
    /// The path within the output archive to the linked element.
    package var path: URL
    /// The names of the linked element.
    ///
    /// Articles, headings, tutorials, and similar pages have a ``Names/single/conceptual(_:)`` name.
    /// Symbols can either have a ``Names/single/symbol(_:)`` name or have different names for each language representation (``Names/languageSpecificSymbol``).
    package var names: Names
    
    package init(path: URL, names: Names) {
        self.path = path
        self.names = names
    }
    
    package enum Names {
        /// This element has the same name in all language representations
        case single(Name)
        /// This element is a symbol with different names in different languages.
        ///
        /// Because `@DisplayName` applies to all language representations, these language specific names are always the symbol's subheading declaration and should display in a monospaced font.
        case languageSpecificSymbol([String /* Language ID */: String])
    }
    package enum Name {
        /// The name refers to an article, heading, or custom `@DisplayName` and should display as regular text.
        case conceptual(String)
        /// The name refers to a symbol's subheading declaration and should display in a monospaced font.
        case symbol(String)
    }
}

package struct LinkedAsset {
    /// The path within the output archive to each image variant, by their light/dark style.
    package var images: [ColorStyle: [Int /* display scale*/: URL]]
    
    package init(images: [ColorStyle : [Int : URL]]) {
        self.images = images
    }
    
    package enum ColorStyle: String {
        case light, dark
    }
}

package struct MarkupRenderer<Provider: LinkProvider>: MarkupVisitor {
    /// The path within the output archive to the page that this renderer renders.
    let path: URL
    /// A type that provides information about other pages that the rendered page references.
    let linkProvider: Provider
    
    package init(path: URL, linkProvider: Provider) {
        self.path = path
        self.linkProvider = linkProvider
    }
    
    mutating func defaultVisit(_ markup: any Markdown.Markup) -> XMLNode {
        fatalError("A placeholder node also crashes here so we might as well make it explicit")
    }
    
    //
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> XMLNode {
        .element(named: "p", children: visit(paragraph.children))
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> XMLNode {
        let aside = Aside(blockQuote)
        
        var children: [XMLNode] = [
            .element(named: "p", children: [.text(aside.kind.displayName)], attributes: ["class": "label"])
        ]
        for child in aside.content {
            children.append(visit(child))
        }
        
        return .element(
            named: "blockquote",
            children: children,
            attributes: ["class": "aside \(aside.kind.rawValue.lowercased())"]
        )
    }
    
    mutating func visitHeading(_ heading: Heading) -> XMLNode {
        .element(named: "h\(heading.level)", children: visit(heading.children))
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> XMLNode {
        .element(named: "i", children: visit(emphasis.children))
    }
    
    mutating func visitStrong(_ strong: Strong) -> XMLNode {
        .element(named: "b", children: visit(strong.children))
    }
    
    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> XMLNode {
        .element(named: "s", children: visit(strikethrough.children))
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> XMLNode {
        .element(named: "code", children: [.text(inlineCode.code)])
    }
    
    func visitText(_ text: Text) -> XMLNode {
        .text(text.string)
    }
    
    func visitLineBreak(_ lineBreak: LineBreak) -> XMLNode {
        .element(named: "br")
    }
    
    func visitSoftBreak(_ softBreak: SoftBreak) -> XMLNode {
        .text(" ") // A soft line break doesn't actually break the content
    }
    
    func visitThematicBreak(_ thematicBreak: ThematicBreak) -> XMLNode {
        .element(named: "hr")
    }
    
    private func _removeComments(from node: XMLNode) {
        guard let element = node as? XMLElement,
              let children = element.children
        else {
            return
        }
        
        let withoutComments = children.filter { $0.kind != .comment }
        element.setChildren(withoutComments)
        
        for child in withoutComments {
            _removeComments(from: child)
        }
    }
    
    func visitHTMLBlock(_ html: HTMLBlock) -> XMLNode {
        do {
            let parsed = try XMLElement(xmlString: html.rawHTML)
            _removeComments(from: parsed)
            return parsed
        } catch {
            return .text("")
        }
    }
    
    func visitInlineHTML(_ html: InlineHTML) -> XMLNode {
        // Inline HTML is one tag at a time, meaning that the closing and opening tags are parsed separately
        // Because of this, we can't parse it with `XMLElement` or `XMLParser`.
        
        // We assume that we want all tags except for comments
        guard !html.rawHTML.hasPrefix("<!--") else {
            return .text("")
        }
        
        // We can't create a valid structured XMLNode (because that closing tag will come later,
        // so we return the raw tag as text.
        return .text(html.rawHTML)
    }
    
    mutating func visitLink(_ link: Link) -> XMLNode {
        guard let destination = link.destination.flatMap({ URL(string: $0) }) else {
            return .text("")
        }
        
        if link.childCount > 0 {
            var customTitle = [XMLNode]()
            for child in link.inlineChildren {
                customTitle.append(visit(child))
            }
            
            if customTitle != [.text(destination.absoluteString)] {
                return .element(
                    named: "a",
                    children: customTitle,
                    attributes: [
                        // Use relative links for DocC elements, and the full link otherwise.
                        "href": linkProvider.element(for: destination).flatMap { path(to: $0.path) } ?? destination.absoluteString
                    ]
                )
            }
        }
        
        // Make a relative link
        if let linkedElement = linkProvider.element(for: destination) {
            let children: [XMLNode] = switch linkedElement.names {
                case .single(let name):
                    switch name {
                        case .conceptual(let name): [ .text(name) ]
                        case .symbol(let name):     [ .element(named: "code", children: [.text(name)]) ]
                    }
                    
                case .languageSpecificSymbol(let namesByLanguageID):
                    namesByLanguageID.sorted(by: { $0.key < $1.key }).map { languageID, name in
                            .element(named: "code", children: [.text(name)], attributes: ["class": "\(languageID)-only"])
                    }
            }
            
            return .element(
                named: "a",
                children: children,
                attributes: ["href": path(to: linkedElement.path)]
            )
        } else if destination.scheme != "doc" {
            // This could be a http link
            return .element(
                named: "a",
                children: [.text(destination.absoluteString)],
                attributes: ["href": destination.absoluteString]
            )
        } else {
            // FIXME: Add this to the protocol
//            // If this is an unresolved documentation link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation.
//            return .text(LinkCompletionTools.parse(linkString: destination.path).last?.name ?? "")
            return .text(destination.path)
        }
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> XMLNode {
        guard let destination = symbolLink.destination.flatMap({ URL(string: $0) }),
              let linkedElement = linkProvider.element(for: destination)
        else {
            // FIXME: Add this to the protocol
//            // If this is an unresolved symbol link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation.
//            let name = symbolLink.destination.flatMap { LinkCompletionTools.parse(linkString: $0).last?.name } ?? ""
//            return .element(named: "code", children: [.text(name)])
            return .element(named: "code", children: [.text(symbolLink.destination ?? "")])
        }
        
        let children: [XMLNode] = switch linkedElement.names {
            case .single(let name):
                switch name {
                    case .conceptual(let name): [ .text(name) ]
                    case .symbol(let name):     [ .element(named: "code", children: [.text(name)]) ]
                }
                
            case .languageSpecificSymbol(let namesByLanguageID):
                namesByLanguageID.sorted(by: { $0.key < $1.key }).map { languageID, name in
                    .element(named: "code", children: [.text(name)], attributes: ["class": "\(languageID)-only"])
                }
        }
        
        return .element(
            named: "a",
            children: children,
            attributes: ["href": path(to: linkedElement.path)]
        )
    }
    
    private func path(to other: URL) -> String {
        let from = path
        let to   = other
        
        guard from != to else { return to.withoutHostAndPortAndScheme().absoluteString }

        // To be able to compare the components of the two URLs they both need to be absolute and standardized.
        let fromComponents = from.absoluteURL.standardizedFileURL.pathComponents
        let toComponents   = to.absoluteURL.standardizedFileURL.pathComponents

        let commonPrefixLength = Array(zip(fromComponents, toComponents).prefix { lhs, rhs in lhs == rhs }).count

        let relativeComponents = repeatElement("..", count: fromComponents.count - commonPrefixLength) + toComponents.dropFirst(commonPrefixLength)
       
        return relativeComponents.joined(separator: "/")
    }
    
    func visitImage(_ image: Image) -> XMLNode {
        guard let asset = image.source.flatMap({ linkProvider.assetNamed($0) }), !asset.images.isEmpty else {
            return .text("") // ???: What do we return for images that won't display anything?
        }
        
        func srcAttributes(for images: [Int: URL]) -> [String: String] {
            switch images.count {
                case 0: [:]
                case 1: ["src": path(to: images.first!.value)]
                default: ["srcset": images.sorted(by: { $0.key > $1.key }) // large scale factors first
                    .map { scale, url in "\(path(to: url)) \(scale)x" }
                    .joined(separator: ", ")
                ]
            }
        }
        
        var imgAttributes = [
            "decoding": "async",
            "loading": "lazy",
        ]
        if let altText = image.altText {
            imgAttributes["alt"] = altText
        }
        
        var children = [XMLNode]()
        if asset.images.count == 1 {
            // When all image are either dark/light mode, add them directly on the "img" element
            imgAttributes.merge(srcAttributes(for: asset.images.first!.value), uniquingKeysWith: { _, new in new })
        } else {
            // Define a "source" element for each dark/light style
            for (style, images) in asset.images.sorted(by: { $0.key.rawValue > $1.key.rawValue }) { // order light images before dark images
                var attributes = srcAttributes(for: images)
                attributes["media"] = "(prefers-color-scheme: \(style.rawValue))"
                children.append(.element(named: "source", attributes: attributes))
            }
        }
        
        children.append(.element(named: "img", attributes: imgAttributes))
        
        return .element(named: "picture", children: children)
    }
    
    func visitCodeBlock(_ codeBlock: CodeBlock) -> XMLNode {
        let attributes = codeBlock.language.map {
            ["class": $0]
        }
        
        return .element(
            named: "pre",
            children: [
                .element(named: "code", children: [.text(codeBlock.code)])
            ],
            attributes: attributes
        )
        
    }
    
    // MARK: List
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> XMLNode {
        .element(named: "ul", children: visit(unorderedList.children))
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> XMLNode {
        .element(named: "ol", children: visit(orderedList.children))
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> XMLNode {
        .element(named: "li", children: visit(listItem.children))
    }
    
    // MARK: Tables
    
    mutating func visitTable(_ table: Table) -> XMLNode {
        let element = XMLElement(name: "table")
        
        var renderer = self // ???: Do we need to use a copy here?
        
        if !table.head.isEmpty {
            var column = 0
            
            element.addChild(
                .element(named: "thead", children: [
                    .element(named: "tr", children: table.head.cells.compactMap { (cell) -> XMLNode? in
                        defer { column += 1 }
                        
                        if cell.colspan == 0 || cell.rowspan == 0 {
                            return nil
                        }
                        
                        var attributes: [String: String] = [:]
                        if cell.colspan != 1 {
                            attributes["colspan"] = "\(cell.colspan)"
                        }
                        if cell.rowspan != 1 {
                            attributes["rowspan"] = "\(cell.rowspan)"
                        }
                        
                        if let alignment = table.columnAlignments[column] {
                            attributes["class"] = switch alignment {
                                case .left:   "left"
                                case .center: "center"
                                case .right:  "right"
                            }
                        }
                        
                        return .element(
                            named: "th",
                            children: renderer.visit(cell.children),
                            attributes: attributes
                        )
                    })
                ])
            )
        }
        
        if !table.body.isEmpty {
            element.addChild(
                .element(named: "tbody", children: table.body.rows.map { row in
                    var column = 0
                    return .element(named: "tr", children: row.cells.compactMap { (cell) -> XMLNode? in
                        defer { column += 1 }
                        
                        if cell.colspan == 0 || cell.rowspan == 0 {
                            return nil
                        }
                        
                        var attributes: [String: String] = [:]
                        if cell.colspan != 1 {
                            attributes["colspan"] = "\(cell.colspan)"
                        }
                        if cell.rowspan != 1 {
                            attributes["rowspan"] = "\(cell.rowspan)"
                        }
                        
                        if let alignment = table.columnAlignments[column] {
                            attributes["class"] = switch alignment {
                                case .left:   "left"
                                case .center: "center"
                                case .right:  "right"
                            }
                        }
                        
                        return .element(
                            named: "td",
                            children: renderer.visit(cell.children),
                            attributes: attributes
                        )
                    })
                })
            )
        }
        
        return element
    }
    
    // MARK: Markup children
    
    private mutating func visit(_ container: MarkupChildren) -> [XMLNode] {
        var children: [XMLNode] = []
        children.reserveCapacity(container.underestimatedCount)
        
        guard container.contains(where: { $0 is InlineHTML }) else {
            for element in container {
                children.append(visit(element))
            }
            return children
        }
        
        var elements = Array(container)
        outer: while !elements.isEmpty {
            let element = elements.removeFirst()
            
            guard let start = element as? InlineHTML else {
                children.append(visit(element))
                continue
            }
            
            // Try to parse the smallest valid inline HTML
            var rawHTML = start.rawHTML
            guard !rawHTML.hasPrefix("<!--") else {
                // Skip plain inline comments
                continue
            }
            
            // Check if this is a a complete "empty-element" tag (for example `<br />` or `<hr />`)
            if let parsed = try? XMLElement(xmlString: rawHTML) {
                children.append(parsed)
                continue
            }
            
            // Gradually increase the content to try and parse
            var copy = elements
            inner: while !copy.isEmpty, let next = copy.first as? any InlineMarkup {
                _ = copy.removeFirst()
                
                if let html = next as? InlineHTML, html.rawHTML.hasPrefix("<!--") {
                    // Skip this comment
                    continue inner
                }
                
                rawHTML += next.format()
                if let parsed = try? XMLElement(xmlString: rawHTML) {
                    children.append(parsed)
                    elements = copy // Skip over all the elements that make up this parsed node
                    continue outer
                }
                
            }
            // Didn't parse anything valid before running out of inline elements.
            // Just drop this html tag
            continue
        }
        
        return children
    }
    
    // MARK: Directives
    
    func visitBlockDirective(_ blockDirective: BlockDirective) -> XMLNode {
        .text("") // Do nothing for now
    }
    
    // FIXME: It would be nice if DocC processed these before rendering
    
    mutating func visitDoxygenNote(_ doxygenNote: DoxygenNote) -> XMLNode {
        .element(named: "p", children: visit(doxygenNote.children))
    }
    
    mutating func visitDoxygenReturns(_ doxygenReturns: DoxygenReturns) -> XMLNode {
        .element(named: "p", children: visit(doxygenReturns.children))
    }
    
    mutating func visitDoxygenAbstract(_ doxygenAbstract: DoxygenAbstract) -> XMLNode {
        .element(named: "p", children: visit(doxygenAbstract.children))
    }
    
    mutating func visitDoxygenParameter(_ doxygenParam: DoxygenParameter) -> XMLNode {
        .element(named: "p", children: visit(doxygenParam.children))
    }
    
    mutating func visitDoxygenDiscussion(_ doxygenDiscussion: DoxygenDiscussion) -> XMLNode {
        .element(named: "p", children: visit(doxygenDiscussion.children))
    }
}

// MARK: Helpers

private extension Image {
    /// The first element's text if it is a `Markdown.Text` element, otherwise `nil`.
    var altText: String? {
        guard let firstText = child(at: 0) as? Text else {
            return nil
        }
        return firstText.string
    }
}

private extension URL {
    /// Returns a copy of the URL without the scheme, host, and port components.
    func withoutHostAndPortAndScheme() -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        components.scheme = nil
        components.host = nil
        components.port = nil
        return components.url!
    }
}
