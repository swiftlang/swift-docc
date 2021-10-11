/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/**
    This transformation removes the hierarchy information from a render node JSON,
    also getting rid of the dead references. It's useful to save space when the
    hierarchy information is not a key information to preserve.
*/
public struct RemoveHierarchyTransformation: RenderNodeTransforming {
    public init() {}

    public func transform(renderNode: RenderNode, context: RenderNodeTransformationContext)
        -> RenderNodeTransformationResult {
        var (renderNode, context) = (renderNode, context)
        
        let identifiersInHierarchy: [String] = {
            switch renderNode.hierarchy {
            case .reference(let reference):
                return reference.paths.flatMap { $0 }
            case .tutorials(let tutorial):
                return tutorial.paths.flatMap { $0 }
            case .none:
                return []
            }
        }()
        
        // Remove hierarchy.
        renderNode.hierarchy = nil

        // Remove unused references.
        for identifier in identifiersInHierarchy {
            context.referencesCount[identifier]? -= 1
        }

        return (renderNode, context)
    }
}
