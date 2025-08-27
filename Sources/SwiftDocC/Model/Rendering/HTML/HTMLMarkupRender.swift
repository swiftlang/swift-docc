/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown

struct HTMLMarkupRender: MarkupVisitor {
    let reference: ResolvedTopicReference
    let context: DocumentationContext
    
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
        guard let destination = link.destination else {
            return .text("")
        }
        
        let customTitle: [XMLNode]?
        if link.hasChildren {
            var a = [XMLNode]()
            for child in link.inlineChildren {
                a.append(visit(child))
            }
            
            if a == [.text(destination)] {
                customTitle = nil
            } else {
                customTitle = a
            }
        } else {
            customTitle = nil
        }
        
        // Make a relative link
        if let resolved = context.referenceIndex[destination],
           let node = context.documentationCache[resolved]
        {
            
            let children = customTitle ?? {
                switch node.name {
                    case .conceptual(let title):
                        [ .text(title) ]
                    case .symbol(let name):
                        [ .element(named: "code", children: [.text(name)]) ]
                }
            }()
            
            return .element(
                named: "a",
                children: children,
                attributes: ["href": path(to: resolved)]
            )
        } else if !destination.hasPrefix("doc:") {
            // This could be a http link
            
            let children = customTitle ?? [.text(destination)]
            
            return .element(
                named: "a",
                children: children,
                attributes: ["href": destination]
            )
        }
        else {
            let name = LinkCompletionTools.parse(linkString: destination).last?.name ?? ""
            return .text(name)
        }
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> XMLNode {
        guard let destination = symbolLink.destination,
              let resolved = context.referenceIndex[destination],
              let node = context.documentationCache[resolved],
              let symbol = node.semantic as? Symbol
        else {
            let name = symbolLink.destination.flatMap { LinkCompletionTools.parse(linkString: $0).last?.name } ?? ""
            return .element(named: "code", children: [.text(name)])
        }
        
        if case .conceptual(let title) = node.name {
            // Custom title is same in all languages
            return .element(
                named: "a",
                children: [.text(title)],
                attributes: ["href": path(to: resolved)]
            )
        }
        
        let link = XMLNode.element(
            named: "a",
            children: [],
            attributes: ["href": path(to: resolved)]
        )
        
        for (trait, variant) in symbol.titleVariants.allValues {
            guard let lang = trait.interfaceLanguage else { continue }
            
            var attributes: [String: String] = [:]
            if symbol.titleVariants.allValues.count > 1 {
                attributes["class"] = "\(lang)-only"
            }
            
            link.addChild(
                .element(named: "code", children: [.text(variant)], attributes: attributes)
            )
        }
        return link
//
//        let hasMultipleLanguages = Set(symbol.titleVariants.allValues.map(\.variant)).count > 1
//        guard hasMultipleLanguages else {
//            // Same spelling in all languages
//            return .element(
//                named: "a",
//                children: [.element(named: "code", children: [symbol.title])],
//                attributes: ["href": path(to: resolved)]
//            )
//        }
//        
//        let titles = symbol.titleVariants.map {
//            
//        }
//        
//        let titles = symbol.titleVariants.allValues
//        
//        let spelling: XMLNode = switch node.name {
//            case .conceptual(let title): .text(title)
//            case .symbol(let name):
//        }
//        
//        return .element(
//            named: "a",
//            children: [spelling],
//            attributes: ["href": path(to: resolved)]
//        )
    }
    
    private func path(to destination: ResolvedTopicReference) -> String {
        (destination.url.relative(to: reference.url)?.path
            ?? destination.path) + "/index.html"
    }
    
    
    func visitImage(_ image: Image) -> XMLNode {
        guard let source = image.source,
              let asset = context.resolveAsset(named: source, in: reference)
        else {
            return .text("") // ???: What do we return here?
        }
        
        let data = asset.data(bestMatching: .init(userInterfaceStyle: .light, displayScale: .double))
        
        let finalImageURL = URL(string: "\(String(repeating: "../", count: reference.pathComponents.count - 1))images/\(reference.bundleID.rawValue)/\(data.url.lastPathComponent)")!
        
        var attributes = [
            "src": finalImageURL.path,
            "decoding": "async",
            "loading": "lazy",
        ]
        if let scale = data.traitCollection?.displayScale {
            attributes["srcset"] = "\(finalImageURL.path) \(scale.rawValue)"
        }
        if let altText = image.altText {
            attributes["alt"] = altText
        }
        
        return .element(named: "picture", children: [
            .element(named: "img", attributes: attributes)
        ])
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
        
        var renderer = HTMLMarkupRender(reference: reference, context: context)
        
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
    
    // MARK: Blah
    
    func visitBlockDirective(_ blockDirective: BlockDirective) -> XMLNode {
        .text("") // Do nothing for now
    }
    
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
