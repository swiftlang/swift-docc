/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// Represents a volume containing a grouped list of tutorials.
public struct VolumeRenderSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .volume
    
    /// A group in a volume.
    public struct Chapter: Codable, TextIndexing, Equatable {
        /// The name of the chapter.
        public var name: String?
        /// An abstract describing the chapter.
        public var content: [RenderBlockContent] = []
        /// The (ordered) tutorials in a chapter.
        public var tutorials: [RenderReferenceIdentifier] = []
        
        /// An image for the chapter.
        public var image: RenderReferenceIdentifier?
        
        public var headings: [String] {
            return name.map { [$0] } ?? [] + content.headings
        }

        public func rawIndexableTextContent(references: [String : any RenderReference]) -> String {
            return content.rawIndexableTextContent(references: references)
        }

        /// Creates a new chapter with the given name.
        ///
        /// - Parameter name: The name of the chapter.
        public init(name: String?) {
            self.name = name
        }
    }
    
    /// The title of the volume section.
    public var name: String?
    
    /// An image for the volume.
    public var image: RenderReferenceIdentifier?
    
    /// Content that appears under the title of the chapters section.
    public var content: [RenderBlockContent]? = nil
    
    /// The chapters/groups in this section.
    public var chapters: [Chapter] = []
    
    /// Creates a new volume with the given name.
    ///
    /// - Parameter name: The name of the volume.
    public init(name: String?) {
        self.name = name
    }
    
    enum CodingKeys: CodingKey {
        case kind
        case name
        case image
        case content
        case chapters
    }
    
    // Override encode(to:) to explicitly encode 'null' when 'name' is nil, for anonymous volumes.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(kind, forKey: .kind)
        try container.encode(name, forKey: .name)
        try container.encode(image, forKey: .image)
        try container.encode(content, forKey: .content)
        try container.encode(chapters, forKey: .chapters)
    }
}

// Diffable conformance
extension VolumeRenderSection: RenderJSONDiffable {
    /// Returns the differences between this VolumeRenderSection and the given one.
    func difference(from other: VolumeRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.name, forKey: CodingKeys.name)
        diffBuilder.addDifferences(atKeyPath: \.image, forKey: CodingKeys.image)
        diffBuilder.addDifferences(atKeyPath: \.content, forKey: CodingKeys.content)
        diffBuilder.addDifferences(atKeyPath: \.chapters, forKey: CodingKeys.chapters)

        return diffBuilder.differences
    }

    /// Returns if this VolumeRenderSection is similar enough to the given one.
    func isSimilar(to other: VolumeRenderSection) -> Bool {
        return self.name == other.name || self.content == other.content
    }
}

// Diffable conformance
extension VolumeRenderSection.Chapter: RenderJSONDiffable {
    /// Returns the differences between this Chapter and the given one.
    func difference(from other: VolumeRenderSection.Chapter, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.name, forKey: CodingKeys.name)
        diffBuilder.addDifferences(atKeyPath: \.content, forKey: CodingKeys.content)
        diffBuilder.addDifferences(atKeyPath: \.tutorials, forKey: CodingKeys.tutorials)
        diffBuilder.addDifferences(atKeyPath: \.image, forKey: CodingKeys.image)

        return diffBuilder.differences
    }

    /// Returns if this Chapter is similar enough to the given one.
    func isSimilar(to other: VolumeRenderSection.Chapter) -> Bool {
        return self.name == other.name || self.content == other.content
    }
}
