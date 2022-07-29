/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderNode: Diffable {
    func isSimilar(to other: RenderNode) -> Bool {
        return identifier == other.identifier
    }
    
    /// Returns the differences between this render node and the given one.
    public func difference(from other: RenderNode, at path: Path) -> Differences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.schemaVersion, forKey: CodingKeys.schemaVersion)
        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)
        diffBuilder.differences.append(contentsOf: metadata.difference(from: other.metadata, at: path + [CodingKeys.metadata])) // RenderMetadata isn't Equatable
        diffBuilder.addDifferences(atKeyPath: \.hierarchy, forKey: CodingKeys.hierarchy)
        diffBuilder.addDifferences(atKeyPath: \.topicSections, forKey: CodingKeys.topicSections)
        diffBuilder.addDifferences(atKeyPath: \.seeAlsoSections, forKey: CodingKeys.seeAlsoSections)
        diffBuilder.addDifferences(atKeyPath: \.references, forKey: CodingKeys.references)
        diffBuilder.addDifferences(atKeyPath: \.primaryContentSections, forKey: CodingKeys.primaryContentSections)
        diffBuilder.addDifferences(atKeyPath: \.relationshipSections, forKey: CodingKeys.relationshipsSections)
        diffBuilder.addDifferences(atKeyPath: \.sections, forKey: CodingKeys.sections)
        
        return diffBuilder.differences
    }
}
