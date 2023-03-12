/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A task group section that contains links to other symbols.
public struct TaskGroupRenderSection: RenderSection {
    public let kind: RenderSectionKind = .taskGroup
    
    /// An optional title for the section.
    public let title: String?
    /// An optional abstract summary for the section.
    public let abstract: [RenderInlineContent]?
    /// An optional discussion for the section.
    public let discussion: RenderSection?
    /// A list of topic graph references.
    @available(*, deprecated, message: "Please use identifierItems instead.")
    public var identifiers: [String] { identifierItems.map { $0.identifier } }
    /// A list of topic graph reference items
    public let identifierItems: [IdentifierItem]
    /// If true, this is an automatically generated group. If false, this is an authored group.
    public let generated: Bool
    
    public struct IdentifierItem: Codable {
        public let identifier: String
        public let overrideTitle: String?
        public let overridingTitleInlineContent: [RenderInlineContent]?

        public init(identifier: String, overrideTitle: String? = nil, overridingTitleInlineContent: [RenderInlineContent]? = nil) {
            self.identifier = identifier
            self.overrideTitle = overrideTitle
            self.overridingTitleInlineContent = overridingTitleInlineContent
        }
    }

    /// Creates a new task group.
    /// - Parameters:
    ///   - title: An optional title for the section.
    ///   - abstract: An optional abstract summary for the section.
    ///   - discussion: An optional discussion for the section.
    ///   - identifiers: A list of topic-graph references.
    ///   - generated: If `true`, this is an automatically generated group. If `false`, this is an authored group.
    @available(*, deprecated, message: "Please use TaskGroupRenderSection.init(title:abstract:discussion:identifierItems:generated:) instead.")
    public init(title: String?, abstract: [RenderInlineContent]?, discussion: RenderSection?, identifiers: [String], generated: Bool = false) {
        self.title = title
        self.abstract = abstract
        self.discussion = discussion
        self.identifierItems = identifiers.map { IdentifierItem(identifier: $0) }
        self.generated = generated
    }
    
    /// Creates a new task group.
    /// - Parameters:
    ///   - title: An optional title for the section.
    ///   - abstract: An optional abstract summary for the section.
    ///   - discussion: An optional discussion for the section.
    ///   - identifiers: A list of topic-graph references.
    ///   - generated: If `true`, this is an automatically generated group. If `false`, this is an authored group.
    public init(title: String?, abstract: [RenderInlineContent]?, discussion: RenderSection?, identifierItems: [IdentifierItem], generated: Bool = false) {
        self.title = title
        self.abstract = abstract
        self.discussion = discussion
        self.identifierItems = identifierItems
        self.generated = generated
    }
    
    /// The list of keys you use to encode or decode this section.
    private enum CodingKeys: CodingKey {
        case title, abstract, discussion, identifiers, identifierItems, generated
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(abstract, forKey: .abstract)
        try container.encodeIfPresent(discussion.map(CodableRenderSection.init), forKey: .discussion)
        try container.encode(identifiers, forKey: .identifiers)
        try container.encode(identifierItems, forKey: .identifierItems)
        if generated {
            try container.encode(generated, forKey: .generated)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract)
        discussion = (try container.decodeIfPresent(CodableContentSection.self, forKey: .discussion)).map { $0.section }
        
        let identifiers = try container.decodeIfPresent([String].self, forKey: .identifiers)
        let identifierItems = try container.decodeIfPresent([IdentifierItem].self, forKey: .identifierItems)
        if let identifierItems = identifierItems {
            self.identifierItems = identifierItems
        } else if let identifiers = identifiers {
            self.identifierItems = identifiers.map { IdentifierItem(identifier: $0) }
        } else {
            self.identifierItems = []
        }
        generated = try container.decodeIfPresent(Bool.self, forKey: .generated) ?? false
        decoder.registerReferences(self.identifiers)
    }
}

extension TaskGroupRenderSection {

    /// Creates a new instance with the given automatically curated task group data.
    init(taskGroup group: AutomaticCuration.TaskGroup) {
        self.title = group.title
        self.abstract = nil
        self.discussion = nil
        self.identifierItems = group.references.map{ IdentifierItem(identifier: $0.absoluteString) }
        self.generated = false
    }
}
