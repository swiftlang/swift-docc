/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

/// For auto capitalizing the first letter of a sentence following a colon (e.g. asides, sections such as parameters, returns).
protocol AutoCapitalizable {
    
    /// Any type that conforms to the AutoCapitalizable protocol will have the first letter of the first word capitalized (if applicable).
    var withFirstWordCapitalized: Self {
        get
    }
    
}

extension AutoCapitalizable {
    var withFirstWordCapitalized: Self { return self }
}

extension RenderInlineContent: AutoCapitalizable {
    /// Capitalize the first word for normal text content, as well as content that has emphasis or strong applied.
    var withFirstWordCapitalized: Self {
        switch self {
        case .text(let text):
            return .text(text.capitalizeFirstWord())
        case .emphasis(inlineContent: let embeddedContent):
            return .emphasis(inlineContent: [embeddedContent[0].withFirstWordCapitalized] + embeddedContent[1...])
        case .strong(inlineContent: let embeddedContent):
            return .strong(inlineContent: [embeddedContent[0].withFirstWordCapitalized] + embeddedContent[1...])
        default:
            return self
        }
    }
}


extension RenderBlockContent: AutoCapitalizable {
    /// Capitalize the first word for paragraphs, asides, headings, and small content.
    var withFirstWordCapitalized: Self {
        switch self {
        case .paragraph(let paragraph):
            return .paragraph(paragraph.withFirstWordCapitalized)
        case .aside(let aside):
            return .aside(aside.withFirstWordCapitalized)
        case .small(let small):
            return .small(small.withFirstWordCapitalized)
        case .heading(let heading):
            return .heading(.init(level: heading.level, text: heading.text.capitalizeFirstWord(), anchor: heading.anchor))
        default:
            return self
        }
    }
}

extension RenderBlockContent.Paragraph: AutoCapitalizable {
    var withFirstWordCapitalized: RenderBlockContent.Paragraph {
        guard !self.inlineContent.isEmpty else {
            return self
        }
        
        let inlineContent = [self.inlineContent[0].withFirstWordCapitalized] + self.inlineContent[1...]
        return .init(inlineContent: inlineContent)
    }
}

extension RenderBlockContent.Aside: AutoCapitalizable {
    var withFirstWordCapitalized: RenderBlockContent.Aside {
        guard !self.content.isEmpty else {
            return self
        }
        
        let content = [self.content[0].withFirstWordCapitalized] + self.content[1...]
        return .init(style: self.style, content: content)
    }
}

extension RenderBlockContent.Small: AutoCapitalizable {
    var withFirstWordCapitalized: RenderBlockContent.Small {
        guard !self.inlineContent.isEmpty else {
            return self
        }
        
        let inlineContent = [self.inlineContent[0].withFirstWordCapitalized] + self.inlineContent[1...]
        return .init(inlineContent: inlineContent)
    }
}

