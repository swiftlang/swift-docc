/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A hierarchy tree node that represents a chapter in a tutorial series.
public struct RenderHierarchyChapter: Codable {    
    /// The topic reference for the chapter.
    public var reference: RenderReferenceIdentifier
    
    /// The tutorials in the chapter.
    public var tutorials: [RenderHierarchyTutorial] = []
    
    /// Creates a new hierarchy chapter.
    /// - Parameter identifier: The topic reference for the chapter.
    public init(identifier: RenderReferenceIdentifier) {
        self.reference = identifier
    }
    
    enum CodingKeys: String, CodingKey {
        case reference
        // Both "tutorials" and "projects" correspond to the
        // same `tutorials` property for legacy reasons.
        case tutorials, projects
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.reference = try container.decode(RenderReferenceIdentifier.self, forKey: .reference)
        // Decode using the new key if its present, otherwise decode using the previous key
        let tutorialsKey = container.contains(.tutorials) ? CodingKeys.tutorials : CodingKeys.projects
        self.tutorials = try container.decode([RenderHierarchyTutorial].self, forKey: tutorialsKey)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(reference, forKey: .reference)
        try container.encode(tutorials, forKey: .projects) // Encode using the previous key for compatibility
    }
}

