/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 A value that can collect plain text content for use in search indexing.
 */
public protocol TextIndexing {
    /**
     Headings and sub-headings to drive search results.
     */
    var headings: [String] { get }

    /**
     A concatenation of all raw text content under this value except for titles and headings.

     > Note: There are no formatting guarantees of this text except that some separation between words is maintained.

     - parameter references: A dictionary of references to resolve ``RenderInlineContent.reference` elements' inlined titles.
     */
    func rawIndexableTextContent(references: [String: RenderReference]) -> String
}

/**
 A value that can provide search results.
 */
public protocol Indexable {
    /**
     A list of ``IndexingRecord``s that can become search results.
     
     > Note: A document may have a search result for itself and sometimes notable subsections.
     
     - throws: ``IndexingError``
     */
    func indexingRecords(onPage page: ResolvedTopicReference) throws -> [IndexingRecord]
}

extension Sequence where Element: TextIndexing {
    var headings: [String] {
        return self.flatMap { $0.headings }
    }
}

extension Sequence where Element == RenderBlockContent {
    var headings: [String] {
        return self.flatMap { $0.headings }
    }

    func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return self.map { $0.rawIndexableTextContent(references: references) }.joined(separator: " ")
    }
}

extension Sequence where Element == RenderInlineContent {
    func rawIndexableTextContent(references: [String: RenderReference]) -> String {
        return self.map { $0.rawIndexableTextContent(references: references) }.joined()
    }
}
