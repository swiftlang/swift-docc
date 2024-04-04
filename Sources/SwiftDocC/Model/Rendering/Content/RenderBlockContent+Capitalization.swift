/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// For auto capitalizing the first letter of a sentence following a colon (e.g. asides, sections such as parameters, returns).
protocol AutoCapitalizable {
    
    /// Any type that conforms to this protocol needs to have this property.
    var capitalizeFirstWord: Self {
        get
    }
    
}

extension AutoCapitalizable {
    var capitalizeFirstWord: Self { return self }
}

extension RenderInlineContent: AutoCapitalizable {
    /// Capitalize the first word for normal text content, as well as content that has emphasis or strong applied.
    var capitalizeFirstWord: Self {
        switch self {
        case .text(let text):
            return .text(text.capitalizeFirstWord)
        case .emphasis(inlineContent: let embeddedContent):
            return .emphasis(inlineContent: embeddedContent.map(\.capitalizeFirstWord))
        case .strong(inlineContent: let embeddedContent):
            return .strong(inlineContent: embeddedContent.map(\.capitalizeFirstWord))
        default:
            return self
        }
    }
}


extension RenderBlockContent: AutoCapitalizable {
    /// Capitalize the first word for paragraphs, asides, and small content.
    var capitalizeFirstWord: Self {
        switch self {
        case .paragraph(let paragraph):
            return .paragraph(paragraph.capitalizeFirstWord)
        case .aside(let aside):
            return .aside(aside.capitalizeFirstWord)
        case .small(let small):
            return .small(small.capitalizeFirstWord)
        default:
            return self
        }
    }
}

extension RenderBlockContent.Paragraph: AutoCapitalizable {
    var capitalizeFirstWord: RenderBlockContent.Paragraph {
        let inlineContent = [self.inlineContent[0].capitalizeFirstWord] + self.inlineContent[1...]
        return .init(inlineContent: inlineContent)
    }
}

extension RenderBlockContent.Aside: AutoCapitalizable {
    var capitalizeFirstWord: RenderBlockContent.Aside {
        let content = [self.content[0].capitalizeFirstWord] + self.content[1...]
        return .init(style: self.style, content: content)
    }
}

extension RenderBlockContent.Small: AutoCapitalizable {
    var capitalizeFirstWord: RenderBlockContent.Small {
        let inlineContent = [self.inlineContent[0].capitalizeFirstWord] + self.inlineContent[1...]
        return .init(inlineContent: inlineContent)
    }
}

