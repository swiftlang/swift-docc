/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains additional resources for learning about a technology.
public struct ResourcesRenderSection: RenderSection {
    public var kind: RenderSectionKind = .resources
    
    /// The resource tiles.
    public var tiles: [RenderTile]
    
    /// An abstract for the section.
    public var content: [RenderBlockContent] = []
        
    /// Creates a new resources section from the given tiles and content.
    ///
    /// - Parameters:
    ///    - tiles: A list of tiles for the section.
    ///    - content: The section's abstract.
    public init(tiles: [RenderTile], content: [RenderBlockContent]) {
        self.tiles = tiles
        self.content = content
    }
}
