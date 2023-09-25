/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A section that groups content and media sections.
public struct ContentAndMediaGroupSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .contentAndMediaGroup
    
    /// The layout direction of all content and media sections in this group.
    public var layout: ContentAndMediaSection.Layout?
    
    /// The content and media sections in this group.
    public var sections: [ContentAndMediaSection]
    
    /// Creates a group of content and media sections.
    ///
    /// - Precondition: `sections.count >= 1`.
    /// - Precondition: All sections have the same `layout`.
    public init(sections: [ContentAndMediaSection]) {
        precondition(!sections.isEmpty)
        assert(sections.allSatisfy({ $0.layout == sections.first?.layout }))
        
        self.layout = sections.first!.layout
        self.sections = sections
    }
}

// Diffable conformance
extension ContentAndMediaGroupSection: RenderJSONDiffable {
    /// Returns the differences between this ContentAndMediaGroupSection and the given one.
    func difference(from other: ContentAndMediaGroupSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.layout, forKey: CodingKeys.layout)
        diffBuilder.addDifferences(atKeyPath: \.sections, forKey: CodingKeys.sections)

        return diffBuilder.differences
    }
    
    /// Returns if this ContentAndMediaGroupSection is similar enough to the given one.
    func isSimilar(to other: ContentAndMediaGroupSection) -> Bool {
        return self.sections == other.sections
    }
}
