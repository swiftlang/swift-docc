/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import SymbolKit

protocol RenderContent {}
extension RenderBlockContent: RenderContent {}
extension RenderBlockContent.ListItem: RenderContent {}
extension RenderBlockContent.TermListItem: RenderContent {}
extension RenderInlineContent: RenderContent {}

struct RenderContentCompiler: MarkupVisitor {
    var context: DocumentationContext
    var bundle: DocumentationBundle
    var identifier: ResolvedTopicReference
    var imageReferences: [String: ImageReference] = [:]
    var videoReferences: [String: VideoReference] = [:]
    /// Resolved topic references that were seen by the visitor. These should be used to populate the references dictionary.
    var collectedTopicReferences = GroupedSequence<String, ResolvedTopicReference> { $0.absoluteString }
    var linkReferences: [String: LinkReference] = [:]
    
    init(context: DocumentationContext, bundle: DocumentationBundle, identifier: ResolvedTopicReference) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
    }
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> [RenderContent] {
        let aside = Aside(blockQuote)
        return [RenderBlockContent.aside(.init(style: RenderBlockContent.AsideStyle(asideKind: aside.kind),
                                               content: aside.content.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderBlockContent]))]
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> [RenderContent] {
        // Default to the bundle's code listing syntax if one is not explicitly declared in the code block.
        return [RenderBlockContent.codeListing(.init(syntax: codeBlock.language ?? bundle.info.defaultCodeListingLanguage, code: codeBlock.code.splitByNewlines, metadata: nil))]
    }
    
    mutating func visitHeading(_ heading: Heading) -> [RenderContent] {
        return [RenderBlockContent.heading(.init(level: heading.level, text: heading.plainText, anchor: urlReadableFragment(heading.plainText)))]
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> [RenderContent] {
        let renderListItems = listItem.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))})
        let checked: Bool?
        switch listItem.checkbox {
            case .checked: checked = true
            case .unchecked: checked = false
            case nil: checked = nil
        }
        return [RenderBlockContent.ListItem(content: renderListItems as! [RenderBlockContent], checked: checked)]
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> [RenderContent] {
        let renderListItems = orderedList.listItems.reduce(into: [], { result, item in result.append(contentsOf: visitListItem(item))})
        return [RenderBlockContent.orderedList(.init(items: renderListItems as! [RenderBlockContent.ListItem]))]
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> [RenderContent] {
        let renderListItems = unorderedList.listItems.reduce(into: [], { result, item in result.append(contentsOf: visitListItem(item))}) as! [RenderBlockContent.ListItem]
        return renderListItems.unorderedAndTermLists()
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> [RenderContent] {
        return [RenderBlockContent.paragraph(.init(inlineContent: paragraph.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent]))]
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> [RenderContent] {
        return [RenderInlineContent.codeVoice(code: inlineCode.code)]
    }
    
    mutating func visitImage(_ image: Image) -> [RenderContent] {
        return visitImage(
            source: image.source ?? "",
            altText: image.altText,
            caption: nil
        )
    }
    
    mutating func visitImage(
        source: String,
        altText: String?,
        caption: [RenderInlineContent]?
    ) -> [RenderContent] {
        guard let imageIdentifier = resolveImage(source: source, altText: altText) else {
            return []
        }
        
        var metadata: RenderContentMetadata?
        if let caption = caption {
            metadata = RenderContentMetadata(abstract: caption)
        }
        
        return [RenderInlineContent.image(identifier: imageIdentifier, metadata: metadata)]
    }
    
    mutating func resolveImage(source: String, altText: String? = nil) -> RenderReferenceIdentifier? {
        let unescapedSource = source.removingPercentEncoding ?? source
        let imageIdentifier: RenderReferenceIdentifier = .init(unescapedSource)
        guard let resolvedImages = context.resolveAsset(
            named: unescapedSource,
            in: identifier,
            withType: .image
        ) else {
            return nil
        }
        
        imageReferences[unescapedSource] = ImageReference(
            identifier: imageIdentifier,
            altText: altText,
            imageAsset: resolvedImages
        )
        
        return imageIdentifier
    }
    
    mutating func visitLink(_ link: Link) -> [RenderContent] {
        let destination = link.destination ?? ""
        // Before attempting to resolve the link, we confirm that is has a ResolvedTopicReference urlScheme
        guard ResolvedTopicReference.urlHasResolvedTopicScheme(URL(string: destination)) else {
            // This is an external URL which needs a ``LinkRenderReference``.
            let linkTitleInlineContent = link.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent]
            let plainTextLinkTitle = linkTitleInlineContent.plainText
            
            // Generate a unique identifier and allow for the same link to be used
            // with different titles on the same page if needed.
            let externalLinkIdentifier = RenderReferenceIdentifier(forExternalLink: destination)
            
            if linkReferences.keys.contains(externalLinkIdentifier.identifier) {
                // If we've already seen this link, return the existing reference with an overridden title.
                return [RenderInlineContent.reference(identifier: externalLinkIdentifier,
                                                     isActive: true,
                                                     overridingTitle: plainTextLinkTitle.isEmpty ? nil : plainTextLinkTitle,
                                                     overridingTitleInlineContent: linkTitleInlineContent.isEmpty ? nil : linkTitleInlineContent)]
            } else {
                // Otherwise, create and save a new link reference.
                let linkReference = LinkReference(identifier: externalLinkIdentifier,
                                                  title: plainTextLinkTitle.isEmpty ? destination : plainTextLinkTitle,
                                                  titleInlineContent: linkTitleInlineContent.isEmpty ? [.text(destination)] : linkTitleInlineContent,
                                                  url: destination)
                
                linkReferences[externalLinkIdentifier.identifier] = linkReference
                
                return [RenderInlineContent.reference(identifier: externalLinkIdentifier, isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)]
            }
        }
        
        guard let destination = link.destination, let resolved = resolveTopicReference(destination) else {
            // As this was a doc: URL, we render the link inactive by converting it to plain text,
            // as it may break routing or other downstream uses of the URL.
            return [RenderInlineContent.text(link.plainText)]
        }
        
        return [RenderInlineContent.reference(identifier: .init(resolved.absoluteString), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)]
    }
    
    mutating func resolveTopicReference(_ destination: String) -> ResolvedTopicReference? {
        guard let validatedURL = ValidatedURL(parsingAuthoredLink: destination) else {
            return nil
        }
        
        let unresolved = UnresolvedTopicReference(topicURL: validatedURL)
        
        // Try to resolve in the local context
        guard case let .success(resolved) = context.resolve(.unresolved(unresolved), in: identifier) else {
            return nil
        }
        
        // We resolved the reference, check if it's a node that can be linked to.
        if let node = context.topicGraph.nodeWithReference(resolved) {
            guard context.topicGraph.isLinkable(node.reference) else {
                return nil
            }
        }
        
        collectedTopicReferences.append(resolved)
        return resolved
    }

    func resolveSymbolReference(destination: String) -> ResolvedTopicReference? {
        if let cached = context.documentationCacheBasedLinkResolver.referenceFor(absoluteSymbolPath: destination, parent: identifier) {
            return cached
        } 

        // The symbol link may be written with a scheme and bundle identifier.
        let url = ValidatedURL(parsingExact: destination)?.requiring(scheme: ResolvedTopicReference.urlScheme) ?? ValidatedURL(symbolPath: destination)
        if case let .success(resolved) = context.resolve(.unresolved(.init(topicURL: url)), in: identifier, fromSymbolLink: true) {
            return resolved
        }

        return nil
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> [RenderContent] {
        guard let destination = symbolLink.destination else {
            return []
        }
        guard let resolved = resolveSymbolReference(destination: destination) else {
            return [RenderInlineContent.codeVoice(code: destination)]
        }
        if let node = context.topicGraph.nodeWithReference(resolved) {
            guard context.topicGraph.isLinkable(node.reference) else {
                return [RenderInlineContent.codeVoice(code: destination)]
            }
        }
        collectedTopicReferences.append(resolved)

        return [RenderInlineContent.reference(identifier: .init(resolved.absoluteString), isActive: true, overridingTitle: nil, overridingTitleInlineContent: nil)]
    }
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> [RenderContent] {
        return [RenderInlineContent.text(" ")]
    }
    
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> [RenderContent] {
        return [RenderInlineContent.text(" ")]
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> [RenderContent] {
        return [RenderInlineContent.emphasis(inlineContent: emphasis.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }
    
    mutating func visitStrong(_ strong: Strong) -> [RenderContent] {
        return [RenderInlineContent.strong(inlineContent: strong.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }
    
    mutating func visitText(_ text: Text) -> [RenderContent] {
        return [RenderInlineContent.text(text.string)]
    }
    
    mutating func visitTable(_ table: Table) -> [RenderContent] {
        var extendedData = Set<RenderBlockContent.TableCellExtendedData>()

        var headerCells = [RenderBlockContent.TableRow.Cell]()
        for cell in table.head.cells {
            let cellContent = cell.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))})
            headerCells.append([RenderBlockContent.paragraph(.init(inlineContent: cellContent as! [RenderInlineContent]))])
            if cell.colspan != 1 || cell.rowspan != 1 {
                extendedData.insert(.init(rowIndex: 0, columnIndex: cell.indexInParent, colspan: cell.colspan, rowspan: cell.rowspan))
            }
        }
        
        var rows = [RenderBlockContent.TableRow]()
        for row in table.body.rows {
            let rowIndex = row.indexInParent + 1
            var cells = [RenderBlockContent.TableRow.Cell]()
            for cell in row.cells {
                let cellContent = cell.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))})
                cells.append([RenderBlockContent.paragraph(.init(inlineContent: cellContent as! [RenderInlineContent]))])
                if cell.colspan != 1 || cell.rowspan != 1 {
                    extendedData.insert(.init(rowIndex: rowIndex, columnIndex: cell.indexInParent, colspan: cell.colspan, rowspan: cell.rowspan))
                }
            }
            rows.append(RenderBlockContent.TableRow(cells: cells))
        }
        
        return [RenderBlockContent.table(.init(header: .row, rows: [RenderBlockContent.TableRow(cells: headerCells)] + rows, extendedData: extendedData, metadata: nil))]
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> [RenderContent] {
        return [RenderInlineContent.strikethrough(inlineContent: strikethrough.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> [RenderContent] {
        switch blockDirective.name {
        case Snippet.directiveName:
            guard let snippet = Snippet(from: blockDirective, for: bundle, in: context) else {
                return []
            }
            
            guard let snippetReference = resolveSymbolReference(destination: snippet.path),
                  let snippetEntity = try? context.entity(with: snippetReference),
                  let snippetSymbol = snippetEntity.symbol,
                  let snippetMixin = snippetSymbol.mixins[SymbolGraph.Symbol.Snippet.mixinKey] as? SymbolGraph.Symbol.Snippet else {
                return []
            }
            
            if let requestedSlice = snippet.slice,
               let requestedLineRange = snippetMixin.slices[requestedSlice] {
                // Render only the slice.
                let lineRange = requestedLineRange.lowerBound..<min(requestedLineRange.upperBound, snippetMixin.lines.count)
                let lines = snippetMixin.lines[lineRange]
                let minimumIndentation = lines.map { $0.prefix { $0.isWhitespace }.count }.min() ?? 0
                let trimmedLines = lines.map { String($0.dropFirst(minimumIndentation)) }
                return [RenderBlockContent.codeListing(.init(syntax: snippetMixin.language, code: trimmedLines, metadata: nil))]
            } else {
                // Render the whole snippet with its explanation content.
                let docCommentContent = snippetEntity.markup.children.flatMap { self.visit($0) }
                let code = RenderBlockContent.codeListing(.init(syntax: snippetMixin.language, code: snippetMixin.lines, metadata: nil))
                return docCommentContent + [code]
            }
        default:
            guard let renderableDirective = DirectiveIndex.shared.renderableDirectives[blockDirective.name] else {
                return []
            }
            
            return renderableDirective.render(blockDirective, with: &self)
        }
    }

    func defaultVisit(_ markup: Markup) -> [RenderContent] {
        return []
    }
}
