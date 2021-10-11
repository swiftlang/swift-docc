/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A transformation that removes automatically curated See Also sections.
public struct RemoveAutomaticallyCuratedSeeAlsoSectionsTransformation: RenderNodeTransforming {
    /// Creates a new transformer.
    public init() {}
    
    /// Removes automatically curated See Also sections from the given render node.
    ///
    /// Applying this transformation will also decrease the reference count in the returned transformation context
    /// for all the references in the removed See Also sections.
    ///
    /// - Parameters:
    ///   - renderNode: The render node from which this transformation removes automatically curated See Also sections.
    ///   - context: The context that tracks the number of times each reference is referenced in the render node's content.
    /// - Returns: The transformed render node and context with updated reference counts.
    public func transform(renderNode: RenderNode, context: RenderNodeTransformationContext)
        -> RenderNodeTransformationResult {
        var (renderNode, context) = (renderNode, context)
        // Remove automatically curated See Also sections.
        let generatedIndex = renderNode.seeAlsoSections.partition { $0.generated }
        let generatedSeeAlsoSections = renderNode.seeAlsoSections[generatedIndex...]
        let authoredSeeAlsoSections = renderNode.seeAlsoSections[..<generatedIndex]

        renderNode.seeAlsoSections = Array(authoredSeeAlsoSections)

        // Remove unused references.
        for generatedSeeAlsoSection in generatedSeeAlsoSections {
            for identifier in generatedSeeAlsoSection.identifiers {
                context.referencesCount[identifier]? -= 1
            }
        }

        return (renderNode, context)
    }
}
