/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

public import Foundation

/// A reference to a version of Xcode that users of your documentation must use.
public struct XcodeRequirementReference: RenderReference, Equatable {
    public var type: RenderReferenceType = .xcodeRequirement
    
    public let identifier: RenderReferenceIdentifier
    
    /// A presentation-friendly title for the version of Xcode required for users of your documentation.
    public let title: String
    
    /// A download URL for the version of Xcode required for users of your documentation.
    public let url: URL
    
    /// Creates a reference to a version of Xcode that users of your documentation must use.
    ///
    /// - Parameters:
    ///   - identifier: An identifier for the requirement's reference
    ///   - title: The Xcode version title.
    ///   - url: A download URL for the Xcode version.
    public init(identifier: RenderReferenceIdentifier, title: String, url: URL) {
        self.identifier = identifier
        self.title = title
        self.url = url
    }
}

// Diffable conformance
extension XcodeRequirementReference: RenderJSONDiffable {
    /// Returns the difference between this XcodeRequirementReference and the given one.
    func difference(from other: XcodeRequirementReference, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.type, forKey: CodingKeys.type)
        diffBuilder.addDifferences(atKeyPath: \.identifier, forKey: CodingKeys.identifier)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.url, forKey: CodingKeys.url)

        return diffBuilder.differences
    }
}
