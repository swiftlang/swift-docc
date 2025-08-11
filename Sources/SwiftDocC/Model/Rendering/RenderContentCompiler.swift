/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
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
    
    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> [any RenderContent] {
        let aside = Aside(blockQuote)
        
        let newAside = RenderBlockContent.Aside(
            style: RenderBlockContent.AsideStyle(asideKind: aside.kind),
            content: aside.content.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderBlockContent]
        )
            
        return [RenderBlockContent.aside(newAside.capitalizingFirstWord())]
    }
    
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> [any RenderContent] {
        // Default to the bundle's code listing syntax if one is not explicitly declared in the code block.
        struct ParsedOptions {
            var lang: String?
            var nocopy = false
        }

        func parseLanguageString(_ input: String?) -> ParsedOptions {
            guard let input else { return ParsedOptions() }

            let parts = input
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }

            var options = ParsedOptions()

            for part in parts {
                let lower = part.lowercased()
                if lower == "nocopy" {
                    options.nocopy = true
                } else if options.lang == nil {
                    options.lang = part
                }
            }
            return options
        }

        let options = parseLanguageString(codeBlock.language)

        return [RenderBlockContent.codeListing(.init(syntax: options.lang ?? bundle.info.defaultCodeListingLanguage, code: codeBlock.code.splitByNewlines, metadata: nil, copyToClipboard: !options.nocopy))]
    }
    
    mutating func visitHeading(_ heading: Heading) -> [any RenderContent] {
        return [RenderBlockContent.heading(.init(level: heading.level, text: heading.plainText, anchor: urlReadableFragment(heading.plainText).addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)))]
    }
    
    mutating func visitListItem(_ listItem: ListItem) -> [any RenderContent] {
        let renderListItems = listItem.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))})
        let checked: Bool?
        switch listItem.checkbox {
            case .checked: checked = true
            case .unchecked: checked = false
            case nil: checked = nil
        }
        return [RenderBlockContent.ListItem(content: renderListItems as! [RenderBlockContent], checked: checked)]
    }
    
    mutating func visitOrderedList(_ orderedList: OrderedList) -> [any RenderContent] {
        let renderListItems = orderedList.listItems.reduce(into: [], { result, item in result.append(contentsOf: visitListItem(item))})
        return [RenderBlockContent.orderedList(.init(
            items: renderListItems as! [RenderBlockContent.ListItem],
            startIndex: orderedList.startIndex
        ))]
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> [any RenderContent] {
        let renderListItems = unorderedList.listItems.reduce(into: [], { result, item in result.append(contentsOf: visitListItem(item))}) as! [RenderBlockContent.ListItem]
        return renderListItems.unorderedAndTermLists()
    }
    
    mutating func visitParagraph(_ paragraph: Paragraph) -> [any RenderContent] {
        return [RenderBlockContent.paragraph(.init(inlineContent: paragraph.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent]))]
    }
    
    mutating func visitInlineCode(_ inlineCode: InlineCode) -> [any RenderContent] {
        return [RenderInlineContent.codeVoice(code: inlineCode.code)]
    }
    
    mutating func visitImage(_ image: Image) -> [any RenderContent] {
        return visitImage(
            source: image.source ?? "",
            altText: image.altText,
            caption: nil,
            deviceFrame: nil
        )
    }
    
    mutating func visitImage(
        source: String,
        altText: String?,
        caption: [RenderInlineContent]?,
        deviceFrame: String?
    ) -> [any RenderContent] {
        guard let imageIdentifier = resolveImage(source: source, altText: altText) else {
            return []
        }
        
        var metadata: RenderContentMetadata?
        if caption != nil || deviceFrame != nil {
            metadata = RenderContentMetadata(abstract: caption, deviceFrame: deviceFrame)
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
    
    mutating func visitLink(_ link: Link) -> [any RenderContent] {
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
        
        let linkTitleInlineContent = link.children.flatMap { visit($0) } as! [RenderInlineContent]
        let plainTextLinkTitle = linkTitleInlineContent.plainText
        let overridingTitle = plainTextLinkTitle.isEmpty ? nil : plainTextLinkTitle
        let overridingTitleInlineContent = linkTitleInlineContent.isEmpty ? nil : linkTitleInlineContent
        
        let useOverriding: Bool
        if link.isAutolink { // If the link is an auto link, we don't use overriding info
            useOverriding = false
        } else if let overridingTitle,
                  overridingTitle.hasPrefix(ResolvedTopicReference.urlScheme + ":"),
                  destination.hasPrefix(ResolvedTopicReference.urlScheme + "://")
        {
            // The overriding title looks like a documentation link. Escape it like a resolved reference string to compare it with the destination.
            let withoutScheme = overridingTitle.dropFirst((ResolvedTopicReference.urlScheme + ":").count)
            if destination.hasSuffix(withoutScheme) {
                useOverriding = false
            } else {
                let escapedTitle: String
                if let fragmentIndex = withoutScheme.firstIndex(of: "#") {
                    let escapedFragment = withoutScheme[fragmentIndex...].dropFirst().addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? ""
                    escapedTitle = "\(urlReadablePath(withoutScheme[..<fragmentIndex]))#\(escapedFragment)"
                } else {
                    escapedTitle = urlReadablePath(withoutScheme)
                }
                
                useOverriding = !destination.hasSuffix(escapedTitle) // If the link is a transformed doc link, we don't use overriding info
            }
        } else {
            useOverriding = true
        }
        return [
            RenderInlineContent.reference(
                identifier: .init(resolved.absoluteString),
                isActive: true,
                overridingTitle: useOverriding ? overridingTitle : nil,
                overridingTitleInlineContent: useOverriding ? overridingTitleInlineContent : nil
            )
        ]
    }
    
    mutating func resolveTopicReference(_ destination: String) -> ResolvedTopicReference? {
        if let cached = context.referenceIndex[destination] {
            if let node = context.topicGraph.nodeWithReference(cached), !context.topicGraph.isLinkable(node.reference) {
                return nil
            }
            collectedTopicReferences.append(cached)
            return cached
        }
        
        // FIXME: Links from this build already exist in the reference index and don't need to be resolved again.
        // https://github.com/swiftlang/swift-docc/issues/581

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
        if let cached = context.referenceIndex[destination] {
            return cached
        }

        // The symbol link may be written with a scheme and bundle identifier.
        let url = ValidatedURL(parsingExact: destination)?.requiring(scheme: ResolvedTopicReference.urlScheme) ?? ValidatedURL(symbolPath: destination)
        if case let .success(resolved) = context.resolve(.unresolved(.init(topicURL: url)), in: identifier, fromSymbolLink: true) {
            return resolved
        }

        return nil
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> [any RenderContent] {
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
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> [any RenderContent] {
        return [RenderInlineContent.text(" ")]
    }
    
    mutating func visitLineBreak(_ lineBreak: LineBreak) -> [any RenderContent] {
        return [RenderInlineContent.text("\n")]
    }
    
    mutating func visitEmphasis(_ emphasis: Emphasis) -> [any RenderContent] {
        return [RenderInlineContent.emphasis(inlineContent: emphasis.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }
    
    mutating func visitStrong(_ strong: Strong) -> [any RenderContent] {
        return [RenderInlineContent.strong(inlineContent: strong.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }
    
    mutating func visitText(_ text: Text) -> [any RenderContent] {
        return [RenderInlineContent.text(text.string)]
    }
    
    mutating func visitTable(_ table: Table) -> [any RenderContent] {
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

        var tempAlignments = [RenderBlockContent.ColumnAlignment]()
        for alignment in table.columnAlignments {
            switch alignment {
            case .left: tempAlignments.append(.left)
            case .right: tempAlignments.append(.right)
            case .center: tempAlignments.append(.center)
            case nil: tempAlignments.append(.unset)
            }
        }
        while tempAlignments.count < table.maxColumnCount {
            tempAlignments.append(.unset)
        }
        if tempAlignments.allSatisfy({ $0 == .unset }) {
            tempAlignments = []
        }
        let alignments: [RenderBlockContent.ColumnAlignment]?
        if tempAlignments.isEmpty {
            alignments = nil
        } else {
            alignments = tempAlignments
        }
        
        return [RenderBlockContent.table(.init(header: .row, rawAlignments: alignments, rows: [RenderBlockContent.TableRow(cells: headerCells)] + rows, extendedData: extendedData, metadata: nil))]
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> [any RenderContent] {
        return [RenderInlineContent.strikethrough(inlineContent: strikethrough.children.reduce(into: [], { result, child in result.append(contentsOf: visit(child))}) as! [RenderInlineContent])]
    }

    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> [any RenderContent] {

        guard let renderableDirective = DirectiveIndex.shared.renderableDirectives[blockDirective.name] else {
            return []
        }
            
        return renderableDirective.render(blockDirective, with: &self)
    }

    mutating func visitDoxygenAbstract(_ doxygenAbstract: DoxygenAbstract) -> [any RenderContent] {
        doxygenAbstract.children.flatMap { self.visit($0)}
    }

    mutating func visitDoxygenDiscussion(_ doxygenDiscussion: DoxygenDiscussion) -> [any RenderContent] {
        doxygenDiscussion.children.flatMap { self.visit($0) }
    }

    mutating func visitDoxygenNote(_ doxygenNote: DoxygenNote) -> [any RenderContent] {
        let content: [RenderBlockContent] = doxygenNote.children
            .flatMap { self.visit($0) }
            .map {
                switch $0 {
                case let inlineContent as RenderInlineContent:
                    return .paragraph(.init(inlineContent: [inlineContent]))
                case let blockContent as RenderBlockContent:
                    return blockContent
                default:
                    fatalError("Unexpected content type in note: \(type(of: $0))")
                }
            }
        return [RenderBlockContent.aside(.init(
            style: .init(asideKind: .note),
            content: content
        ))]
    }
    
    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> [any RenderContent] {
        return [RenderBlockContent.thematicBreak]
    }

    func defaultVisit(_ markup: any Markup) -> [any RenderContent] {
        return []
    }
}
