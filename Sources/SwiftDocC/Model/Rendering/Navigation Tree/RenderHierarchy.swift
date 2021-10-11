/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// Hierarchical information for a render node.
///
/// A render node's hierarchy information, such as its parent topics,
/// describes an API reference hierarchy that starts with a framework
/// landing page, or a Tutorials hierarchy that starts with a Tutorials landing page.
/// ## Topics
/// ### Hierarchy Types
/// - ``RenderReferenceHierarchy``
/// - ``RenderTutorialsHierarchy``
public enum RenderHierarchy: Codable {
    /// The hierarchy for an API reference render node.
    case reference(RenderReferenceHierarchy)
    /// The hierarchy for tutorials-related render node.
    case tutorials(RenderTutorialsHierarchy)

    public init(from decoder: Decoder) throws {
        if let tutorialsHierarchy = try? RenderTutorialsHierarchy(from: decoder) {
            self = .tutorials(tutorialsHierarchy)
            decoder.registerReferences(tutorialsHierarchy.paths.flatMap { $0 })
            return
        }
        
        let referenceHierarchy = try RenderReferenceHierarchy(from: decoder)
        self = .reference(referenceHierarchy)
        decoder.registerReferences(referenceHierarchy.paths.flatMap { $0 })
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .reference(let hierarchy):
            try container.encode(hierarchy)
        case .tutorials(let hierarchy):
            try container.encode(hierarchy)
        }
    }
}
