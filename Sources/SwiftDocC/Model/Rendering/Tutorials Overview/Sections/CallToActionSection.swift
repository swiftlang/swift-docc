/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that prompts the user to perform an action.
public struct CallToActionSection: RenderSection, Equatable {
    public var kind: RenderSectionKind = .callToAction
    
    /// The title of the section.
    public var title: String
    
    /// The abstract to display under the title.
    public var abstract: [RenderInlineContent] = []
    
    /// An intro-style image or video to display under the content.
    public var media: RenderReferenceIdentifier?
    
    /// The content that describe the primary action.
    public var action: RenderInlineContent
    
    /// A short description of the section.
    public var featuredEyebrow: String?
    
    /// Creates a new call-to-action section from the given parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the section.
    ///   - abstract: The content for the section's abstract.
    ///   - media: A reference to a media item.
    ///   - action: The content that describe the primary action.
    ///   - featuredEyebrow: A short description of the section.
    public init(title: String, abstract: [RenderInlineContent], media: RenderReferenceIdentifier?, action: RenderInlineContent, featuredEyebrow: String) {
        self.title = title
        self.abstract = abstract
        self.media = media
        self.action = action
        self.featuredEyebrow = featuredEyebrow
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        media = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .media)
        action = try container.decode(RenderInlineContent.self, forKey: .action)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract) ?? []
        // The featured eyebrow might not be present in older JSON
        featuredEyebrow = try container.decodeIfPresent(String.self, forKey: .featuredEyebrow)
    }
}

// Diffable conformance
extension CallToActionSection: RenderJSONDiffable {
    /// Returns the differences between this CallToActionSection and the given one.
    func difference(from other: CallToActionSection, at path: CodablePath) -> JSONPatchDifferences {
        var diffBuilder = DifferenceBuilder(current: self, other: other, basePath: path)

        diffBuilder.addDifferences(atKeyPath: \.kind, forKey: CodingKeys.kind)
        diffBuilder.addDifferences(atKeyPath: \.title, forKey: CodingKeys.title)
        diffBuilder.addDifferences(atKeyPath: \.abstract, forKey: CodingKeys.abstract)
        diffBuilder.addDifferences(atKeyPath: \.media, forKey: CodingKeys.media)
        diffBuilder.addDifferences(atKeyPath: \.action, forKey: CodingKeys.action)
        diffBuilder.addDifferences(atKeyPath: \.featuredEyebrow, forKey: CodingKeys.featuredEyebrow)

        return diffBuilder.differences
    }

    /// Returns if this CallToActionSection is similar enough to the given one.
    func isSimilar(to other: CallToActionSection) -> Bool {
        return self.title == other.title || self.action == other.action
    }
}
