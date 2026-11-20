/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

#if canImport(FoundationXML)
// TODO: Consider other HTML rendering options as a future improvement (rdar://165755530)
// XML nodes are still used to parse raw HTML in the markup.
private import FoundationXML
private import FoundationEssentials
internal import struct Foundation.CharacterSet
#else
private import Foundation
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
package struct MarkdownRenderer<Provider: LinkProvider, Parser: RenderableDirectiveParser> {
    /// The path components within the output archive to the page that this renderer renders.
    private let pathComponents: [String]
    /// The goal of the rendered HTML output.
    let goal: RenderGoal
    /// A type that provides information about other pages that the rendered page references.
    let linkProvider: Provider
    /// A type that parses on-page renderable directives and returns the information required to render the directive in HTML.
    let renderableDirectiveParser: Parser
    
    package init(path: String, goal: RenderGoal, linkProvider: Provider, renderableDirectiveParser: Parser) {
        self.pathComponents = path.components(separatedBy: "/")
        self.goal = goal
        self.linkProvider = linkProvider
        self.renderableDirectiveParser = renderableDirectiveParser
    }
    
    /// Transforms a markdown paragraph into a `<p>` HTML element.
    ///
    /// As part of transforming the paragraph, the renderer also transforms all of the its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// Some _formatted_ text
    /// ```
    /// into nodes representing this HTML structure
    /// ```html
    /// <p>Some <em>formatted</em> text</p>
    /// ```
    func visitParagraph(_ paragraph: Paragraph, into output: inout [HTMLNode]) {
        if paragraph.childCount == 1, let image = paragraph.child(at: 0) as? Image {
            visitImage(image, into: &output)
        } else {
            output.append(p(contents: _visit(paragraph.children)))
        }
    }
    
    /// Transforms a markdown block quote into a `<aside>` HTML element that represents an "aside".
    ///
    /// As part of transforming the paragraph, the renderer also transforms all of its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// > Note: Something noteworthy
    /// ```
    /// into nodes representing this HTML structure
    /// ```
    /// <aside class="note">
    ///   <p class="label">Note</p>
    ///   <p>Something noteworthy</p>
    /// </aside>
    /// ```
    func visitBlockQuote(_ blockQuote: BlockQuote, into output: inout [HTMLNode]) {
        let aside = Aside(blockQuote)
        
        var children: [HTMLNode] = [
            p(attributes: [.class("label")], contents: [.text(aside.kind.displayName)])
        ]
        for child in aside.content {
            visit(child, into: &children)
        }
        
        output.append(DocCHTML.aside(attributes: [.class(aside.kind.rawValue.lowercased())], contents: children))
    }
    
    /// Transforms a markdown heading into a`<h[1...6]>` HTML element whose content is wrapped in an `<a>` HTML element that references the heading itself.
    ///
    /// As part of transforming the heading, the renderer also transforms all of the its content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// # Some _Formatted_ text
    /// ```
    /// into nodes representing this HTML structure
    /// ```
    /// <h1 id="some-formatted-text">
    ///   <a href="#some-formatted-text">
    ///     Some <em>formatted</em>text
    ///   </a>
    /// </h1>
    /// ```
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't wrap the heading's content in an anchor.
    func visitHeading(_ heading: Heading, into output: inout [HTMLNode]) {
        output.append(selfReferencingHeading(level: heading.level, content: _visit(heading.children), plainTextTitle: heading.plainText))
    }
    
    /// Returns a `<h[1...6]>` HTML element whose content is wrapped in an `<a>` HTML element that references the heading itself.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't wrap the heading's content in an anchor.
    func selfReferencingHeading(level: Int, content: [HTMLNode], plainTextTitle: @autoclosure () -> String) -> HTMLNode {
        switch goal {
        case .conciseness:
            return heading(level: level, contents: content)
            
        case .richness:
            let id = urlReadableFragment(plainTextTitle())
            return heading(level: level, attributes: [.id(id)], contents: [
                // Wrap the heading content in an anchor that references the heading element
                a(attributes: [.href("#\(id)")], contents: content)
            ])
        }
    }
    
    /// Returns a "section" with a level-2 heading that references the section it's in.
    ///
    /// When the renderer has a ``RenderGoal/richness`` goal, the returned section is a`<section>` HTML element.
    /// The first child of that `<section>` HTML element is an `<h2>` HTML element that wraps a `<a>` HTML element that references the section.
    /// After that `<h2>` HTML element, the section contains the already transformed `content` nodes representing the rest of its HTML content.
    ///
    /// When the renderer has a ``RenderGoal/conciseness`` goal, it returns a plain `<h2>` element followed by the already transformed `content` nodes.
    func selfReferencingSection(named sectionName: String, content: consuming [HTMLNode]) -> [HTMLNode] {
        guard !content.isEmpty else { return [] }
        
        switch goal {
        case .richness:
            let id = urlReadableFragment(sectionName)
            
            return [section(attributes: [.id(id)], contents: [
                h2(contents: [
                    a(attributes: [.href("#\(id)")], contents: [.text(sectionName)])
                ])
            ] + content)]
        case .conciseness:
            return [h2(contents: [.text(sectionName)])] + content
        }
    }
    
    /// Transforms a markdown emphasis into a`<em>` HTML element.
    func visitEmphasis(_ emphasis: Emphasis, into output: inout [HTMLNode]) {
        output.append(em(contents: _visit(emphasis.children)))
    }
    
    /// Transforms a markdown strong into a`<strong>` HTML element.
    func visitStrong(_ strong: Strong, into output: inout [HTMLNode]) {
        output.append(DocCHTML.strong(contents: _visit(strong.children)))
    }
    
    /// Transforms a markdown strikethrough into a`<s>` HTML element.
    func visitStrikethrough(_ strikethrough: Strikethrough, into output: inout [HTMLNode]) {
        output.append(s(contents: _visit(strikethrough.children)))
    }
    
    /// Transforms a markdown inline code into a`<code>` HTML element.
    func visitInlineCode(_ inlineCode: InlineCode, into output: inout [HTMLNode]) {
        output.append(code(contents: [.text(inlineCode.code)]))
    }
    
    /// Transforms a markdown text into an HTML escaped text node.
    func visitText(_ text: Text, into output: inout [HTMLNode]) {
        output.append(.text(text.string))
    }
    
    /// Transforms a markdown line break into an empty`<br>` HTML element.
    func visitLineBreak(_: LineBreak, into output: inout [HTMLNode]) {
        output.append(br)
    }
    
    /// Transforms a markdown line break into a single space.
    func visitSoftBreak(_: SoftBreak, into output: inout [HTMLNode]) {
        output.append(.text(" ")) // A soft line break doesn't actually break the content
    }
    
    /// Transforms a markdown line break into an empty`<hr>` HTML element.
    func visitThematicBreak(_: ThematicBreak, into output: inout [HTMLNode]) {
        output.append(hr)
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
    
    /// Transforms a block of HTML in the source markdown into nodes representing the same structure with all the comments removed.
    func visitHTMLBlock(_ html: HTMLBlock, into output: inout [HTMLNode]) {
        do {
            let parsed = try XMLElement(xmlString: html.rawHTML)
            _removeComments(from: parsed)
            if let element = HTMLNode(from: parsed) {
                output.append(element)
            }
        } catch {
            return // Don't add anything to the output
        }
    }
    
    /// Transforms an inline HTML tag in the source markdown into nodes representing the same structure with all the comments removed.
    func visitInlineHTML(_ html: InlineHTML, into output: inout [HTMLNode]) {
        // Inline HTML is one tag at a time, meaning that the closing and opening tags are parsed separately
        // Because of this, we can't parse it with `XMLElement` or `XMLParser`.
        
        // We assume that we want all tags except for comments
        guard !html.rawHTML.hasPrefix("<!--") else {
            return // Don't add anything to the output
        }
        
        // We can't create a valid structured HTMLNode (because that closing tag will come later,
        // so we return the raw tag as text.
        output.append(.text(html.rawHTML))
    }
    
    package func wordBreak(symbolName: String) -> [HTMLNode] {
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
    /// into nodes representing this HTML structure
    /// ```
    /// <a href="../somearticle/index.html">
    ///   Some Article Title
    /// </a>
    /// ```
    ///
    /// If the link provider returns `nil`, the renderer instead transforms the link into an HTML version of the provider's ``LinkProvider/fallbackLinkText(linkString:)`` text.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't insert `<wbr>` HTML elements in the symbol name.
    func visitLink(_ link: Link, into output: inout [HTMLNode]) {
        guard let destination = link.destination else {
            // If the link has text, return that inline
            for child in link.children {
                visit(child, into: &output)
            }
            return
        }
        
        let linkedElement = linkProvider.element(for: destination)
        // Check if the link has an authored link title or if it's an "autolink" (for example `<LINK>` or `[](LINK)`)
        guard link.isAutolink else {
            var customTitle = [HTMLNode]()
            for child in link.inlineChildren {
                if let inlineCode = child as? InlineCode {
                    customTitle.append(code(contents: wordBreak(symbolName: inlineCode.code)))
                } else {
                    visit(child, into: &customTitle)
                }
            }
            
            output.append(a(attributes: [
                // Use relative links for DocC elements and the full link otherwise.
                .href(linkedElement.flatMap { path(to: $0.path) } ?? destination)
            ], contents: customTitle))
            return
        }
        
        // Make a relative link
        if let linkedElement {
            let content: [HTMLNode] = switch linkedElement.names {
                case .single(.conceptual(let name)): [ .text(name) ]
                case .single(.symbol(let name)):     [ code(contents: wordBreak(symbolName: name)) ]
                
                case .languageSpecificSymbol(let namesByLanguageID):
                    RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { language, name in
                        code(attributes: [language.filterAttribute], contents: wordBreak(symbolName: name))
                    }
            }
            
            output.append(anchor(linkingTo: linkedElement, contents: content))
        } else if destination.hasPrefix("doc:") {
            // If this is an unresolved documentation link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation
            var path = destination.dropFirst(4) // "doc:"
            if path.hasPrefix("//") {
                // If this is an absolute link, drop the "authority" ("//" prefix and "host" component)
                path = path.dropFirst(2).drop(while: { $0 != "/" })
            }
            output.append(.text(linkProvider.fallbackLinkText(linkString: String(path))))
        } else {
            // This could be a http link
            output.append(a(
                attributes: [.href(destination)],
                contents:   [.text(destination)]
            ))
        }
    }
    
    /// Transforms an already resolved markdown symbol link into a`<a>` HTML element.
    ///
    /// The renderer uses its configured ``LinkProvider`` to find information about the referenced symbol.
    /// For example, if the link provider returns an element from the ``LinkProvider/element(for:)`` call, the renderer transforms this markdown
    /// ```md
    /// ``doc://com.example.test/documentation/Something/SomeClass/someMethod(_:_:)``
    /// ```
    /// into nodes representing this HTML structure
    /// ```
    /// <a href="../somemethod(with:and:)/index.html">
    ///   <code>some<wbr>Method(<wbr>with:<wbr>and:)</code>
    /// </a>
    /// ```
    ///
    /// If the link provider returns `nil`, the renderer instead transforms the symbol link into a `<code>` HTML element that wraps the provider's ``LinkProvider/fallbackLinkText(linkString:)`` text.
    ///
    /// - Note: When the renderer has a ``RenderGoal/conciseness`` goal, it doesn't insert `<wbr>` HTML elements in the symbol name.
    func visitSymbolLink(_ symbolLink: SymbolLink, into output: inout [HTMLNode]) {
        guard let destination = symbolLink.destination,
              let linkedElement = linkProvider.element(for: destination)
        else {
            // If this is an unresolved symbol link, try to display only the name of the linked symbol; without the rest of its path and without its disambiguation.
            output.append(code(contents: [.text(linkProvider.fallbackLinkText(linkString: symbolLink.destination ?? ""))]))
            return
        }
        
        let content: [HTMLNode] = switch linkedElement.names {
            case .single(.conceptual(let name)): [ .text(name) ]
            case .single(.symbol(let name)):     [ code(contents: wordBreak(symbolName: name)) ]
                
            case .languageSpecificSymbol(let namesByLanguageID):
                RenderHelpers.sortedLanguageSpecificValues(namesByLanguageID).map { language, name in
                    code(attributes: [language.filterAttribute], contents: wordBreak(symbolName: name))
                }
        }
        
        output.append(anchor(linkingTo: linkedElement, contents: content))
    }
    
    package func path(to other: String) -> String {
        let fromComponents = pathComponents
        let toComponents   = other.components(separatedBy: "/")
        
        guard fromComponents != toComponents else { return "." }

        let commonPrefixLength = Array(zip(fromComponents, toComponents).prefix { lhs, rhs in lhs == rhs }).count

        let relativeComponents = repeatElement("..", count: fromComponents.count - commonPrefixLength - 1 /* the "index.html" component doesn't count in a web server */)
            + toComponents.dropFirst(commonPrefixLength)
       
        return relativeComponents.joined(separator: "/")
    }
    
    /// Transforms a markdown image into a`<picture>` HTML element that wraps an `<img>` element and zero or more `<source>` elements.
    ///
    /// The renderer uses its configured ``LinkProvider`` to find information about the referenced asset.
    /// For example, if the link provider returns an asset with both light and dark image representations from the ``LinkProvider/assetNamed(_:)`` call, the renderer transforms this markdown
    /// ```md
    /// ![Some alt text](some-image.png)
    /// ```
    /// into nodes representing this HTML structure
    /// ```
    /// <picture>
    ///   <source media="(prefers-color-scheme: light)" srcset="relative/path/to/some-image.png"/>
    ///   <source media="(prefers-color-scheme: dark)" srcset="relative/path/some-image~dark.png"/>
    ///   <img alt="Some alt text" decoding="async" loading="lazy"/>
    /// </picture>
    /// ```
    func visitImage(_ image: Image, into output: inout [HTMLNode]) {
        guard let source = image.source else {
            // ???: Is there anything we want to display for images without a source?
            return
        }
        if let picture = makePicture(from: source, altText: image.altText) {
            output.append(picture)
        }
    }
    
    private func makePicture(from imageSource: String, altText: String?) -> HTMLNode? {
        var imgAttributes: [HTMLNode.Attribute] = [
            .decoding(.async),
            .loading(.lazy),
        ]
        
        if let altText {
            imgAttributes.insert(.alt(altText), at: 0)
        }
        
        if imageSource.isAbsoluteWebURL {
            imgAttributes.append(.src(imageSource))
            return picture(contents: [img(attributes: imgAttributes)])
        }
        
        guard let asset = linkProvider.assetNamed(imageSource), !asset.files.isEmpty else {
            return nil // ???: Is there anything we want to display for images without a source?
        }
        
        func srcAttributes(for images: [Int: String]) -> [HTMLNode.Attribute] {
            switch images.count {
                case 0: []
                case 1: [.srcSet([path(to: images.first!.value)])] // No need to specify a scale factor when there's only one source.
                default: [.srcSet(images.sorted(by: { $0.key > $1.key }) // Order by large scale factors first
                    .map { scale, imagePath in "\(path(to: imagePath)) \(scale)x" }
                )]
            }
        }
        
        var content = [HTMLNode]()
        if asset.files.count == 1 {
            // When all image are either dark/light mode, add them directly on the "img" element
            let scaleVariants = asset.files.first!.value
            if scaleVariants.count == 1 {
                // Prefer a "src" attribute over a "srcSet" attribute for the "img" element itself.
                imgAttributes.append(.src(path(to: scaleVariants.first!.value)))
            } else {
                imgAttributes.append(contentsOf: srcAttributes(for: scaleVariants))
            }
        } else {
            // Define a "source" element for each dark/light style
            for (style, images) in asset.files.sorted(by: { $0.key.rawValue > $1.key.rawValue }) { // Order light images before dark images
                var attributes = srcAttributes(for: images)
                attributes.insert(.media("(prefers-color-scheme: \(style.rawValue))"), at: 0)
                content.append(source(attributes: attributes))
            }
        }
        
        content.append(img(attributes: imgAttributes))
        
        return picture(contents: content)
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
    /// into nodes representing this HTML structure
    /// ```
    /// <pre class="lang">
    ///   <code>Some block of code</code>
    /// </pre>
    /// ```
    func visitCodeBlock(_ codeBlock: CodeBlock, into output: inout [HTMLNode]) {
        output.append(pre(
            attributes: codeBlock.language.map { [.class($0)] } ?? [],
            contents: [code(contents: [.text(codeBlock.code)])]
        ))
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
    /// into nodes representing this HTML structure
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
    func visitUnorderedList(_ unorderedList: UnorderedList, into output: inout [HTMLNode]) {
        output.append(ul(contents: _visit(unorderedList.children)))
    }
    
    /// Transforms a markdown ordered list into a`<ul>` HTML element.
    ///
    /// As part of transforming the ordered list, the renderer also transforms all of its list items and their content recursively.
    /// For example, the renderer transforms this markdown
    /// ```md
    /// 1. One
    /// 2. Two
    /// ```
    /// into nodes representing this HTML structure
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
    func visitOrderedList(_ orderedList: OrderedList, into output: inout [HTMLNode]) {
        output.append(ol(contents: _visit(orderedList.children)))
    }
    
    /// Transforms a markdown list item into a`<li>` HTML element.
    ///
    /// See ``visit(_:)-(UnorderedList)`` or ``visit(_:)-(OrderedList)`` for examples.
    func visitListItem(_ listItem: ListItem, into output: inout [HTMLNode]) {
        output.append(li(contents: _visit(listItem.children)))
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
    /// into nodes representing this HTML structure
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
    func visitTable(_ table: Table, into output: inout [HTMLNode]) {
        var content: [HTMLNode] = []
                
        if !table.head.isEmpty {
            var column = 0
            
            content.append(
                thead(contents: [
                    tr(contents: table.head.cells.compactMap { (cell) -> HTMLNode? in
                        defer { column += 1 }
                        
                        if cell.colspan == 0 || cell.rowspan == 0 {
                            return nil
                        }
                        
                        var attributes: [HTMLNode.Attribute] = []
                        if cell.colspan != 1 {
                            attributes.append(.colSpan(cell.colspan))
                        }
                        if cell.rowspan != 1 {
                            attributes.append(.rowSpan(cell.rowspan))
                        }
                        
                        if let alignment = table.columnAlignments[column] {
                            let className = switch alignment {
                                case .left:   "left"
                                case .center: "center"
                                case .right:  "right"
                            }
                            attributes.append(.class(className))
                        }
                        
                        return th(attributes: attributes, contents: _visit(cell.children))
                    })
                ])
            )
        }
        
        if !table.body.isEmpty {
            content.append(
                tbody(contents: table.body.rows.map { row in
                    var column = 0
                    return tr(contents: row.cells.compactMap { (cell) -> HTMLNode? in
                        defer { column += 1 }
                        
                        if cell.colspan == 0 || cell.rowspan == 0 {
                            return nil
                        }
                        
                        var attributes: [HTMLNode.Attribute] = []
                        if cell.colspan != 1 {
                            attributes.append(.colSpan(cell.colspan))
                        }
                        if cell.rowspan != 1 {
                            attributes.append(.rowSpan(cell.rowspan))
                        }
                        
                        if let alignment = table.columnAlignments[column] {
                            let className = switch alignment {
                                case .left:   "left"
                                case .center: "center"
                                case .right:  "right"
                            }
                            attributes.append(.class(className))
                        }
                        
                        return td(attributes: attributes, contents: _visit(cell.children))
                    })
                })
            )
        }
        
        output.append(DocCHTML.table(contents: content))
    }
    
    // MARK: Markup children
    
    func _visit(_ container: some Sequence<any Markup>) -> [HTMLNode] {
        var output: [HTMLNode] = []
        output.reserveCapacity(container.underestimatedCount)
        
        // Check if the markup contains _any_ inline HTML. If it doesn't, then we can simply visit each child.
        guard container.contains(where: { $0 is InlineHTML }) else {
            for element in container {
                visit(element, into: &output)
            }
            return output
        }
        
        // The markup contains at least _some_ inline HTML. This could be either:
        // - A comment like `<!-- comment -->` that we'd want to exclude from the output.
        // - A void element like `<br>` or `<hr>` that's complete on its own.
        // - An element with children like `<span style="color: red;">Something</span>` that needs to be created out of multiple markup elements.
        //
        // Because it may take multiple markdown elements to create an HTML element, we pop elements rather than iterating
        var remainder = Array(container)[...]
        while let element = remainder.popFirst() {
            guard let openingHTML = element as? InlineHTML else {
                // If the markup _isn't_ inline HTML we can simply visit it to transform it.
                visit(element, into: &output)
                continue
            }
            
            // Otherwise, we need to determine how long this markdown element is.
            let rawHTML = openingHTML.rawHTML
            // Simply skip any HTML/XML comments.
            guard !rawHTML.hasPrefix("<!--") else {
                continue
            }
            
            // Next, check if its empty element (for example `<br>` or `<hr>`) that's complete on its own.
            
            
            // On non-Darwin platforms, `XMLElement(xmlString:)` sometimes crashes for certain invalid / incomplete XML strings.
            // To minimize the risk of this happening, don't try to parse the XML string as an empty HTML element unless it ends with "/>"
            if rawHTML.hasSuffix("/>"), let parsed = try? XMLElement(xmlString: rawHTML) {
                output.append(HTMLNode(from: parsed) ?? .text(""))
            }
            // Lastly, check if this is the start of an HTML element that needs to be constructed out of more than one markup element
            else if let parsed = _findMultiMarkupHTMLElement(in: &remainder, openingRawHTML: rawHTML) {
                output.append(parsed)
            }
        }
        
        return output
    }
    
    private func _findMultiMarkupHTMLElement(in remainder: inout ArraySlice<any Markup>, openingRawHTML: String) -> HTMLNode? {
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
                return HTMLNode(from: parsed) ?? .text("") // Include the valid HTML element in the output.
            }
        }
        // If we reached the end of the _inline_ markup without parsing a valid HTML element, skip just that opening markup without updating `remainder`
        return nil
    }
    
    // MARK: Directives
    
    func visitBlockDirective(_ directive: BlockDirective, into output: inout [HTMLNode]) {
        let parsed = self.renderableDirectiveParser.parse(blockDirective: directive)
        
        switch parsed {
        case .small:
            //<small> is phrasing content and should be wrapped by <p>,
            // per the HTML spec - not the other way around
            var smallContents = [HTMLNode]()
            for child in directive.children {
                if let paragraph = child as? Paragraph {
                    for markup in paragraph.children {
                        visit(markup, into: &smallContents)
                    }
                } else {
                    visit(child, into: &smallContents)
                }
            }
            output.append(p(contents: [small(contents: smallContents)]))
        case .image(let source, let alt, let caption):
            guard let picture = makePicture(from: source, altText: alt) else {
                return // Don't add anything
            }
            
            let element = if caption.isEmpty {
                picture
            }
            else if caption.count == 1,
                    let paragraph = caption.first as? Paragraph,
                    paragraph.isEmpty
            {
                picture
            }
            else {
                figure(contents: [
                    picture,
                    figcaption(contents: _visit(caption))
                ])
            }
            output.append(element)
        case .row(let columns):
            output.append(div(attributes: [.class("row")], contents: columns.map { column in
                let alignment = switch column.alignment {
                case .leading:  "start"
                case .center:   "center"
                case .trailing: "end"
                }
                let attributes: [HTMLNode.Attribute] = [
                    .cssCustomProperties(["column-size": String(column.size), "alignment": alignment])
                ]
                return div(
                    attributes: attributes,
                    contents: _visit(column.content)
                )
            }))
        case .tabNavigator(tabs: let tabs):
            // `<details>` elements with the same `name` form an exclusive group, so each navigator on the page needs its own
            let groupName = directive.range.map { range in
                "tabnavigator-\(range.lowerBound.line)"
            } ?? "tabnavigator"
            output.append(div(
                attributes: [
                    .class("tabnavigator"),
                    .cssCustomProperties(["count": String(tabs.count)]),
                ],
                contents: tabs.enumerated().map { i, tab in
                    details(
                        attributes: [
                            .name(groupName),
                            .cssCustomProperties(["index": String(i + 1)]),
                        ] + (i == 0 ? ([.open]) : ([])),
                        contents: [
                            summary(contents: [.text(tab.title)]),
                        ] + _visit(tab.content)
                    )
                }
            ))
        case .none:
            // If the directive cannot be parsed into a known RenderableDirective, nothing should be rendered.
            return // Don't add anything to the output
        }
    }
    
    // TODO: Support rendering Doxygen tags. (rdar://165755750)
    // It would be nice if DocC processed in the model, so that all renderers could have just one code path for parameters, returns, etc.
    
    func visitDoxygenNote(_: DoxygenNote, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    func visitDoxygenReturns(_: DoxygenReturns, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    func visitDoxygenAbstract(_: DoxygenAbstract, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    func visitDoxygenParameter(_: DoxygenParameter, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    func visitDoxygenDiscussion(_: DoxygenDiscussion, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    private func visitCustomBlock(_: CustomBlock, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    private func visitDocument(_: Document, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    private func visitCustomInline(_: CustomInline, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    private func visitInlineAttributes(_: InlineAttributes, into output: inout [HTMLNode]) {
        // Don't add anything to the output
    }
    
    // MARK: Default
    
    @_disfavoredOverload
    package func visit(_ markup: some Markup, into output: inout [HTMLNode]) {
        // Check common markup types first
        if let paragraph = markup as? Paragraph {
            return visitParagraph(paragraph, into: &output)
        } else if let text = markup as? Text {
            return visitText(text, into: &output)
        } else if let strong = markup as? Strong {
            return visitStrong(strong, into: &output)
        } else if let emphasis = markup as? Emphasis {
            return visitEmphasis(emphasis, into: &output)
        } else if let symbolLink = markup as? SymbolLink {
            return visitSymbolLink(symbolLink, into: &output)
        } else if let link = markup as? Link {
            return visitLink(link, into: &output)
        } else if let inlineCode = markup as? InlineCode {
            return visitInlineCode(inlineCode, into: &output)
        } else if let image = markup as? Image {
            return visitImage(image, into: &output)
        } else if let listItem = markup as? ListItem {
            return visitListItem(listItem, into: &output)
        } else if let heading = markup as? Heading {
            return visitHeading(heading, into: &output)
        } else if let orderedList = markup as? OrderedList {
            return visitOrderedList(orderedList, into: &output)
        } else if let unorderedList = markup as? UnorderedList {
            return visitUnorderedList(unorderedList, into: &output)
        } else if let codeBlock = markup as? CodeBlock {
            return visitCodeBlock(codeBlock, into: &output)
        } else if let blockQuote = markup as? BlockQuote {
            return visitBlockQuote(blockQuote, into: &output)
        } else if let table = markup as? Table {
            return visitTable(table, into: &output)
        } else if let lineBreak = markup as? LineBreak {
            return visitLineBreak(lineBreak, into: &output)
        } else if let softBreak = markup as? SoftBreak {
            return visitSoftBreak(softBreak, into: &output)
        } else if let thematicBreak = markup as? ThematicBreak {
            return visitThematicBreak(thematicBreak, into: &output)
        } else if let blockDirective = markup as? BlockDirective {
            return visitBlockDirective(blockDirective, into: &output)
        } else if let inlineHTML = markup as? InlineHTML {
            return visitInlineHTML(inlineHTML, into: &output)
        } else if let html = markup as? HTMLBlock {
            return visitHTMLBlock(html, into: &output)
        } else if let strikethrough = markup as? Strikethrough {
            return visitStrikethrough(strikethrough, into: &output)
        } else if let customBlock = markup as? CustomBlock {
            return visitCustomBlock(customBlock, into: &output)
        } else if let document = markup as? Document {
            return visitDocument(document, into: &output)
        } else if let customInline = markup as? CustomInline {
            return visitCustomInline(customInline, into: &output)
        } else if let attributes = markup as? InlineAttributes {
            return visitInlineAttributes(attributes, into: &output)
        } else if let doxygenDiscussion = markup as? DoxygenDiscussion {
            return visitDoxygenDiscussion(doxygenDiscussion, into: &output)
        } else if let doxygenNote = markup as? DoxygenNote {
            return visitDoxygenNote(doxygenNote, into: &output)
        } else if let doxygenAbstract = markup as? DoxygenAbstract {
            return visitDoxygenAbstract(doxygenAbstract, into: &output)
        } else if let doxygenParam = markup as? DoxygenParameter {
            return visitDoxygenParameter(doxygenParam, into: &output)
        } else if let doxygenReturns = markup as? DoxygenReturns {
            return visitDoxygenReturns(doxygenReturns, into: &output)
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

extension MarkdownRenderer {
    /// Creates an `<a>` element with a relative link to the given element.
    func anchor(linkingTo element: LinkedElement, contents: [HTMLNode]) -> HTMLNode {
        a(attributes: [.href(path(to: element.path))], contents: contents)
    }
}

private extension String {
    var isAbsoluteWebURL: Bool {
        let maybeScheme = prefix(8 /* "http://" + 1 character */).lowercased()
        
        return maybeScheme.hasPrefix("http://")
            || maybeScheme.hasPrefix("https://")
    }
}
