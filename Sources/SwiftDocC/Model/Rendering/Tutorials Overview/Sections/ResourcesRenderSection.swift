/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that contains additional resources for learning about a technology.
public struct ResourcesRenderSection: RenderSection, Equatable {
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

// Diffable conformance
extension ResourcesRenderSection: RenderJSONDiffable {
    /// Returns the differences between this ResourcesRenderSection and the given one.
    func difference(from other: ResourcesRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.tiles, forKey: CodingKeys.tiles)
        diffBuilder.addDifferences(atKeyPath: \.content, forKey: CodingKeys.content)

        return diffBuilder.differences
    }

    /// Returns if this ResourcesRenderSection is similar enough to the given one.
    func isSimilar(to other: ResourcesRenderSection) -> Bool {
        return self.content == other.content
    }
}
