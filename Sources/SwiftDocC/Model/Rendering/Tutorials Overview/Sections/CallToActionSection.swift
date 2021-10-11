/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A section that prompts the user to perform an action.
public struct CallToActionSection: RenderSection {
    public var kind: RenderSectionKind = .callToAction
    
    /// The title of the section.
    public var title: String
    
    /// The abstract to display under the title.
    public var abstract: [RenderInlineContent] = []
    
    /// An intro-style image or video to display under the content.
    public var media: RenderReferenceIdentifier?
    
    /// The primary action to perform.
    public var action: RenderInlineContent
    
    /// A short description of the section.
    public var featuredEyebrow: String?
    
    /// Creates a new call-to-action section from the given parameters.
    ///
    /// - Parameters:
    ///   - title: The title of the section.
    ///   - abstract: The content for the section's abstract.
    ///   - media: A reference to a media item.
    ///   - featuredEyebrow: A short description of the section.
    public init(title: String, abstract: [RenderInlineContent], media: RenderReferenceIdentifier?, action: RenderInlineContent, featuredEyebrow: String) {
        self.title = title
        self.abstract = abstract
        self.media = media
        self.action = action
        self.featuredEyebrow = featuredEyebrow
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        media = try container.decodeIfPresent(RenderReferenceIdentifier.self, forKey: .media)
        action = try container.decode(RenderInlineContent.self, forKey: .action)
        abstract = try container.decodeIfPresent([RenderInlineContent].self, forKey: .abstract) ?? []
        // The featured eyebrow might not be present in older JSON
        featuredEyebrow = try container.decodeIfPresent(String.self, forKey: .featuredEyebrow)
    }
}
