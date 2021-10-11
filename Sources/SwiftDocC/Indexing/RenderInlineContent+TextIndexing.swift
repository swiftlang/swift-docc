/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderInlineContent: TextIndexing {
    public var headings: [String] {
        return []
    }

    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        switch self {
        case let .emphasis(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .strong(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .text(string):
            return string
        case let .codeVoice(string):
            return string
        case .image(_, let metadata):
            return metadata?.rawIndexableTextContent(references: references) ?? ""
        case let .reference(identifier, _, overridingTitle, overridingTitleInlineContent):
            if let overridingTitleInlineContent = overridingTitleInlineContent {
                return overridingTitleInlineContent.rawIndexableTextContent(references: references)
            } else if let overridingTitle = overridingTitle {
                return overridingTitle
            } else if let reference = references[identifier.identifier] as? TopicRenderReference {
                return reference.title
            } else if let imageReference = references[identifier.identifier] as? ImageReference {
                return imageReference.altText ?? ""
            } else if let videoReference = references[identifier.identifier] as? VideoReference {
                return videoReference.altText ?? ""
            } else if let linkReference = references[identifier.identifier] as? LinkReference {
                return linkReference.titleInlineContent.rawIndexableTextContent(references: references)
            } else {
                return ""
            }
        case let .newTerm(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .inlineHead(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .subscript(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .superscript(inlines):
            return inlines.rawIndexableTextContent(references: references)
        case let .strikethrough(inlines):
            return inlines.rawIndexableTextContent(references: references)
        }
    }
}
