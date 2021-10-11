/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section containing textual content and media laid out horizontally or vertically.
public struct ContentAndMediaSection: RenderSection {
    public var kind: RenderSectionKind = .contentAndMedia
    
    /// The layout direction.
    public var layout: Layout?
    
    /// The title of the section.
    public var title: String?
    
    /// Text to display above the title.
    public var eyebrow: String?
    
    /// The body content of the section.
    public var content: [RenderBlockContent] = []
    
    /// An image or video to display opposite the text.
    public var media: RenderReferenceIdentifier?
    
    /// Whether the media comes before or after the text when read from top to bottom or leading to trailing.
    public var mediaPosition: ContentAndMedia.MediaPosition
    
    /// The kind of layout to use when rendering a section.
    /// Content is always leading, and media is always trailing.
    public enum Layout: String, Codable {
        /// Content should be laid out horizontally, with the media on the trailing side.
        case horizontal
        /// Content should be laid out vertically, with the media trailing the content.
        case vertical
    }
    
    /// Creates a new content and media section from the given parameters.
    ///
    /// - Parameters:
    ///   - layout: The layout direction for the section.
    ///   - title: The title of the section.
    ///   - media: A reference to a media item for the section.
    ///   - mediaPosition: The position of the media in relation to the prose content.
    public init(layout: Layout?, title: String?, media: RenderReferenceIdentifier?, mediaPosition: ContentAndMedia.MediaPosition) {
        self.layout = layout
        self.title = title
        self.media = media
        self.mediaPosition = mediaPosition
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        kind = try container.decodeIfPresent(RenderSectionKind.self, forKey: .kind) ?? .contentAndMedia
        layout = try container.decodeIfPresent(Layout.self, forKey: .layout)
        title = try container.decodeIfPresent(String.self, forKey: .title)
        eyebrow = try container.decodeIfPresent(String.self, forKey: .eyebrow)
        content = try container.decodeIfPresent([RenderBlockContent].self, forKey: .content) ?? []
        media = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .media)
        mediaPosition = try container.decodeIfPresent(ContentAndMedia.MediaPosition.self, forKey: .mediaPosition)
            // Provide backwards-compatibility for ContentAndMediaSections that don't have a `mediaPosition` key.
            ?? .leading
    }
}
