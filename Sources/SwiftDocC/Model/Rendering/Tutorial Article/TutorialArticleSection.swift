/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A Tutorial Article section.
public struct TutorialArticleSection: RenderSection {
    
    public let kind: RenderSectionKind = .articleBody
    
    /// The contents of the Tutorial Article.
    public var content: [ContentLayout] = []
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        content = try container.decodeIfPresent([ContentLayout].self, forKey: .content) ?? []
    }
    
    /// Creates a tutorial article section from a given list
    /// of content layout items.
    ///
    /// - Parameter content: The content for this section.
    public init(content: [ContentLayout]) {
        self.content = content
    }
}

/// The layout in which the content should be presented.
public enum ContentLayout {
    /// A full-width layout.
    case fullWidth(content: [RenderBlockContent])
    
    /// A layout for a piece of media that has an attached description.
    case contentAndMedia(content: ContentAndMediaSection)
    
    /// A multi-column layout.
    case columns(content: [ContentAndMediaSection])
}

extension ContentLayout: Codable {
    private enum CodingKeys: CodingKey {
        case kind
        case content
    }
    
    private enum LayoutKind: String, Codable {
        case fullWidth, contentAndMedia, columns
    }
    
    private var kind: LayoutKind {
        switch self {
        case .fullWidth: return .fullWidth
        case .contentAndMedia: return .contentAndMedia
        case .columns: return .columns
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(LayoutKind.self, forKey: .kind)
        
        switch kind {
        case .fullWidth:
            self = try .fullWidth(content: container.decode([RenderBlockContent].self, forKey: .content))
        case .contentAndMedia:
            self = .contentAndMedia(content: try ContentAndMediaSection(from: decoder))
        case .columns:
            self = try .columns(content: container.decode([ContentAndMediaSection].self, forKey: .content))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        
        switch self {
        case .fullWidth(let content):
            try container.encode(content, forKey: .content)
        case .contentAndMedia(let content):
            try content.encode(to: encoder)
        case .columns(let content):
            try container.encode(content, forKey: .content)
        }
    }
}
