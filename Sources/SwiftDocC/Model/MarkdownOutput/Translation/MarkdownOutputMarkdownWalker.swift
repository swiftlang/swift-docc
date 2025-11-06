/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown
@_spi(MarkdownOutput) import SwiftDocCMarkdownOutput

/// Performs any markup processing necessary to build the final output markdown
internal struct MarkdownOutputMarkupWalker: MarkupWalker {
    let context: DocumentationContext
    let bundle: DocumentationBundle
    let identifier: ResolvedTopicReference
    
    init(context: DocumentationContext, bundle: DocumentationBundle, identifier: ResolvedTopicReference) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
    }
    
    var markdown = ""
    var outgoingReferences: Set<MarkdownOutputManifest.Relationship> = []
     
    private(set) var indentationToRemove: String?
    private(set) var isRenderingLinkList = false
    private var lastHeading: String? = nil
    
    /// Perform actions while rendering a link list, which affects the output formatting of links
    mutating func withRenderingLinkList(_ process: (inout Self) -> Void) {
        isRenderingLinkList = true
        process(&self)
        isRenderingLinkList = false
    }
    
    /// Perform actions while removing a base level of indentation, typically while processing the contents of block directives.
    mutating func withRemoveIndentation(from base: (any Markup)?, process: (inout Self) -> Void) {
        indentationToRemove = nil
        if let toRemove = base?
            .format()
            .splitByNewlines
            .first(where: { $0.isEmpty == false })?
            .prefix(while: { $0.isWhitespace && !$0.isNewline }) {
            if toRemove.isEmpty == false {
                indentationToRemove = String(toRemove)
            }
        }
        process(&self)
        indentationToRemove = nil
    }
}

extension MarkdownOutputMarkupWalker {
    mutating func visit(_ optionalMarkup: (any Markup)?) -> Void {
        if let markup = optionalMarkup {
            self.visit(markup)
        }
    }
    
    mutating func visit(section: (any Section)?, addingHeading: String? = nil) -> Void {
        guard
            let section = section,
            section.content.isEmpty == false else {
            return
        }
        
        if let heading = addingHeading ?? type(of: section).title, heading.isEmpty == false {
            // Don't add if there is already a heading in the content
            if let first = section.content.first as? Heading, first.level == 2 {
                // Do nothing
            } else {
                visit(Heading(level: 2, Text(heading)))
            }
        }
        
        section.content.forEach {
            self.visit($0)
        }
    }
        
    mutating func startNewParagraphIfRequired() {
        if !markdown.isEmpty, !markdown.hasSuffix("\n\n") { markdown.append("\n\n") }
    }
}

extension MarkdownOutputMarkupWalker {
    
    mutating func defaultVisit(_ markup: any Markup) -> () {
        var output = markup.format()
        if let indentationToRemove, output.hasPrefix(indentationToRemove) {
            output.removeFirst(indentationToRemove.count)
        }
        markdown.append(output)
    }
        
    mutating func visitHeading(_ heading: Heading) -> () {
        startNewParagraphIfRequired()
        markdown.append(heading.detachedFromParent.format())
        if heading.level > 1 {
            lastHeading = heading.plainText
        }
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        guard isRenderingLinkList else {
            return defaultVisit(unorderedList)
        }
        
        startNewParagraphIfRequired()
        for item in unorderedList.listItems {
            item.children.forEach { visit($0) }
            startNewParagraphIfRequired()
        }
    }
    
