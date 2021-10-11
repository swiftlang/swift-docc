/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A hierarchy tree node that represents a tutorial or a tutorial article.
public struct RenderHierarchyTutorial: Codable {
    /// The topic reference.
    public var reference: RenderReferenceIdentifier
        
    /// The landmarks on the page.
    public var landmarks: [RenderHierarchyLandmark] = []
    
    private enum CodingKeys: String, CodingKey {
        case reference
        case landmarks = "sections"
    }
    
    /// Creates a new tutorial or tutorial article.
    /// - Parameter identifier: The topic reference.
    public init(identifier: RenderReferenceIdentifier) {
        self.reference = identifier
    }
}
