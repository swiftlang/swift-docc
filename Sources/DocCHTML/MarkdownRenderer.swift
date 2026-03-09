/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
package import FoundationXML
package import FoundationEssentials
internal import struct Foundation.CharacterSet
#else
package import Foundation
#endif
package import Markdown
private import DocCCommon

/// The primary goal for the rendered HTML output.
package enum RenderGoal {
    /// The rendered output should prioritize richness, optimizing for human consumption.
    ///
    /// The rendered output might include explicit work-breaks, syntax highlighted code, etc.
    case richness
    /// The minimalistic rendered output should prioritize conciseness, optimizing for consumption by machines such as SEO indexers or LLMs.
    case conciseness
}

/// An HTML renderer for DocC markdown content.
///
/// Markdown elements that have different meaning depending on where they occur in the page structure (for example links in prose vs. links in topic sections) should be handled at a layer above this plain markdown renderer.
package struct MarkdownRenderer<Provider: LinkProvider> {
    /// The path within the output archive to the page that this renderer renders.
    let path: URL
    /// The goal of the rendered HTML output.
    let goal: RenderGoal
    /// A type that provides information about other pages that the rendered page references.
    let linkProvider: Provider
    
    package init(path: URL, goal: RenderGoal, linkProvider: Provider) {
        self.path = path
        self.goal = goal
        self.linkProvider = linkProvider
    }
    
    /// Transforms a markdown paragraph into a `<p>` HTML element.
    ///
    /// As part of transforming the paragraph, the renderer also transforms all of the its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// Some _formatted_ text
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```html
    /// <p>Some <i>formatted</i> text</p>
    /// ```
    func visit(_ paragraph: Paragraph) -> XMLNode {
        .element(named: "p", children: visit(paragraph.children))
    }
    
    /// Transforms a markdown block quote into a `<blockquote>` HTML element that represents an "aside".
    ///
    /// As part of transforming the paragraph, the renderer also transforms all of its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// > Note: Something noteworthy
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <blockquote class="aside note">
    ///   <p class="label">Note</p>
    ///   <p>Something noteworthy</p>
    /// </blockquote>
    /// ```
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
    
    /// Transforms a markdown heading into a`<h[1...6]>` HTML element whose content is wrapped in an `<a>` HTML element that references the heading itself.
    ///
    /// As part of transforming the heading, the renderer also transforms all of the its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// # Some _Formatted_ text
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <h1 id="some-formatted-text">
    ///   <a href="#some-formatted-text">
    ///     Some <i>formatted</i>text
    ///   </a>
    /// </h1>
    /// ```
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't wrap the heading's content in an anchor.
    package func visit(_ heading: Heading) -> XMLNode {
        selfReferencingHeading(level: heading.level, content: visit(heading.children), plainTextTitle: heading.plainText)
    }
    
    /// Returns a `<h[1...6]>` HTML element whose content is wrapped in an `<a>` HTML element that references the heading itself.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't wrap the heading's content in an anchor.
    func selfReferencingHeading(level: Int, content: [XMLNode], plainTextTitle: @autoclosure () -> String) -> XMLElement {
        switch goal {
        case .conciseness:
            return .element(named: "h\(level)", children: content)
            
        case .richness:
            let id = urlReadableFragment(plainTextTitle())
            return .element(
                named: "h\(level)",
                children: [
                    // Wrap the heading content in an anchor ...
                    .element(named: "a", children: content, attributes: ["href": "#\(id)"])
                ],
                // ... that refers to the heading itself
                attributes: ["id": id]
            )
        }
    }
    
    /// Returns a "section" with a level-2 heading that references the section it's in.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, the returned section is a`<section>` HTML element.
    /// The first child of that `<section>` HTML element is an `<h2>` HTML element that wraps a `<a>` HTML element that references the section.
    /// After that `<h2>` HTML element, the section contains the already transformed `content` nodes representing the rest of its HTML content.
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it returns a plain `<h2>` element followed by the already transformed `content` nodes.
    func selfReferencingSection(named sectionName: String, content: [XMLNode]) -> [XMLNode] {
        guard !content.isEmpty else { return [] }
        
        switch goal {
        case .richness:
            let id = urlReadableFragment(sectionName)
            
            return [.element(
                named: "section",
                children: [
                    .element(named: "h2", children: [
                        .element(named: "a", children: [.text(sectionName)], attributes: ["href": "#\(id)"])
                    ])
                ] + content,
                attributes: ["id": id]
            )]
        case .conciseness:
            return [.element(named: "h2", children: [.text(sectionName)]) as XMLNode] + content
        }
    }
    
    /// Transforms a markdown emphasis into a`<i>` HTML element.
    func visit(_ emphasis: Emphasis) -> XMLNode {
        .element(named: "i", children: visit(emphasis.children))
    }
    
    /// Transforms a markdown strong into a`<b>` HTML element.
    func visit(_ strong: Strong) -> XMLNode {
        .element(named: "b", children: visit(strong.children))
    }
    
    /// Transforms a markdown strikethrough into a`<s>` HTML element.
    func visit(_ strikethrough: Strikethrough) -> XMLNode {
        .element(named: "s", children: visit(strikethrough.children))
    }
    
    /// Transforms a markdown inline code into a`<code>` HTML element.
    func visit(_ inlineCode: InlineCode) -> XMLNode {
        .element(named: "code", children: [.text(inlineCode.code)])
    }
    
    /// Transforms a markdown text into an HTML escaped text node.
    func visit(_ text: Text) -> XMLNode {
        .text(text.string)
    }
    
    /// Transforms a markdown line break into an empty`<br />` HTML element.
    func visit(_: LineBreak) -> XMLNode {
        .element(named: "br")
    }
    
    /// Transforms a markdown line break into a single space.
    func visit(_: SoftBreak) -> XMLNode {
        .text(" ") // A soft line break doesn't actually break the content
    }
    
    /// Transforms a markdown line break into an empty`<hr />` HTML element.
    func visit(_: ThematicBreak) -> XMLNode {
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
    
    /// Transforms a block of HTML in the source markdown into XML nodes representing the same structure with all the comments removed.
    func visit(_ html: HTMLBlock) -> XMLNode {
        do {
            let parsed = try XMLElement(xmlString: html.rawHTML)
            _removeComments(from: parsed)
            return parsed
        } catch {
            return .text("")
        }
    }
    
    /// Transforms an inline HTML tag in the source markdown into XML nodes representing the same structure with all the comments removed.
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
    
    package func wordBreak(symbolName: String) -> [XMLNode] {
        switch goal {
        case .richness:     RenderHelpers.wordBreak(symbolName: symbolName)
        case .conciseness: [.text(symbolName)]
        }
    }
    
    /// Transforms an already resolved markdown link into a`<a>` HTML element.
    ///
    /// The renderer uses its configured ``LinkProvider`` to find information about the referenced page.
    /// For example, if the link provider returns an element from the ``LinkProvider/element(for:)`` call, the renderer transforms this markdown
    /// ```md
    /// <doc://com.example.test/documentation/Something/SomeArticle>
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <a href="../somearticle/index.html">
    ///   Some Article Title
    /// </a>
    /// ```
    ///
    /// If the link provider returns `nil`, the renderer instead transforms the link into an HTML version of the provider's ``LinkProvider/fallbackLinkText(linkString:)`` text.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't insert `<wbr />` HTML elements in the symbol name.
    func visit(_ link: Link) -> XMLNode {
        guard let destination = link.destination.flatMap({ URL(string: $0) }) else {
            return .text("")
        }
        
        let linkedElement = linkProvider.element(for: destination)
        // Check if the link has an authored link title or if it's an "autolink" (for example `<LINK>` or `[](LINK)`)
        guard link.isAutolink else {
            var customTitle = [XMLNode]()
            for child in link.inlineChildren {
                if let code = child as? InlineCode {
                    customTitle.append(.element(named: "code", children: wordBreak(symbolName: code.code)))
                } else {
                    customTitle.append(visit(child))
                }
            }
            
            return .element(
                named: "a",
                children: customTitle,
                attributes: [
                    // Use relative links for DocC elements and the full link otherwise.
                    "href": linkedElement.flatMap { path(to: $0.path) } ?? destination.absoluteString
                ]
            )
        }
        
        // Make a relative link
        if let linkedElement {
            let children: [XMLNode] = switch linkedElement.names {
                case .single(.conceptual(let name)): [ .text(name) ]
                case .single(.symbol(let name)):     [ .element(named: "code", children: wordBreak(symbolName: name)) ]
                
                case .languageSpecificSymbol(let namesByLanguageID):
                    RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { language, name in
                        .element(named: "code", children: wordBreak(symbolName: name), attributes: ["class": "\(language.id)-only"])
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
            // If this is an unresolved documentation link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation
            return .text(linkProvider.fallbackLinkText(linkString: destination.path))
        }
    }
    
    /// Transforms an already resolved markdown symbol link into a`<a>` HTML element.
    ///
    /// The renderer uses its configured ``LinkProvider`` to find information about the referenced symbol.
    /// For example, if the link provider returns an element from the ``LinkProvider/element(for:)`` call, the renderer transforms this markdown
    /// ```md
    /// ``doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)``
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <a href="../somemethod(with:and:)/index.html">
    ///   <code>some<wbr/>Method(<wbr/>with:<wbr/>and:)</code>
    /// </a>
    /// ```
    ///
    /// If the link provider returns `nil`, the renderer instead transforms the symbol link into a `<code>` HTML element that wraps the provider's ``LinkProvider/fallbackLinkText(linkString:)`` text.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't insert `<wbr />` HTML elements in the symbol name.
    func visit(_ symbolLink: SymbolLink) -> XMLNode {
        guard let destination = symbolLink.destination.flatMap({ URL(string: $0) }),
              let linkedElement = linkProvider.element(for: destination)
        else {
            // If this is an unresolved symbol link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation.
            return .element(named: "code", children: [.text(linkProvider.fallbackLinkText(linkString: symbolLink.destination ?? ""))])
        }
        
        let children: [XMLNode] = switch linkedElement.names {
            case .single(.conceptual(let name)): [ .text(name) ]
            case .single(.symbol(let name)):     [ .element(named: "code", children: wordBreak(symbolName: name)) ]
                
            case .languageSpecificSymbol(let namesByLanguageID):
                RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { language, name in
                    .element(named: "code", children: wordBreak(symbolName: name), attributes: ["class": "\(language.id)-only"])
                }
        }
        
        return .element(
            named: "a",
            children: children,
            attributes: ["href": path(to: linkedElement.path)]
        )
    }
    
    package func path(to other: URL) -> String {
        let from = path
        let to   = other
        
        guard from != to else { return "." }

        // To be able to compare the components of the two URLs they both need to be absolute and standardized.
        let fromComponents = from.absoluteURL.standardizedFileURL.pathComponents
        let toComponents   =   to.absoluteURL.standardizedFileURL.pathComponents

        let commonPrefixLength = Array(zip(fromComponents, toComponents).prefix { lhs, rhs in lhs == rhs }).count

        let relativeComponents = repeatElement("..", count: fromComponents.count - commonPrefixLength - 1 /* the "index.html" component doesn't count in a web server */)
            + toComponents.dropFirst(commonPrefixLength)
       
        return relativeComponents.joined(separator: "/")
            .lowercased() // Don't make assumptions about a case insensitive hosting environment.
    }
    
    /// Transforms a markdown image into a`<picture>` HTML element that wraps an `<img>` element and zero or more `<source>` elements.
    ///
    /// The renderer uses its configured ``LinkProvider`` to find information about the referenced asset.
    /// For example, if the link provider returns an asset with both light and dark image representations from the ``LinkProvider/assetNamed(_:)`` call, the renderer transforms this markdown
    /// ```md
    /// ![Some alt text](some-image.png)
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <picture>
    ///   <source media="(prefers-color-scheme: light)" src="relative/path/to/some-image.png"/>
    ///   <source media="(prefers-color-scheme: dark)" src="relative/path/some-image~dark.png"/>
    ///   <img alt="Some alt text" decoding="async" loading="lazy"/>
    /// </picture>
    /// ```
    func visit(_ image: Image) -> XMLNode {
        guard let asset = image.source.flatMap({ linkProvider.assetNamed($0) }), !asset.files.isEmpty else {
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
        if asset.files.count == 1 {
            // When all image are either dark/light mode, add them directly on the "img" element
            imgAttributes.merge(srcAttributes(for: asset.files.first!.value), uniquingKeysWith: { _, new in new })
        } else {
            // Define a "source" element for each dark/light style
            for (style, images) in asset.files.sorted(by: { $0.key.rawValue > $1.key.rawValue }) { // order light images before dark images
                var attributes = srcAttributes(for: images)
                attributes["media"] = "(prefers-color-scheme: \(style.rawValue))"
                children.append(.element(named: "source", attributes: attributes))
            }
        }
        
        children.append(.element(named: "img", attributes: imgAttributes))
        
        return .element(named: "picture", children: children)
    }
    
    /// Transforms a markdown code block (either fenced or indented) into a `<pre>` HTML element that wraps a `<code>` HTML element containing the code block's code.
    ///
    /// If the fenced code block contains source language information on its opening line, the renderer includes this in the `<pre>` element.
    /// For example, the renderer transforms this markdown
    /// ```
    /// ~~~lang
    /// Some block of code
    /// ~~~
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <pre class="lang">
    ///   <code>Some block of code</code>
    /// </pre>
    /// ```
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
    
    /// Transforms a markdown unordered list into a`<ul>` HTML element.
    ///
    /// As part of transforming the unordered list, the renderer also transforms all of its list items and their content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// - First
    /// - Second
    ///   + A
    ///   + B
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <ul>
    ///   <li>
    ///     <p>First</p>
    ///   </li>
    ///   <li>
    ///     <p>Second</p>
    ///     <ul>
    ///       <li>
    ///         <p>A</p>
    ///       </li>
    ///       <li>
    ///         <p>B</p>
    ///       </li>
    ///     </ul>
    ///   </li>
    /// </ul>
    /// ```
    func visit(_ unorderedList: UnorderedList) -> XMLNode {
        .element(named: "ul", children: visit(unorderedList.children))
    }
    
    /// Transforms a markdown ordered list into a`<ul>` HTML element.
    ///
    /// As part of transforming the ordered list, the renderer also transforms all of its list items and their content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// 1. One
    /// 2. Two
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <ol>
    ///   <li>
    ///     <p>One</p>
    ///   </li>
    ///   <li>
    ///     <p>Two</p>
    ///   </li>
    /// </ol>
    /// ```
    func visit(_ orderedList: OrderedList) -> XMLNode {
        .element(named: "ol", children: visit(orderedList.children))
    }
    
    /// Transforms a markdown list item into a`<li>` HTML element.
    ///
    /// See ``visit(_:)-(UnorderedList)`` or ``visit(_:)-(OrderedList)`` for examples.
    func visit(_ listItem: ListItem) -> XMLNode {
        .element(named: "li", children: visit(listItem.children))
    }
    
    // MARK: Tables
    
    /// Transforms a markdown table into a`<table>` HTML element.
    ///
    /// As part of transforming the table, the renderer also transforms the table's head and body and all their cells and their content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// | First | Second | Third |
    /// | ----- | ------ | ----- |
    /// | One           || Two   |
    /// | Three | Four          ||
    /// | Five                 |||
    /// ```
    /// into XML nodes representing this HTML structure
    /// ```
    /// <table>
    ///   <thead>
    ///     <tr>
    ///       <th>First</th>
    ///       <th>Second</th>
    ///       <th>Third</th>
    ///     </tr>
    ///   </thead>
    ///   <tbody>
    ///     <tr>
    ///       <td colspan="2">One</td>
    ///       <td>Two</td>
    ///     </tr>
    ///     <tr>
    ///       <td>Three</td>
    ///       <td colspan="2">Four</td>
    ///     </tr>
    ///     <tr>
    ///       <td colspan="3">Five</td>
    ///     </tr>
    ///   </tbody>
    /// </table>
    /// ```
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
        
        // Check if the markup contains _any_ inline HTML. If it doesn't, then we can simply visit each child.
        guard container.contains(where: { $0 is InlineHTML }) else {
            for element in container {
                children.append(visit(element))
            }
            return children
        }
        
        // The markup contains at least _some_ inline HTML. This could be either:
        // - A comment like `<!-- comment -->` that we'd want to exclude from the output.
        // - An empty element like `<br />` or `<hr />` that's complete on its own.
        // - An element with children like `<span style="color: red;">Something</span>` that needs to be created out of multiple markup elements.
        //
        // Because it may take multiple markdown elements to create an HTML element, we pop elements rather than iterating
        var remainder = Array(container)[...]
        while let element = remainder.popFirst() {
            guard let openingHTML = element as? InlineHTML else {
                // If the markup _isn't_ inline HTML we can simply visit it to transform it.
                children.append(visit(element))
                continue
            }
            
            // Otherwise, we need to determine how long this markdown element is.
            let rawHTML = openingHTML.rawHTML
            // Simply skip any HTML/XML comments.
            guard !rawHTML.hasPrefix("<!--") else {
                continue
            }
            
            // Next, check if its empty element (for example `<br />` or `<hr />`) that's complete on its own.
            
            // On non-Darwin platforms, `XMLElement(xmlString:)` sometimes crashes for certain invalid / incomplete XML strings.
            // To minimize the risk of this happening, don't try to parse the XML string as an empty HTML element unless it ends with "/>"
            if rawHTML.hasSuffix("/>"), let parsed = try? XMLElement(xmlString: rawHTML) {
                children.append(parsed)
            }
            // Lastly, check if this is the start of an HTML element that needs to be constructed out of more than one markup element
            else if let parsed = _findMultiMarkupHTMLElement(in: &remainder, openingRawHTML: rawHTML) {
                children.append(parsed)
            }
        }
        
        return children
    }
    
    private func _findMultiMarkupHTMLElement(in remainder: inout ArraySlice<any Markup>, openingRawHTML: String) -> XMLNode? {
        // Don't modify `remainder` until we know that we've parsed a valid HTML element.
        var copy = remainder
        
        var rawHTML = openingRawHTML
        let tagName = rawHTML.dropFirst(/* the opening "<" */).prefix(while: \.isLetter)
        let expectedClosingTag = "</\(tagName)>"
        
        // Only iterate as long the markup is _inline_ markup.
        while let next = copy.first as? any InlineMarkup {
            _ = copy.removeFirst()
            let html = next as? InlineHTML
            
            // Skip any HTML/XML comments _inside_ this HTML tag
            if let html, html.rawHTML.hasPrefix("<!--") {
                continue
            }
            
            // If this wasn't a comment, accumulate more raw HTML to try and parse
            rawHTML += next.format()
            // On non-Darwin platforms, `XMLElement(xmlString:)` sometimes crashes for certain invalid / incomplete XML strings.
            // To minimize the risk of this happening, don't try to parse the XML string as an empty HTML element unless it ends with "/>"
            if html?.rawHTML == expectedClosingTag, let parsed = try? XMLElement(xmlString: rawHTML) {
                remainder = copy // Skip over all the elements that were used to create that HTML element.
                return parsed // Include the valid HTML element in the output.
            }
        }
        // If we reached the end of the _inline_ markup without parsing a valid HTML element, skip just that opening markup without updating `remainder`
        return nil
    }
    
    // MARK: Directives
    
    func visit(_: BlockDirective) -> XMLNode {
        .text("") // TODO: Support the block directives that appear as in-page content (rdar://165755944)
    }
    
    // TODO: Support rendering Doxygen tags. (rdar://165755750)
    // It would be nice if DocC processed in the model, so that all renderers could have just one code path for parameters, returns, etc.
    
    func visit(_: DoxygenNote) -> XMLNode {
        .text("")
    }
    func visit(_: DoxygenReturns) -> XMLNode {
        .text("")
    }
    func visit(_: DoxygenAbstract) -> XMLNode {
        .text("")
    }
    func visit(_: DoxygenParameter) -> XMLNode {
        .text("")
    }
    func visit(_: DoxygenDiscussion) -> XMLNode {
        .text("")
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

private extension CharacterSet {
    static let fragmentCharactersToRemove = CharacterSet.punctuationCharacters // Remove punctuation from fragments
        .union(CharacterSet(charactersIn: "`"))       // Also consider back-ticks as punctuation. They are used as quotes around symbols or other code.
        .subtracting(CharacterSet(charactersIn: "-")) // Don't remove hyphens. They are used as a whitespace replacement.
    static let whitespaceAndDashes = CharacterSet.whitespaces
        .union(CharacterSet(charactersIn: "-\u{2013}\u{2014}")) // hyphen, en dash, em dash
}

/// Creates a more readable version of a fragment by replacing characters that are not allowed in the fragment of a URL with hyphens.
///
/// If this step is not performed, the disallowed characters are instead percent escape encoded, which is less readable.
/// For example, a fragment like `"#hello world"` is converted to `"#hello-world"` instead of `"#hello%20world"`.
func urlReadableFragment(_ fragment: some StringProtocol) -> String {
    var fragment = fragment
        // Trim leading/trailing whitespace
        .trimmingCharacters(in: .whitespaces)
    
        // Replace continuous whitespace and dashes
        .components(separatedBy: .whitespaceAndDashes)
        .filter({ !$0.isEmpty })
        .joined(separator: "-")
    
    // Remove invalid characters
    fragment.unicodeScalars.removeAll(where: CharacterSet.fragmentCharactersToRemove.contains)
    
    return fragment
}
