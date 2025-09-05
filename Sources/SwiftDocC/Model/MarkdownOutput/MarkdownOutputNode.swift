public import Foundation
public import Markdown
/// A markdown version of a documentation node.
public struct MarkdownOutputNode {

    public let context: DocumentationContext
    public let bundle: DocumentationBundle
    public let identifier: ResolvedTopicReference
    
    public init(context: DocumentationContext, bundle: DocumentationBundle, identifier: ResolvedTopicReference) {
        self.context = context
        self.bundle = bundle
        self.identifier = identifier
    }
    
    public var metadata: [String: String] = [:]
    public var markdown: String = ""
    
    public var data: Data {
        get throws {
            Data(markdown.utf8)
        }
    }
    
    private(set) var indentationToRemove: String?
    private(set) var isRenderingLinkList = false
    
    public mutating func withRenderingLinkList(_ process: (inout MarkdownOutputNode) -> Void) {
        isRenderingLinkList = true
        process(&self)
        isRenderingLinkList = false
    }
    
    public mutating func withRemoveIndentation(from base: (any Markup)?, process: (inout MarkdownOutputNode) -> Void) {
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
    
    private var linkListAbstract: (any Markup)?
}

extension MarkdownOutputNode {
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
        
        if let heading = addingHeading ?? type(of: section).title {
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

extension MarkdownOutputNode: MarkupWalker {
    
    public mutating func defaultVisit(_ markup: any Markup) -> () {
        var output = markup.format()
        if let indentationToRemove, output.hasPrefix(indentationToRemove) {
            output.removeFirst(indentationToRemove.count)
        }
        markdown.append(output)
    }
        
    public mutating func visitHeading(_ heading: Heading) -> () {
        startNewParagraphIfRequired()
        markdown.append(heading.detachedFromParent.format())
    }
    
    public mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> () {
        guard isRenderingLinkList else {
            return defaultVisit(unorderedList)
        }
        
        startNewParagraphIfRequired()
        for item in unorderedList.listItems {
            linkListAbstract = nil
            item.children.forEach { visit($0) }
            visit(linkListAbstract)
            linkListAbstract = nil
            startNewParagraphIfRequired()
        }
    }
    
    public mutating func visitImage(_ image: Image) -> () {
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
       
    public mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> () {
        startNewParagraphIfRequired()
        markdown.append(codeBlock.detachedFromParent.format())
    }
    
    public mutating func visitSymbolLink(_ symbolLink: SymbolLink) -> () {
        guard
            let destination = symbolLink.destination,
            let resolved = context.referenceIndex[destination],
            let node = context.topicGraph.nodeWithReference(resolved)
        else {
            return defaultVisit(symbolLink)
        }
        
        let linkTitle: String
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
        } else {
            linkTitle = node.title
        }
        let link = Link(destination: destination, title: linkTitle, [InlineCode(linkTitle)])
        visit(link)
    }
    
    public mutating func visitLink(_ link: Link) -> () {
        guard
            link.isAutolink,
            let destination = link.destination,
            let resolved = context.referenceIndex[destination],
            let doc = try? context.entity(with: resolved)
        else {
            return defaultVisit(link)
        }
        
        let linkTitle: String
        if
            let article = doc.semantic as? Article
        {
            if isRenderingLinkList {
                linkListAbstract = article.abstract
            }
            linkTitle = article.title?.plainText ?? resolved.lastPathComponent
        } else {
            linkTitle = resolved.lastPathComponent
        }
        let link = Link(destination: destination, title: linkTitle, [InlineCode(linkTitle)])
        defaultVisit(link)
    }
    
    
    public mutating func visitSoftBreak(_ softBreak: SoftBreak) -> () {
        markdown.append("\n")
    }
        
    public mutating func visitParagraph(_ paragraph: Paragraph) -> () {
        
        startNewParagraphIfRequired()
        
        for child in paragraph.children {
            visit(child)
        }
    }
    
    public mutating func visitBlockDirective(_ blockDirective: BlockDirective) -> () {
        
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
                let languageMatch = tabs.tabs.first(where: { $0.title.lowercased() == defaultLanguage }) {
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
            
        default: return
        }
        
    }
}

// Semantic handling
extension MarkdownOutputNode {
    
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
