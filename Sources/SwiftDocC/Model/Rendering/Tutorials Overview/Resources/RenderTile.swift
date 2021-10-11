/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A render-friendly representation of a view that links
/// to a specified type of content.
///
/// Depending on its type, a render tile contains links to a 
/// specific kind of resource such as sample code, videos,
/// or forum topics.
public struct RenderTile: Codable, TextIndexing {
    /// Predefined semantic tile identifiers.
    public enum Identifier: String, Codable {
        /// Identifies a tile that links to featured content.
        case featured = "featured"

        /// Identifies a tile that links to documentation.
        case documentation = "documentation"

        /// Identifies a tile that links to sample code.
        case sampleCode = "sampleCode"

        /// Identifies a tile that links to downloads.
        case downloads = "downloads"

        /// Identifies a tile that links to videos.
        case videos = "videos"

        /// Identifies a tile that links to forum topics.
        case forums = "forums"
        
        /// Creates a new render-friendly tile identifier from a tile
        /// identifier.
        init(tileIdentifier: Tile.Identifier) {
            switch tileIdentifier {
                case .documentation: self = .documentation
                case .sampleCode: self = .sampleCode
                case .downloads: self = .downloads
                case .videos: self = .videos
                case .forums: self = .forums
            }
        }
    }
    
    /// The type of tile.
    ///
    /// Use this identifier to determine the tile's type during layout.
    public var identifier: RenderTile.Identifier
    
    /// The tile's title.
    public var title: String
    
    /// The main content of the tile.
    public var content: [RenderBlockContent] = []
    
    /// The tile's call-to-action content, if any.
    public var action: RenderInlineContent?
    
    /// A reference to the tile's media content, if any.
    public var media: RenderReferenceIdentifier?
    
    /// Creates a new tile from the given parameters.
    ///
    /// - Parameters:
    ///   - identifier: The type of tile.
    ///   - title: The tile's title.
    ///   - content: The main content for the tile.
    ///   - action: The tile's call-to-action content.
    ///   - media: A reference to the tile's media content.
    public init(identifier: RenderTile.Identifier, title: String, content: [RenderBlockContent] = [], action: RenderInlineContent?, media: RenderReferenceIdentifier?) {
        self.identifier = identifier
        self.title = title
        self.content = content
        self.action = action
        self.media = media
    }
}

extension RenderTile {
    /// Returns a call-to-action title for the given tile identifier. 
    ///
    /// This string is intended for use as a title for a tile's call-to-action
    /// link. An example title is "View more".
    public static func defaultCallToActionTitle(for identifier: Tile.Identifier) -> String {
        switch identifier {
            case .documentation: return "View more"
            case .sampleCode: return "View more"
            case .downloads: return "View downloads"
            case .videos: return "Watch videos"
            case .forums: return "View forums"
        }
    }
}
