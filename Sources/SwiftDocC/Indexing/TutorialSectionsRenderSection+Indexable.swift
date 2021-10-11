/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension TutorialSectionsRenderSection {
    public func indexingRecords(onPage page: ResolvedTopicReference, references: [String: RenderReference]) throws -> [IndexingRecord] {
        return tasks.map { section -> IndexingRecord in
            let sectionReference = page.withFragment(section.anchor)
            let summary: String
            
            switch section.contentSection.first {
                case .some(.contentAndMedia(let contentAndMedia)):
                summary = contentAndMedia.content.firstParagraph.rawIndexableTextContent(references: references)
                case .some(.fullWidth(let content)):
                summary = content.firstParagraph.rawIndexableTextContent(references: references)
                case .some(.columns), nil:
                summary = ""
            }
            
            return IndexingRecord(kind: .tutorialSection, location: .contained(sectionReference, inPage: page), title: section.title, summary: summary, headings: section.headings, rawIndexableTextContent: section.rawIndexableTextContent(references: references))
        }
    }
}
