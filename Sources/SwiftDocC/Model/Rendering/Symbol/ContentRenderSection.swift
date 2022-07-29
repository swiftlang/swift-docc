/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section of documentation content.
public struct ContentRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind
    
    /// Arbitrary content for this section.
    public var content: [RenderBlockContent]
    
    /// Creates a new content section
    /// - Parameters:
    ///   - kind: The kind of the new section.
    ///   - content: Arbitrary rendering content.
    ///   - heading: A heading to use for the new section.
    public init(kind: RenderSectionKind, content: [RenderBlockContent], heading: String? = nil) {
        self.kind = kind
        self.content = content
        if let heading = heading {
            self.content.insert(RenderBlockContent.heading(level: 2, text: heading, anchor: urlReadableFragment(heading.lowercased())), at: 0)
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        kind = try container.decode(RenderSectionKind.self, forKey: .kind)
        content = try container.decode([RenderBlockContent].self, forKey: .content)
    }
}

extension ContentRenderSection: Diffable {
    func difference(from other: ContentRenderSection, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.content, forKey: CodingKeys.content)
        
        return diffBuilder.differences
    }
}
