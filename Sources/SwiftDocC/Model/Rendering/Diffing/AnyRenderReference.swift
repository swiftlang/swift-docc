/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// A RenderReference value that can be diffed.
///
/// An `AnyRenderReference` value forwards difference operations to the underlying base type, which implement the difference differently.
struct AnyRenderReference: Encodable, Equatable, RenderJSONDiffable {
    var value: RenderReference & Codable
    
    init(_ value: RenderReference & Codable) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
    
    /// Forwards the difference methods on to the correct concrete type.
    func difference(from other: AnyRenderReference, at path: CodablePath) -> JSONPatchDifferences {
        switch (self.value.type, other.value.type) {
            
        // MARK: References
            
        case (.file, .file):
            return (value as! FileReference).difference(from: (other.value as! FileReference), at: path)
        case (.fileType, .fileType):
            return (value as! FileTypeReference).difference(from: (other.value as! FileTypeReference), at: path)
        case (.image, .image):
            return (value as! ImageReference).difference(from: (other.value as! ImageReference), at: path)
        case (.link, .link):
            return (value as! LinkReference).difference(from: (other.value as! LinkReference), at: path)
        case (.section, .section), (.topic, .topic):
            return (value as! TopicRenderReference).difference(from: (other.value as! TopicRenderReference), at: path)
        case (.unresolvable, .unresolvable):
            return (value as! UnresolvedRenderReference).difference(from: (other.value as! UnresolvedRenderReference), at: path)
        case (.video, .video):
            return (value as! VideoReference).difference(from: (other.value as! VideoReference), at: path)
            
        // MARK: Tutorial References
            
        case (.download, .download):
            return (value as! DownloadReference).difference(from: (other.value as! DownloadReference), at: path)
        case (.xcodeRequirement, .xcodeRequirement):
            return (value as! XcodeRequirementReference).difference(from: (other.value as! XcodeRequirementReference), at: path)
            
        default:
            assertionFailure("Case diffing \(value) with \(other.value) is not implemented.")
            return []
        }
    }

    static func == (lhs: AnyRenderReference, rhs: AnyRenderReference) -> Bool {
        switch (lhs.value.type, rhs.value.type) {
            
        // MARK: References
          
        case (.file, .file):
            return (lhs.value as! FileReference) == (rhs.value as! FileReference)
        case (.fileType, .fileType):
            return (lhs.value as! FileTypeReference) == (rhs.value as! FileTypeReference)
        case (.image, .image):
            return (lhs.value as! ImageReference) == (rhs.value as! ImageReference)
        case (.link, .link):
            return (lhs.value as! LinkReference) == (rhs.value as! LinkReference)
        case (.section, .section), (.topic, .topic):
            return (lhs.value as! TopicRenderReference) == (rhs.value as! TopicRenderReference)
        case (.unresolvable, .unresolvable):
            return (lhs.value as! UnresolvedRenderReference) == (rhs.value as! UnresolvedRenderReference)
        case (.video, .video):
            return (lhs.value as! VideoReference) == (rhs.value as! VideoReference)
        
        // MARK: Tutorial References
            
        case (.download, .download):
            return (lhs.value as! DownloadReference) == (rhs.value as! DownloadReference)
        case (.xcodeRequirement, .xcodeRequirement):
            return (lhs.value as! XcodeRequirementReference) == (rhs.value as! XcodeRequirementReference)
        
        default:
            assertionFailure("Case diffing \(lhs.value) with \(rhs.value) is not implemented.")
            return false
        }
    }
    
    func isSimilar(to other: AnyRenderReference) -> Bool {
        return self.value.identifier == other.value.identifier
    }
}