    mutating func visitImage(_ image: Image) -> () {
        guard let source = image.source else {
            return
        }
        let unescaped = source.removingPercentEncoding ?? source
        var filename = source
        if
            let resolved = context.resolveAsset(named: unescaped, in: identifier, withType: .image), let first = resolved.variants.first?.value {
            filename = first.lastPathComponent
        }
                    
        markdown.append("![\(image.altText ?? "")](images/\(bundle.id)/\(filename))")
    }
       
    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        startNewParagraphIfRequired()
        markdown.append(codeBlock.detachedFromParent.format())
    }
    
    mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> () {
        guard
            let destination = symbolLink.destination,
            let resolved = context.referenceIndex[destination],
            let node = context.topicGraph.nodeWithReference(resolved)
        else {
            return defaultVisit(symbolLink)
        }
        
        let linkTitle: String
        var linkListAbstract: (any Markup)?
        if
            isRenderingLinkList,
            let doc = try? context.entity(with: resolved),
            let symbol = doc.semantic as? Symbol
        {
            linkListAbstract = (doc.semantic as? Symbol)?.abstract
            if let fragments = symbol.navigator {
                linkTitle = fragments
                    .map { $0.spelling }
                    .joined(separator: " ")
            } else {
                linkTitle = symbol.title
            }
            add(source: resolved, type: .belongsToTopic, subtype: nil)
        } else {
            linkTitle = node.title
        }
        let link = Link(destination: destination, title: linkTitle, [InlineCode(linkTitle)])
        // Only perform the linked list rendering for the first thing you find
        let previous = isRenderingLinkList
        isRenderingLinkList = false
        visit(link)
        visit(linkListAbstract)
        isRenderingLinkList = previous
    }
    
    mutating func visitLink(_ link: Link) -> () {
        guard
            link.isAutolink,
            let destination = link.destination,
            let resolved = context.referenceIndex[destination],
            let doc = try? context.entity(with: resolved)
        else {
            return defaultVisit(link)
        }
        
        let linkTitle: String
        var linkListAbstract: (any Markup)?
        if
            let article = doc.semantic as? Article
        {
            if isRenderingLinkList {
                linkListAbstract = article.abstract
                add(source: resolved, type: .belongsToTopic, subtype: nil)
            }
            linkTitle = article.title?.plainText ?? resolved.lastPathComponent
        } else {
            linkTitle = resolved.lastPathComponent
        }
        
        let linkMarkup: any RecurringInlineMarkup
        if doc.semantic is Symbol {
            linkMarkup = InlineCode(linkTitle)
        } else {
            linkMarkup = Text(linkTitle)
        }
        
        let link = Link(destination: destination, title: linkTitle, [linkMarkup])
        // Only perform the linked list rendering for the first thing you find
        let previous = isRenderingLinkList
        isRenderingLinkList = false
        defaultVisit(link)
        visit(linkListAbstract)
        isRenderingLinkList = previous
    }
    
    
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        markdown.append("\n")
    }
        
    mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        
        startNewParagraphIfRequired()
        
        for child in paragraph.children {
            visit(child)
        }
    }
    
    mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> () {
        
        switch blockDirective.name {
        case VideoMedia.directiveName:
            guard let video = VideoMedia(from: blockDirective, for: bundle) else {
                return
            }
            visit(video)
                        
        case ImageMedia.directiveName:
            guard let image = ImageMedia(from: blockDirective, for: bundle) else {
                return
            }
            visit(image)
            
        case Row.directiveName:
            guard let row = Row(from: blockDirective, for: bundle) else {
                return
            }
            for column in row.columns {
                markdown.append("\n\n")
                withRemoveIndentation(from: column.childMarkup.first) {
                    $0.visit(container: column.content)
                }
            }
        case TabNavigator.directiveName:
            guard let tabs = TabNavigator(from: blockDirective, for: bundle) else {
                return
            }
            if
                let defaultLanguage = context.sourceLanguages(for: identifier).first?.name,
                let languageMatch = tabs.tabs.first(where: { $0.title.lowercased() == defaultLanguage.lowercased() }) {
                visit(container: languageMatch.content)
            } else {
                for tab in tabs.tabs {
                    // Don't make any assumptions about headings here
                    let para = Paragraph([Strong(Text("\(tab.title):"))])
                    visit(para)
                    withRemoveIndentation(from: tab.childMarkup.first) {
                        $0.visit(container: tab.content)
                        
                    }
                }
            }
        case Links.directiveName:
            withRenderingLinkList {
                for child in blockDirective.children {
                    $0.withRemoveIndentation(from: child) {
                        $0.visit(child)
                    }
                }
            }
        case Snippet.directiveName:
            guard let snippet = Snippet(from: blockDirective, for: bundle) else {
                return
            }
            guard case .success(let resolved) = context.snippetResolver.resolveSnippet(path: snippet.path) else {
                return
            }
            
            let lines: [String]
            let renderExplanation: Bool
            if let slice = snippet.slice {
                renderExplanation = false
                guard let sliceRange = resolved.mixin.slices[slice] else {
                    return
                }
                let sliceLines = resolved.mixin
                    .lines[sliceRange]
                    .linesWithoutLeadingWhitespace()
                lines = sliceLines.map { String($0) }
            } else {
                renderExplanation = true
                lines = resolved.mixin.lines
            }
            
            if renderExplanation, let explanation = resolved.explanation {
                visit(explanation)
            }
            
            let code = CodeBlock(language: resolved.mixin.language, lines.joined(separator: "\n"))
            visit(code)
        default: return
        }
        
    }
}

