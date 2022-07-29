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
struct AnyRenderReference: Encodable, Equatable, Diffable {
    
    var value: RenderReference & Codable
    init(_ value: RenderReference & Codable) { self.value = value }
    public func difference(from other: AnyRenderReference, at path: Path) -> Differences {
        var differences = Differences()
        // TODO: Fix this CodingKey accessibility issue
        differences.append(contentsOf: propertyDifference(value.identifier,
                                                          from: other.value.identifier,
                                                          at: path + [CustomKey(stringValue: "identifier")])
                           )
                           
        switch (value.type, other.value.type) {
        case (.file, .file):
            let value = value as! FileReference
            let otherValue = other.value as! FileReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.image, .image):
            let value = value as! ImageReference
            let otherValue = other.value as! ImageReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.video, .video):
            let value = value as! VideoReference
            let otherValue = other.value as! VideoReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.fileType, .fileType):
            let value = value as! FileTypeReference
            let otherValue = other.value as! FileTypeReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.xcodeRequirement, .xcodeRequirement):
            let value = value as! XcodeRequirementReference
            let otherValue = other.value as! XcodeRequirementReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.topic, .topic):
            let value = value as! TopicRenderReference
            let otherValue = other.value as! TopicRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.section, .section):
            let value = value as! TopicRenderReference
            let otherValue = other.value as! TopicRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.download, .download):
            let value = value as! DownloadReference
            let otherValue = other.value as! DownloadReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.unresolvable, .unresolvable):
            let value = value as! UnresolvedRenderReference
            let otherValue = other.value as! UnresolvedRenderReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        case (.link, .link):
            let value = value as! LinkReference
            let otherValue = other.value as! LinkReference
            differences.append(contentsOf: value.difference(from: otherValue, at: path))
        default:
            differences.append(.replace(pointer: JSONPointer(from: path), encodableValue: self.value))
        }
        return differences
    }
    
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
    
    func isSimilar(to other: AnyRenderReference) -> Bool {
        self.value.identifier == other.value.identifier
    }
}

/// A coding key with a custom name.
private struct CustomKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init(intValue: Int) {
        self.intValue = intValue
        self.stringValue = intValue.description
    }
    
    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
}
