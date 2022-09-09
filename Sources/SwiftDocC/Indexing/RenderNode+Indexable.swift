/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderNode {
    public var headings: [String] {
        return contentSections
            // Exclude headings from call-to-action sections, since they always link to standalone (indexed) pages.
            .filter { $0.kind != .callToAction }
            .flatMap { $0.headings }
    }

    var rawIndexableTextContent: String {
        return contentSections
            // Exclude text from call-to-action sections, since they always link to standalone (indexed) pages.
            .filter { $0.kind != .callToAction }
            .map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
    
    private var contentSections: [RenderSection] {
        guard kind == .symbol || (kind == .article && sections.isEmpty) else {
            return sections
        }
        
        return [ContentRenderSection(kind: .content, content: [.paragraph(.init(inlineContent: abstract ?? []))])]
            + primaryContentSections
    }
}

extension RenderNode: Indexable {
    func topLevelIndexingRecord() throws -> IndexingRecord {
        let kind: IndexingRecord.Kind
        switch self.kind {
        case .tutorial:
            kind = .tutorial
        case .section:
            kind = .tutorialSection
        case .overview:
            kind = .overview
        case .article:
            kind = .article
        case .symbol:
            kind = .symbol
        }
        
        guard let title = metadata.title, !title.isEmpty else {
            // We at least need a title for a search result.
            throw IndexingError.missingTitle(identifier)
        }
        
        let summaryParagraph: RenderBlockContent?
        if let abstract = self.abstract {
            summaryParagraph = RenderBlockContent.paragraph(.init(inlineContent: abstract))
        } else if let intro = self.sections.first as? IntroRenderSection, let firstBlock = intro.content.first, case .paragraph = firstBlock {
            summaryParagraph = firstBlock
        } else {
            summaryParagraph = nil
        }

        let summary = summaryParagraph?.rawIndexableTextContent(references: references) ?? ""
        
        return IndexingRecord(kind: kind, location: .topLevelPage(identifier), title: title, summary: summary, headings: self.headings, rawIndexableTextContent: self.rawIndexableTextContent, platforms: metadata.platforms)
    }
    
    public func indexingRecords(onPage page: ResolvedTopicReference) throws -> [IndexingRecord] {
        switch self.kind {
        case .tutorial:
            let sectionRecords = try self.sections
                .flatMap { section -> [IndexingRecord] in
                    guard let sectionsSection = section as? TutorialSectionsRenderSection else {
                        return []
                    }
                    return try sectionsSection.indexingRecords(onPage: page, references: references)
            }
            
            return [try topLevelIndexingRecord()] + sectionRecords
        default:
            return [try topLevelIndexingRecord()]
        }
    }
}
