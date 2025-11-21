/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/


extension RenderInlineContent {
    /// Capitalize the first word for normal text content, as well as content that has emphasis or strong applied.
    func capitalizingFirstWord() -> Self {
        switch self {
        case .text(let text):
            return .text(text.capitalizingFirstWord())
        case .emphasis(inlineContent: let embeddedContent):
            return .emphasis(inlineContent: embeddedContent.capitalizingFirstWord())
        case .strong(inlineContent: let embeddedContent):
            return .strong(inlineContent: embeddedContent.capitalizingFirstWord())
        default:
            return self
        }
    }
}

extension [RenderBlockContent] {
    func capitalizingFirstWord() -> Self {
        guard let first else { return [] }
        
        return [first.capitalizingFirstWord()] + dropFirst()
    }
}

extension [RenderInlineContent] {
    func capitalizingFirstWord() -> Self {
        guard let first else { return [] }
        
        return [first.capitalizingFirstWord()] + dropFirst()
    }
}


extension RenderBlockContent {
    /// Capitalize the first word for paragraphs, asides, headings, and small content.
    func capitalizingFirstWord() -> Self {
        switch self {
        case .paragraph(let paragraph):
            return .paragraph(paragraph.capitalizingFirstWord())
        case .aside(let aside):
            return .aside(aside.capitalizingFirstWord())
        case .small(let small):
            return .small(small.capitalizingFirstWord())
        case .heading(let heading):
            return .heading(.init(level: heading.level, text: heading.text.capitalizingFirstWord(), anchor: heading.anchor))
        default:
            return self
        }
    }
}

extension RenderBlockContent.Paragraph {
    func capitalizingFirstWord() -> RenderBlockContent.Paragraph {
        return .init(inlineContent: inlineContent.capitalizingFirstWord())
    }
}

extension RenderBlockContent.Aside {
    func capitalizingFirstWord() -> RenderBlockContent.Aside {
        return .init(style: self.style, name: self.name, content: self.content.capitalizingFirstWord())
    }
}

extension RenderBlockContent.Small {
    func capitalizingFirstWord() -> RenderBlockContent.Small {
        return .init(inlineContent: self.inlineContent.capitalizingFirstWord())
    }
}