// Semantic handling
extension MarkdownOutputMarkupWalker {
    
    mutating func visit(container: MarkupContainer?) -> Void {
        container?.elements.forEach {
            self.visit($0)
        }
    }
    
    mutating func visit(_ video: VideoMedia) -> Void {
        let unescaped = video.source.path.removingPercentEncoding ?? video.source.path
        var filename = video.source.url.lastPathComponent
        if
            let resolvedVideos = context.resolveAsset(named: unescaped, in: identifier, withType: .video), let first = resolvedVideos.variants.first?.value {
            filename = first.lastPathComponent
        }
                    
        markdown.append("\n\n![\(video.altText ?? "")](videos/\(bundle.id)/\(filename))")
        visit(container: video.caption)
    }
    
    mutating func visit(_ image: ImageMedia) -> Void {
        let unescaped = image.source.path.removingPercentEncoding ?? image.source.path
        var filename = image.source.url.lastPathComponent
        if let resolvedImages = context.resolveAsset(named: unescaped, in: identifier, withType: .image), let first = resolvedImages.variants.first?.value {
            filename = first.lastPathComponent
        }
        markdown.append("\n\n![\(image.altText ?? "")](images/\(bundle.id)/\(filename))")
    }
    
    mutating func visit(_ code: Code) -> Void {
        guard let codeIdentifier = context.identifier(forAssetName: code.fileReference.path, in: identifier) else {
            return
        }
        let fileReference = ResourceReference(bundleID: code.fileReference.bundleID, path: codeIdentifier)
        let codeText: String
        if
            let data = try? context.resource(with: fileReference),
            let string = String(data: data, encoding: .utf8) {
            codeText = string
        } else if
            let asset = context.resolveAsset(named: code.fileReference.path, in: identifier),
            let string = try? String(contentsOf: asset.data(bestMatching: .init()).url, encoding: .utf8)
        {
            codeText = string
        } else {
            return
        }
        
        visit(Paragraph(Emphasis(Text(code.fileName))))
        visit(CodeBlock(codeText))
    }
    
}

// MARK: - Manifest construction
extension MarkdownOutputMarkupWalker {
    mutating func add(source: ResolvedTopicReference, type: MarkdownOutputManifest.RelationshipType, subtype: String?) {
        var targetURI = identifier.path
        if let lastHeading {
            targetURI.append("#\(urlReadableFragment(lastHeading))")
        }
        let relationship = MarkdownOutputManifest.Relationship(sourceURI: source.path, relationshipType: type, subtype: subtype, targetURI: targetURI)
        outgoingReferences.insert(relationship)
                                                               
    }
}
