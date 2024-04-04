//
//  RenderBlockContent+Capitalization.swift
//  
//
//  Created by Emily Chen on 04/04/2024.
//

protocol AutoCapitalizable {
    
    /// Any type that conforms to this protocol  needs to have this property
    var capitalizeFirstWord: Self {
        get
    }
    
}

extension AutoCapitalizable {
    var capitalizeFirstWord: Self { return self }
}

extension RenderInlineContent: AutoCapitalizable {
    // Capitalize the first word for content that has emphasis or strong applied as well as normal text.
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

