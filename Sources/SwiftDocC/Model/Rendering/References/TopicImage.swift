/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A custom authored image that can be associated with a documentation topic.
///
/// Allows an author to provide a custom icon or card image for a given documentation page.
public struct TopicImage: Codable, Hashable {
    /// The type of this topic image.
    public let type: TopicImageType
    
    /// The reference identifier for the image.
    public let identifier: RenderReferenceIdentifier
    
    /// Create a new topic image with the given type and reference identifier.
    public init(
        type: TopicImage.TopicImageType,
        identifier: RenderReferenceIdentifier
    ) {
        self.type = type
        self.identifier = identifier
    }
}

extension TopicImage {
    /// The type of topic image.
    public enum TopicImageType: String, Codable, Hashable {
        /// An icon image that should be used to represent this page wherever a default icon
        /// is currently used.
        case icon
        
        /// An icon image that should be used to represent this page wherever a default icon
        /// is currently used.
        case card
    }
}

extension TopicImage {
    init(
        pageImagePurpose purpose: PageImage.Purpose,
        identifier: RenderReferenceIdentifier
    ) {
        let type: TopicImage.TopicImageType
        switch purpose {
        case .card:
            type = .card
        case .icon:
            type = .icon
        }
        
        self.init(type: type, identifier: identifier)
    }
    
    init?(
        pageImage: PageImage,
        with context: DocumentationContext,
        in parent: ResolvedTopicReference
    ) {
        guard let identifier = context.identifier(
            forAssetName: pageImage.source.path,
            in: parent
        ) else {
            return nil
        }
        
        self.init(
            pageImagePurpose: pageImage.purpose,
            identifier: RenderReferenceIdentifier(identifier)
        )
    }
    
}

extension RenderNode {
    var icon: RenderReferenceIdentifier? {
        return metadata.images.first { image in
            image.type == .icon
        }?.identifier
    }
}
