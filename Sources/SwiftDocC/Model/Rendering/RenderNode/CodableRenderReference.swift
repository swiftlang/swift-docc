/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

/// A Codable container for a render node reference.
struct CodableRenderReference: Codable {
    var reference: RenderReference
    
    init(_ reference: RenderReference) {
        self.reference = reference
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(RenderReferenceType.self, forKey: .type)
        
        switch type {
        case .image:
            reference = try ImageReference(from: decoder)
        case .video:
            reference = try VideoReference(from: decoder)
        case .file:
            reference = try FileReference(from: decoder)
        case .fileType:
            reference = try FileTypeReference(from: decoder)
        case .xcodeRequirement:
            reference = try XcodeRequirementReference(from: decoder)
        case .topic:
            reference = try TopicRenderReference(from: decoder)
        case .section:
            reference = try TopicRenderReference(from: decoder)
        case .download:
            reference = try DownloadReference(from: decoder)
        case .unresolvable:
            reference = try UnresolvedRenderReference(from: decoder)
        case .link:
            reference = try LinkReference(from: decoder)
        }
    }
    
    private enum CodingKeys: CodingKey {
        case type
    }
    
    func encode(to encoder: Encoder) throws {
        try reference.encode(to: encoder)
    }
}
