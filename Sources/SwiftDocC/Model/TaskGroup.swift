/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
public import Markdown

/**
 A rewriter that extracts topic links for unordered list items.
 */
struct ExtractLinks: MarkupRewriter {
    enum Mode {
        case linksDirective
        case taskGroup
    }
    
    var links = [any AnyLink]()
    var diagnostics = [Diagnostic]()
    var mode = Mode.taskGroup
        
    /// Creates a warning with a suggestion to remove all paragraph elements but the first.
    private func makeTrailingContentDiagnostic(_ paragraph: Paragraph) -> Diagnostic {
        let range = paragraph.range ?? paragraph.firstChildRange()
        // An unexpected non-link list item found, suggest to remove it
        let trailingContent = Document(Paragraph(paragraph.inlineChildren.dropFirst()))
        let replacements = trailingContent.children.range.map({ [Solution.Replacement(range: $0, replacement: "")] }) ?? []
        let solutions = [Solution(summary: "Remove extraneous content", replacements: replacements)]
        
        switch mode {
        case .taskGroup:
            return Diagnostic(
                source: range?.source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.ExtraneousTaskGroupItemContent",
                summary: "Extraneous content found after a link in task group list item",
                solutions: solutions
            )
        case .linksDirective:
            return Diagnostic(
                source: range?.source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.ExtraneousLinksDirectiveItemContent",
                summary: "Extraneous content found after a link",
                explanation: "\(Links.directiveName.singleQuoted) can only contain a bulleted list of documentation links",
                solutions: solutions
            )
        }
    }
    
    private func makeNonLinkContentDiagnostic(_ item: ListItem) -> Diagnostic {
        let range = item.range ?? item.firstChildRange()
        let replacements = range.map({ [Solution.Replacement(range: $0, replacement: "")] }) ?? []
        let solutions = [Solution(summary: "Remove non-link item", replacements: replacements)]
        
        switch mode {
        case .taskGroup:
            return Diagnostic(
                source: range?.source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.UnexpectedTaskGroupItem",
                summary: "Only links are allowed in task group list items",
                solutions: solutions
            )
        case .linksDirective:
            return Diagnostic(
                source: range?.source,
                severity: .warning,
                range: range,
                identifier: "org.swift.docc.UnexpectedLinksDirectiveListItem",
                summary: "Only documentation links are allowed in \(Links.directiveName.singleQuoted) list items",
                solutions: solutions
            )
        }
    }
    
    mutating func visitUnorderedList(_ unorderedList: UnorderedList) -> (any Markup)? {
        let remainingItems = unorderedList.children.map { $0 as! ListItem }
            .filter { item -> Bool in
                guard item.childCount == 1 else { return true }
                
                guard let paragraph = item.child(at: 0) as? Paragraph,
                    paragraph.childCount >= 1 else { return true }
                
                // Check for trailing invalid content.
                let containsInvalidContent = paragraph.children.dropFirst().contains { child in
                    let isComment = child is InlineHTML
                    var isSpace = false
                    if let text = child as? Text {
                        isSpace = text.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    }
                    return !(isComment || isSpace)
                }
                
                switch paragraph.child(at: 0) {
                    case let link as Link:
                        // Topic link
                        guard let url = link.destination.flatMap(URL.init(string:)) else {
                            return true
                        }
                    
                        switch mode {
                        case .linksDirective:
                            // The 'Links' directive only supports `doc:` links.
                            guard ResolvedTopicReference.urlHasResolvedTopicScheme(url) else {
                                diagnostics.append(makeNonLinkContentDiagnostic(item))
                                return true
                            }
                        case .taskGroup:
                            guard let scheme = url.scheme,
                                  TaskGroup.allowedSchemes.contains(scheme) else { return true }
                        }
                        links.append(link)
                        
                        // Warn if there is a trailing content after the link
                        if containsInvalidContent {
                            
                            diagnostics.append(makeTrailingContentDiagnostic(paragraph))
                        }
                        return false
                    case let link as SymbolLink:
                        // Symbol link
                        links.append(link)
                        
                        // Warn if there is a trailing content after the link
                        if containsInvalidContent {
                            diagnostics.append(makeTrailingContentDiagnostic(paragraph))
                        }
                        return false
                    default:
                        diagnostics.append(makeNonLinkContentDiagnostic(item))
                        return true
                }
        }
        guard !remainingItems.isEmpty else {
            return nil
        }
        return UnorderedList(remainingItems)
    }
}

/**
 A collection of curated child topics.
 */
public struct TaskGroup {
    /// The schemes for links to external content supported in task groups.
    static let allowedExternalSchemes = ["http", "https"]
    /// The schemes for links that is supported in task groups.
    static let allowedSchemes = allowedExternalSchemes + [ResolvedTopicReference.urlScheme]
    
    /// The title heading of the group.
    public var heading: Heading?
    
    /// The group's original contents, excluding its delimiting heading.
    public var originalContent: [any Markup]
    
    /// The group's remaining content after stripping topic links.
    public var content: [any Markup] {
        var extractor = ExtractLinks()
        return originalContent.compactMap {
            extractor.visit($0)
        }
    }
    
    /**
     The curated child topic links in this group.
     
     - Note: Links must be at the top level and have the `doc:` URL scheme.
     */
    public var links: [any AnyLink] {
        var extractor = ExtractLinks()
        for child in originalContent {
            _ = extractor.visit(child)
        }
        return extractor.links
    }
    
    /// An optional abstract for the task group.
    public var abstract: AbstractSection? {
        if let firstParagraph = originalContent.mapFirst(where: { $0 as? Paragraph }) {
            return AbstractSection(paragraph: firstParagraph)
        }
        return nil
    }
    
    /// An optional discussion section for the task group.
    public var discussion: DiscussionSection? {
        guard originalContent.count > 1 else {
            // There must be more than 1 element to contain both a discussion and links list
            return nil
        }
        
        var discussionChildren = originalContent
            .prefix(while: { !($0 is UnorderedList) })
            .filter({ !($0 is BlockDirective) })
        
        // Drop the abstract
        if discussionChildren.first is Paragraph {
            discussionChildren.removeFirst()
        }
        
        guard !discussionChildren.isEmpty else { return nil }

        return DiscussionSection(content: Array(discussionChildren))
    }
    
    /// Creates a new task group with a given heading and content.
    /// - Parameters:
    ///   - heading: The heading for this task group.
    ///   - content: The content, excluding the title, for this task group.
    public init(heading: Heading?, content: [any Markup]) {
        self.heading = heading
        self.originalContent = content
    }
    
    var directives: [String: [BlockDirective]] {
        .init(grouping: originalContent.compactMap { $0 as? BlockDirective }, by: \.name)
    }
}

extension TaskGroup {
    /// Validates the task group links markdown and return the diagnostics, if any.
    func diagnosticsForGroupLinks() -> [Diagnostic] {
        var extractor = ExtractLinks()
        for child in originalContent {
            _ = extractor.visit(child)
        }
        return extractor.diagnostics
    }
}
