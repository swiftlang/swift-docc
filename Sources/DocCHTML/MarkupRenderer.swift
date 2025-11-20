/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

package import Foundation
package import Markdown

package struct MarkupRenderer<Provider: LinkProvider> {
    /// The path within the output archive to the page that this renderer renders.
    let path: URL
    /// A type that provides information about other pages that the rendered page references.
    let linkProvider: Provider
    
    package init(path: URL, linkProvider: Provider) {
        self.path = path
        self.linkProvider = linkProvider
    }
    
    package func visit(_ paragraph: Paragraph) -> XMLNode {
        .element(named: "p", children: visit(paragraph.children))
    }
    
    func visit(_ blockQuote: BlockQuote) -> XMLNode {
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
    
    package func visit(_ heading: Heading) -> XMLNode {
        .element(named: "h\(heading.level)", children: visit(heading.children))
    }
    
    func visit(_ emphasis: Emphasis) -> XMLNode {
        .element(named: "i", children: visit(emphasis.children))
    }
    
    func visit(_ strong: Strong) -> XMLNode {
        .element(named: "b", children: visit(strong.children))
    }
    
    func visit(_ strikethrough: Strikethrough) -> XMLNode {
        .element(named: "s", children: visit(strikethrough.children))
    }
    
    func visit(_ inlineCode: InlineCode) -> XMLNode {
        .element(named: "code", children: [.text(inlineCode.code)])
    }
    
    func visit(_ text: Text) -> XMLNode {
        .text(text.string)
    }
    
    func visit(_ lineBreak: LineBreak) -> XMLNode {
        .element(named: "br")
    }
    
    func visit(_ softBreak: SoftBreak) -> XMLNode {
        .text(" ") // A soft line break doesn't actually break the content
    }
    
    func visit(_ thematicBreak: ThematicBreak) -> XMLNode {
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
    
    func visit(_ html: HTMLBlock) -> XMLNode {
        do {
            let parsed = try XMLElement(xmlString: html.rawHTML)
            _removeComments(from: parsed)
            return parsed
        } catch {
            return .text("")
        }
    }
    
    func visit(_ html: InlineHTML) -> XMLNode {
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
    
    func visit(_ link: Link) -> XMLNode {
        guard let destination = link.destination.flatMap({ URL(string: $0) }) else {
            return .text("")
        }
        
        if link.childCount > 0 {
            var customTitle = [XMLNode]()
            for child in link.inlineChildren {
                if let code = child as? InlineCode {
                    customTitle.append(.element(named: "code", children: RenderHelpers.wordBreak(symbolName: code.code)))
                } else {
                    customTitle.append(visit(child))
                }
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
                        case .symbol(let name):     [ .element(named: "code", children: RenderHelpers.wordBreak(symbolName: name)) ]
                    }
                    
                case .languageSpecificSymbol(let namesByLanguageID):
                    RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { languageID, name in
                        .element(named: "code", children: RenderHelpers.wordBreak(symbolName: name), attributes: ["class": "\(languageID)-only"])
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
    
    func visit(_ symbolLink: SymbolLink) -> XMLNode {
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
                    case .symbol(let name):     [ .element(named: "code", children: RenderHelpers.wordBreak(symbolName: name)) ]
                }
                
            case .languageSpecificSymbol(let namesByLanguageID):
                RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { languageID, name in
                    .element(named: "code", children: RenderHelpers.wordBreak(symbolName: name), attributes: ["class": "\(languageID)-only"])
                }
        }
        
        return .element(
            named: "a",
            children: children,
            attributes: ["href": path(to: linkedElement.path)]
        )
    }
    
    func path(to other: URL) -> String {
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
    
    func visit(_ image: Image) -> XMLNode {
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
    
    func visit(_ codeBlock: CodeBlock) -> XMLNode {
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
    
    func visit(_ unorderedList: UnorderedList) -> XMLNode {
        .element(named: "ul", children: visit(unorderedList.children))
    }
    
    func visit(_ orderedList: OrderedList) -> XMLNode {
        .element(named: "ol", children: visit(orderedList.children))
    }
    
    func visit(_ listItem: ListItem) -> XMLNode {
        .element(named: "li", children: visit(listItem.children))
    }
    
    // MARK: Tables
    
    func visit(_ table: Table) -> XMLNode {
        let element = XMLElement(name: "table")
                
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
                            children: visit(cell.children),
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
                            children: visit(cell.children),
                            attributes: attributes
                        )
                    })
                })
            )
        }
        
        return element
    }
    
    // MARK: Markup children
    
    private func visit(_ container: MarkupChildren) -> [XMLNode] {
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
    
    func visit(_ blockDirective: BlockDirective) -> XMLNode {
        .text("") // Do nothing for now
    }
    
    // FIXME: It would be nice if DocC processed these before rendering
    
    func visit(_ doxygenNote: DoxygenNote) -> XMLNode {
        .element(named: "p", children: visit(doxygenNote.children))
    }
    
    func visit(_ doxygenReturns: DoxygenReturns) -> XMLNode {
        .element(named: "p", children: visit(doxygenReturns.children))
    }
    
    func visit(_ doxygenAbstract: DoxygenAbstract) -> XMLNode {
        .element(named: "p", children: visit(doxygenAbstract.children))
    }
    
    func visit(_ doxygenParam: DoxygenParameter) -> XMLNode {
        .element(named: "p", children: visit(doxygenParam.children))
    }
    
    func visit(_ doxygenDiscussion: DoxygenDiscussion) -> XMLNode {
        .element(named: "p", children: visit(doxygenDiscussion.children))
    }
    
    // MARK: Default
    
    @_disfavoredOverload
    package func visit(_ markup: some Markup) -> XMLNode {
        // Check common markup types first
        if let paragraph = markup as? Paragraph {
            return visit(paragraph)
        } else if let text = markup as? Text {
            return visit(text)
        } else if let strong = markup as? Strong {
            return visit(strong)
        } else if let emphasis = markup as? Emphasis {
            return visit(emphasis)
        } else if let symbolLink = markup as? SymbolLink {
            return visit(symbolLink)
        } else if let link = markup as? Link {
            return visit(link)
        } else if let inlineCode = markup as? InlineCode {
            return visit(inlineCode)
        } else if let image = markup as? Image {
            return visit(image)
        } else if let listItem = markup as? ListItem {
            return visit(listItem)
        } else if let heading = markup as? Heading {
            return visit(heading)
        } else if let orderedList = markup as? OrderedList {
            return visit(orderedList)
        } else if let unorderedList = markup as? UnorderedList {
            return visit(unorderedList)
        } else if let codeBlock = markup as? CodeBlock {
            return visit(codeBlock)
        } else if let blockQuote = markup as? BlockQuote {
            return visit(blockQuote)
        } else if let table = markup as? Table {
            return visit(table)
        } else if let lineBreak = markup as? LineBreak {
            return visit(lineBreak)
        } else if let softBreak = markup as? SoftBreak {
            return visit(softBreak)
        } else if let thematicBreak = markup as? ThematicBreak {
            return visit(thematicBreak)
        } else if let blockDirective = markup as? BlockDirective {
            return visit(blockDirective)
        } else if let inlineHTML = markup as? InlineHTML {
            return visit(inlineHTML)
        } else if let html = markup as? HTMLBlock {
            return visit(html)
        } else if let strikethrough = markup as? Strikethrough {
            return visit(strikethrough)
        } else if let customBlock = markup as? CustomBlock {
            return visit(customBlock)
        } else if let document = markup as? Document {
            return visit(document)
        } else if let customInline = markup as? CustomInline {
            return visit(customInline)
        } else if let attributes = markup as? InlineAttributes {
            return visit(attributes)
        } else if let doxygenDiscussion = markup as? DoxygenDiscussion {
            return visit(doxygenDiscussion)
        } else if let doxygenNote = markup as? DoxygenNote {
            return visit(doxygenNote)
        } else if let doxygenAbstract = markup as? DoxygenAbstract {
            return visit(doxygenAbstract)
        } else if let doxygenParam = markup as? DoxygenParameter {
            return visit(doxygenParam)
        } else if let doxygenReturns = markup as? DoxygenReturns {
            return visit(doxygenReturns)
        } else if markup is Table.Head || markup is Table.Body || markup is Table.Row || markup is Table.Cell {
            fatalError("This renderer is expected to visit the `Table` element, not it's member. It's a programming error to pass one of its member type directly.")
        } else {
            fatalError("Encountered unknown markup element. All supported markup elements should already be defined by the Markdown framework")
        }
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
