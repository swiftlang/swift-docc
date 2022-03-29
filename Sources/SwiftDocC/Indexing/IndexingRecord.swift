/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/**
 A structure containing indexing information for a ``RenderNode``.
*/
public struct IndexingRecord: Equatable {
    /**
     The location of the content for this record.
     
     Top-level pages are an obvious kind of search result in a list-like UI. However,
     we may want to put subsections or other important items in the same list of search results.
     This location may point to a top-level page or somewhere deeper in the page.
     
     For example, a ``Tutorial`` may have its own search result and each of its ``TutorialSection``s may be a search result as well.
     */
    public enum Location: Equatable {
        /**
         A search result corresponds to a top-level page of documentation.
         */
        case topLevelPage(ResolvedTopicReference)
        
        /**
         A search result corresponds to something on a page of documentation.
         */
        case contained(ResolvedTopicReference, inPage: ResolvedTopicReference)
    }
    
    /**
     The kind of documentation for a search result.
     */
    public struct Kind: RawRepresentable, Equatable {
        public var rawValue: String
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
        
        /// A Technology "Overview" page.
        public static let overview = Kind(rawValue: "overview")
                
        /// A "Tutorial" page.
        public static let tutorial = Kind(rawValue: "tutorial")
        
        /// An "Article" page.
        public static let article = Kind(rawValue: "article")
        
        /// A tutorial section.
        public static let tutorialSection = Kind(rawValue: "tutorialSection")
        
        /// A symbol page.
        public static let symbol = Kind(rawValue: "symbol")
    }
    
    /**
     The kind of document or section whose text content this record collects.
     */
    public let kind: Kind
    
    /**
     The location of a search result for this record.
     */
    public let location: Location
    
    /**
     The title of the document or section.
     */
    public let title: String
    
    /**
     A summary phrase, sentence, or abstract from a document or section for use in previewing content in search results.
     */
    public let summary: String
    
    /**
     Headings and subheadings in the document or section.
     */
    public let headings: [String]
    
    /**
     A concatenation of all other raw text content in the document or section.
     
     > Note: Titles, headings, and abstracts are not included in this string.
     */
    public let rawIndexableTextContent: String
    
    /// The availability information for a platform.
    public typealias PlatformAvailability = AvailabilityRenderItem
    /// Information about the platforms for which the summarized element is available.
    public let platforms: [PlatformAvailability]?

    init(kind: Kind, location: Location, title: String, summary: String, headings: [String], rawIndexableTextContent: String, platforms: [PlatformAvailability]? = nil) {
        self.kind = kind
        self.location = location
        self.title = title
        self.summary = summary
        self.headings = headings
        self.rawIndexableTextContent = rawIndexableTextContent
        self.platforms = platforms
    }
}

// MARK: - Codable conformance

extension IndexingRecord: Codable {}

extension IndexingRecord.Location: Codable {
    private enum LocationType: String, Codable {
        case topLevelPage
        case contained
    }
    
    private enum CodingKeys: CodingKey {
        case type
        case reference, inPage
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(LocationType.self, forKey: .type)
        
        switch type {
        case .topLevelPage:
            let reference = try container.decode(ResolvedTopicReference.self, forKey: .reference)
            self = .topLevelPage(reference)
        case .contained:
            let reference = try container.decode(ResolvedTopicReference.self, forKey: .reference)
            let inPageReference = try container.decode(ResolvedTopicReference.self, forKey: .inPage)
            self = .contained(reference, inPage: inPageReference)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .topLevelPage(let reference):
            try container.encode(LocationType.topLevelPage, forKey: .type)
            try container.encode(reference, forKey: .reference)
        case .contained(let reference, let inPage):
            try container.encode(LocationType.contained, forKey: .type)
            try container.encode(reference, forKey: .reference)
            try container.encode(inPage, forKey: .inPage)
        }
    }
}

extension IndexingRecord.Kind: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }
}
