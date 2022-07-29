/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A RenderReference value that can be diffed.
///
/// An `AnyRenderReference` value forwards difference operations to the underlying base type, which implement the difference differently.
struct AnyRenderReference: Encodable, Equatable {
    
    var value: RenderReference & Codable
    init(_ value: RenderReference & Codable) { self.value = value }
    
    static func == (lhs: AnyRenderReference, rhs: AnyRenderReference) -> Bool {
        switch (lhs.value.type, rhs.value.type) {
        case (.file, .file):
            return (lhs.value as! FileReference) == (rhs.value as! FileReference)
        case (.image, .image):
            return (lhs.value as! ImageReference) == (rhs.value as! ImageReference)
        case (.video, .video):
            return (lhs.value as! VideoReference) == (rhs.value as! VideoReference)
        case (.fileType, .fileType):
            return (lhs.value as! FileTypeReference) == (rhs.value as! FileTypeReference)
        case (.xcodeRequirement, .xcodeRequirement):
            return (lhs.value as! XcodeRequirementReference) == (rhs.value as! XcodeRequirementReference)
        case (.topic, .topic):
            return (lhs.value as! TopicRenderReference) == (rhs.value as! TopicRenderReference)
        case (.section, .section):
            return (lhs.value as! TopicRenderReference) == (rhs.value as! TopicRenderReference)
        case (.download, .download):
            return (lhs.value as! DownloadReference) == (rhs.value as! DownloadReference)
        case (.unresolvable, .unresolvable):
            return (lhs.value as! UnresolvedRenderReference) == (rhs.value as! UnresolvedRenderReference)
        case (.link, .link):
            return (lhs.value as! LinkReference) == (rhs.value as! LinkReference)
        default:
            return false
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

