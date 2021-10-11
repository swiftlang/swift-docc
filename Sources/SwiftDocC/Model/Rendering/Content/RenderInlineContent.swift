/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// An inline content element.
///
/// Typically, a renderer will append inline elements to previous inline elements.
/// Apart from simple content like an image or a piece of plain text,
/// a renderer uses inline elements to style content.
///
/// These elements don't introduce a break in their container's layout flow
/// like ``RenderBlockContent`` elements do.
///
/// ```
/// [ Paragraph
///    [Text] [Strong [Text]] [Text] [Emphasize [Reference]] ...
/// ]
/// - - - - - - - -
/// [ Paragraph
///   ...
/// ]
/// ```
///
/// Inline elements can be nested, for example, an inline piece of text can be wrapped in an emphasis element.
/// Block elements cannot be nested in inline elements.
public enum RenderInlineContent: Equatable {
    /// A piece of code like a variable name or a single operator.
    case codeVoice(code: String)
    /// An emphasized piece of inline content.
    case emphasis(inlineContent: [RenderInlineContent])
    /// A strongly emphasized piece of inline content.
    case strong(inlineContent: [RenderInlineContent])
    /// An image element.
    case image(identifier: RenderReferenceIdentifier, metadata: RenderContentMetadata?)
    
    /// A reference to another resource.
    case reference(identifier: RenderReferenceIdentifier, isActive: Bool, overridingTitle: String?, overridingTitleInlineContent: [RenderInlineContent]?)
    /// A piece of plain text.
    case text(String)
    
    /// A piece of content that introduces a new term.
    case newTerm(inlineContent: [RenderInlineContent])
    /// An inline heading.
    case inlineHead(inlineContent: [RenderInlineContent])
    /// A subscript piece of content.
    case `subscript`(inlineContent: [RenderInlineContent])
    /// A superscript piece of content.
    case superscript(inlineContent: [RenderInlineContent])
    /// A strikethrough piece of content.
    case strikethrough(inlineContent: [RenderInlineContent])
}

// Codable conformance
extension RenderInlineContent: Codable {
    private enum InlineType: String, Codable {
        case codeVoice, emphasis, strong, image, reference, text, newTerm, inlineHead, `subscript`, superscript, strikethrough
    }
    
    private enum CodingKeys: CodingKey {
        case type, code, inlineContent, identifier, title, destination, text, isActive, overridingTitle, overridingTitleInlineContent, metadata
    }
    
    private var type: InlineType {
        switch self {
        case .codeVoice: return .codeVoice
        case .emphasis: return .emphasis
        case .strong: return .strong
        case .image: return .image
        case .reference: return .reference
        case .text: return .text
        case .subscript: return .subscript
        case .superscript: return .superscript
        case .newTerm: return .newTerm
        case .inlineHead: return .inlineHead
        case .strikethrough: return .strikethrough
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(InlineType.self, forKey: .type)
        switch type {
        case .codeVoice:
            self = try .codeVoice(code: container.decode(String.self, forKey: .code))
        case .emphasis:
            self = try .emphasis(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .strong:
            self = try .strong(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .image:
            self = try .image(
                identifier: container.decode(RenderReferenceIdentifier.self, forKey: . identifier),
                metadata: container.decodeIfPresent(RenderContentMetadata.self, forKey: .metadata)
            )
        case .reference:
            let identifier = try container.decode(RenderReferenceIdentifier.self, forKey: .identifier)
            let overridingTitle: String?
            let overridingTitleInlineContent: [RenderInlineContent]?
            
            if let formattedOverridingTitle = try container.decodeIfPresent([RenderInlineContent].self, forKey: .overridingTitleInlineContent) {
                overridingTitleInlineContent = formattedOverridingTitle
                overridingTitle = try container.decodeIfPresent(String.self, forKey: .overridingTitle) ?? formattedOverridingTitle.plainText
            } else if let plainTextOverridingTitle = try container.decodeIfPresent(String.self, forKey: .overridingTitle) {
                overridingTitleInlineContent = [.text(plainTextOverridingTitle)]
                overridingTitle = plainTextOverridingTitle
            } else {
                overridingTitleInlineContent = nil
                overridingTitle = nil
            }

            self = try .reference(identifier: identifier,
                                  isActive: container.decode(Bool.self, forKey: .isActive),
                                  overridingTitle: overridingTitle,
                                  overridingTitleInlineContent: overridingTitleInlineContent)
            decoder.registerReferences([identifier.identifier])
        case .text:
            self = try .text(container.decode(String.self, forKey: .text))
        case .newTerm:
            self = try .newTerm(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .inlineHead:
            self = try .inlineHead(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .subscript:
            self = try .subscript(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .superscript:
            self = try .superscript(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .strikethrough:
            self = try .strikethrough(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch self {
        case .codeVoice(let code):
            try container.encode(code, forKey: .code)
        case .emphasis(let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .strong(let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .image(let identifier, let metadata):
            try container.encode(identifier, forKey: .identifier)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        case .reference(let identifier, let isActive, let overridingTitle, let overridingTitleInlineContent):
            try container.encode(identifier, forKey: .identifier)
            try container.encode(isActive, forKey: .isActive)
            try container.encodeIfPresent(overridingTitle, forKey: .overridingTitle)
            try container.encodeIfPresent(overridingTitleInlineContent, forKey: .overridingTitleInlineContent)
        case .text(let text):
            try container.encode(text, forKey: .text)
        case .newTerm(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .inlineHead(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .subscript(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .superscript(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .strikethrough(inlineContent: let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        }
    }
}

// Plain text extraction
extension RenderInlineContent {
    /// Returns a lossy conversion of the formatted content to a plain-text string.
    ///
    /// This implementation is necessarily limited because it doesn't make
    /// use of any collected `RenderReference` items. In many cases, it may make
    /// more sense to use the `rawIndexableTextContent` function that does use `RenderReference`
    /// for a more accurate textual representation of `RenderInlineContent.image` and
    /// `RenderInlineContent.reference`.
    var plainText: String {
        switch self {
        case let .codeVoice(code):
            return code
        case let .emphasis(inlineContent):
            return inlineContent.plainText
        case let .strong(inlineContent):
            return inlineContent.plainText
        case let .image(_, metadata):
            return (metadata?.abstract?.plainText) ?? ""
        case let .reference(_, _, overridingTitle, overridingTitleInlineContent):
            return overridingTitle ?? overridingTitleInlineContent?.plainText ?? ""
        case let .text(text):
            return text
        case let .newTerm(inlineContent):
            return inlineContent.plainText
        case let .inlineHead(inlineContent):
            return inlineContent.plainText
        case let .subscript(inlineContent):
            return inlineContent.plainText
        case let .superscript(inlineContent):
            return inlineContent.plainText
        case let .strikethrough(inlineContent):
            return inlineContent.plainText
        }
    }
}

// Plain text extraction
extension Sequence where Element == RenderInlineContent {
    /// Returns a lossy conversion of the formatted content to a plain-text string.
    ///
    /// This implementation is necessarily limited because it doesn't make
    /// use of any collected `RenderReference` items. In many cases, it may make
    /// more sense to use the `rawIndexableTextContent` function that does use `RenderReference`
    /// for a more accurate textual representation of `RenderInlineContent.image` and
    /// `RenderInlineContent.reference`.
    var plainText: String {
        return map { $0.plainText }.joined()
    }
}
