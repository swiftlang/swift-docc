/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that contains a list of symbol relationships of the same kind.
public struct RelationshipsRenderSection: RenderSection, Equatable {
    public let kind: RenderSectionKind = .relationships
    
    /// A title for the section.
    public let title: String
    
    /// A list of references to the symbols that are related to the symbol.
    public let identifiers: [String]
    
    /// The type of relationship, e.g., "Conforms To".
    public let type: String
    
    /// Creates a new relationships section.
    /// - Parameters:
    ///   - type: The type of relationships in that section, for example, "Conforms To".
    ///   - title: The title for this section.
    ///   - identifiers: The list of related symbol references.
    public init(type: String, title: String, identifiers: [String]) {
        self.type = type
        self.title = title
        self.identifiers = identifiers
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        identifiers = try container.decode([String].self, forKey: .identifiers)
        
        decoder.registerReferences(identifiers)
    }
}

// Diffable conformance
extension RelationshipsRenderSection: RenderJSONDiffable {
    /// Returns the differences between this RelationshipsRenderSection and the given one.
    func difference(from other: RelationshipsRenderSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.identifiers, forKey: CodingKeys.identifiers)
        diffBuilder.addDifferences(atKeyPath: \.type, forKey: CodingKeys.type)

        return diffBuilder.differences
    }

    /// Returns if this RelationshipsRenderSection is similar enough to the given one.
    func isSimilar(to other: RelationshipsRenderSection) -> Bool {
        return self.title == other.title
    }
}
