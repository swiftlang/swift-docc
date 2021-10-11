/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A hierarchy tree node that represents a landmark on a page.
public struct RenderHierarchyLandmark: Codable {
    /// The kind of a landmark.
    public enum Kind: String, Codable {
        /// A landmark at the start of a task.
        case task
        /// A landmark at the start of an assessment.
        case assessment
        /// A landmark to a heading in the content.
        case heading
    }
    
    /// The topic reference for the landmark.
    public var reference: RenderReferenceIdentifier
    
    /// The kind of landmark.
    public var kind: Kind
    
    /// Creates a new hierarchy landmark.
    /// - Parameters:
    ///   - reference: The topic reference for the landmark.
    ///   - kind: The kind of landmark.
    public init(reference: RenderReferenceIdentifier, kind: Kind) {
        self.reference = reference
        self.kind = kind
    }
}
