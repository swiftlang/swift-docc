/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


extension RenderInlineContent {
    /// Capitalize the first word for normal text content, as well as content that has emphasis or strong applied.
    func capitalizeFirstWord() -> Self {
        switch self {
        case .text(let text):
            return .text(text.capitalizeFirstWord())
        case .emphasis(inlineContent: let embeddedContent):
            return .emphasis(inlineContent: embeddedContent.capitalizeFirstWord())
        case .strong(inlineContent: let embeddedContent):
            return .strong(inlineContent: embeddedContent.capitalizeFirstWord())
        default:
            return self
        }
    }
}

extension [RenderBlockContent] {
    func capitalizeFirstWord() -> Self {
        guard let first else { return [] }
        
        return [first.capitalizeFirstWord()] + dropFirst()
    }
}

extension [RenderInlineContent] {
    func capitalizeFirstWord() -> Self {
        guard let first else { return [] }
        
        return [first.capitalizeFirstWord()] + dropFirst()
    }
}


extension RenderBlockContent {
    /// Capitalize the first word for paragraphs, asides, headings, and small content.
    func capitalizeFirstWord() -> Self {
        switch self {
        case .paragraph(let paragraph):
            return .paragraph(paragraph.capitalizeFirstWord())
        case .aside(let aside):
            return .aside(aside.capitalizeFirstWord())
        case .small(let small):
            return .small(small.capitalizeFirstWord())
        case .heading(let heading):
            return .heading(.init(level: heading.level, text: heading.text.capitalizeFirstWord(), anchor: heading.anchor))
        default:
            return self
        }
    }
}

extension RenderBlockContent.Paragraph {
    func capitalizeFirstWord() -> RenderBlockContent.Paragraph {
        return .init(inlineContent: inlineContent.capitalizeFirstWord())
    }
}

extension RenderBlockContent.Aside {
    func capitalizeFirstWord() -> RenderBlockContent.Aside {
        return .init(style: self.style, content: self.content.capitalizeFirstWord())
    }
}

extension RenderBlockContent.Small {
    func capitalizeFirstWord() -> RenderBlockContent.Small {
        return .init(inlineContent: self.inlineContent.capitalizeFirstWord())
    }
}

