/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderNode: RenderJSONDiffable {
    
    /// Returns the differences between this RenderNode and the given one.
    public func difference(from other: RenderNode) -> JSONPatchDifferences {
        self.difference(from: other, at: [])
    }
    
    func difference(from other: RenderNode, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)
        
        // MARK: General
                
        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)
        diffBuilder.addDifferences(atKeyPath: \.schemaVersion, forKey: CodingKeys.schemaVersion)
        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.sections, forKey: CodingKeys.sections)
        diffBuilder.addDifferences(atKeyPath: \.references, forKey: CodingKeys.references)
        diffBuilder.addDifferences(atKeyPath: \.hierarchy, forKey: CodingKeys.hierarchy)
        diffBuilder.differences.append(contentsOf: metadata.difference(from: other.metadata, at: path + [CodingKeys.metadata])) // RenderMetadata isn't Equatable
        
        // MARK: Reference Documentation Data
        
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.primaryContentSections, forKey: CodingKeys.primaryContentSections)
        diffBuilder.addDifferences(atKeyPath: \.topicSectionsStyle, forKey: CodingKeys.topicSectionsStyle)
        diffBuilder.addDifferences(atKeyPath: \.topicSections, forKey: CodingKeys.topicSections)
        diffBuilder.addDifferences(atKeyPath: \.relationshipSections, forKey: CodingKeys.relationshipsSections)
        diffBuilder.addDifferences(atKeyPath: \.defaultImplementationsSections, forKey: CodingKeys.defaultImplementationsSections)
        diffBuilder.addDifferences(atKeyPath: \.seeAlsoSections, forKey: CodingKeys.seeAlsoSections)
        diffBuilder.addDifferences(atKeyPath: \.deprecationSummary, forKey: CodingKeys.deprecationSummary)
        diffBuilder.addDifferences(atKeyPath: \.variants, forKey: CodingKeys.variants)
        diffBuilder.addDifferences(atKeyPath: \.diffAvailability, forKey: CodingKeys.diffAvailability)

        // MARK: Sample Code Data
        
        diffBuilder.addDifferences(atKeyPath: \.sampleDownload, forKey: CodingKeys.sampleCodeDownload)
        diffBuilder.addDifferences(atKeyPath: \.downloadNotAvailableSummary, forKey: CodingKeys.downloadNotAvailableSummary)
        
        return diffBuilder.differences
    }
    
    func isSimilar(to other: RenderNode) -> Bool {
        return identifier == other.identifier
    }
}
