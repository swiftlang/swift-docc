/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A root node of a tutorials series hierarchy.
public struct RenderTutorialsHierarchy {
    /// The topic reference for the landing page.
    public var reference: RenderReferenceIdentifier
    
    /// The chapters of the technology.
    public var modules: [RenderHierarchyChapter]?

    /// The paths to the current node.
    ///
    /// A list of render reference identifiers.
    public var paths: [[String]]
    
    /// Creates a new root hierarchy node.
    /// - Parameters:
    ///   - reference: The topic reference.
    ///   - paths: The paths to the current node.
    public init(reference: RenderReferenceIdentifier, paths: [[String]]) {
        self.reference = reference
        self.paths = paths
    }
}

// Codable conformance
extension RenderTutorialsHierarchy: Codable {
    private enum CodingKeys: CodingKey {
        case reference
        case modules
        case paths
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        reference = try container.decode(RenderReferenceIdentifier.self, forKey: .reference)
        modules = try container.decodeIfPresent([RenderHierarchyChapter].self, forKey: .modules)
        paths = try container.decode([[String]].self, forKey: .paths)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reference, forKey: .reference)
        try container.encodeIfPresent(modules, forKey: .modules)
        try container.encode(paths, forKey: .paths)
    }
}
