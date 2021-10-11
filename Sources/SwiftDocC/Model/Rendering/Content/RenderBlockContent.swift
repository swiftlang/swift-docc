/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Markdown

/// A block content element.
///
/// Block elements introduce a break in their container's layout flow, and
/// usually represent a discrete item of their parent's content.
///
/// Historically, the name "block element" comes from rendering scrollable, vertical content.
/// A block element introduced a break in the horizontal flow, was preceded
/// with an empty new line, and took the whole width, which started a new horizontal flow.
/// These are headings, paragraphs, tables, and more.
///
/// ```
/// [ Paragraph ...    ]
/// - - - - - - - - - -
/// [ Aside Note ...   ]
/// - - - - - - - - - -
/// [ Code Listing ... ]
/// - - - - - - - - - - 
/// [ Paragraph ...    ]
/// ```
///
/// `RenderBlockContent` contains traditional elements like ``paragraph(inlineContent:)`` and
/// ``heading(level:text:anchor:)`` but also other documentation-specific elements like
/// ``step(content:caption:media:code:runtimePreview:)`` and ``endpointExample(summary:request:response:)``.
///
/// Block elements can be nested, for example, an aside note contains one or more paragraphs of text.
public enum RenderBlockContent: Equatable {
    /// A paragraph of content.
    case paragraph(inlineContent: [RenderInlineContent])
    /// An aside block.
    case aside(style: AsideStyle, content: [RenderBlockContent])
    /// A block of sample code.
    case codeListing(syntax: String?, code: [String], metadata: RenderContentMetadata?)
    /// A heading with the given level.
    case heading(level: Int, text: String, anchor: String?)
    /// A list that contains ordered items.
    case orderedList(items: [ListItem])
    /// A list that contains unordered items.
    case unorderedList(items: [ListItem])
    
    /// A step in a multi-step tutorial.
    case step(content: [RenderBlockContent], caption: [RenderBlockContent], media: RenderReferenceIdentifier?, code: RenderReferenceIdentifier?, runtimePreview: RenderReferenceIdentifier?)
    /// A REST endpoint example that includes a request and the expected response.
    case endpointExample(summary: [RenderBlockContent]?, request: CodeExample, response: CodeExample)
    /// An example that contains a sample code block.
    case dictionaryExample(summary: [RenderBlockContent]?, example: CodeExample)
    
    /// A list of terms.
    case termList(items: [TermListItem])
    /// A table that contains a list of row data.
    case table(header: HeaderType, rows: [TableRow], metadata: RenderContentMetadata?)
    
    /// An item in a list.
    public struct ListItem: Codable, Equatable {
        /// The item content.
        public var content: [RenderBlockContent]
        
        /// Creates a new list item with the given content.
        public init(content: [RenderBlockContent]) {
            self.content = content
        }
    }
    
    /// An aside style.
    public enum AsideStyle: String, Codable, Equatable, CaseIterable {
        /// A note aside.
        case note
        /// An important aside.
        case important
        /// A warning aside.
        case warning
        /// An experiment aside.
        case experiment
        /// A tip aside.
        case tip
        /// An attention aside.
        case attention
        /// An author aside.
        case author
        /// An authors aside.
        case authors
        /// A bug aside.
        case bug
        /// A complexity aside.
        case complexity
        /// A copyright aside.
        case copyright
        /// A date aside.
        case date
        /// An invariant aside.
        case invariant
        /// A mutatingVariant aside.
        case mutatingVariant
        /// A nonMutatingVariant aside.
        case nonMutatingVariant
        /// A postcondition aside.
        case postcondition
        /// A precondition aside.
        case precondition
        /// A remark aside.
        case remark
        /// A requires aside.
        case requires
        /// A since aside.
        case since
        /// A todo aside.
        case todo
        /// A version aside.
        case version
        /// A throws aside.
        case `throws`
        
        /// Creates a new aside style of the given kind.
        init(_ kind: Aside.Kind) {
            switch kind {
            case .note: self = .note
            case .important: self = .important
            case .warning: self = .warning
            case .experiment: self = .experiment
            case .tip: self = .tip
            case .attention: self = .attention
            case .author: self = .author
            case .authors: self = .authors
            case .bug: self = .bug
            case .complexity: self = .complexity
            case .copyright: self = .copyright
            case .date: self = .date
            case .invariant: self = .invariant
            case .mutatingVariant: self = .mutatingVariant
            case .nonMutatingVariant: self = .nonMutatingVariant
            case .postcondition: self = .postcondition
            case .precondition: self = .precondition
            case .remark: self = .remark
            case .requires: self = .requires
            case .since: self = .since
            case .todo: self = .todo
            case .version: self = .version
            case .throws: self = .throws
            }
        }

        /// Create a new aside style by looking up its display name. Returns nil if no aside style matches.
        init?(displayName: String) {
            let casesAndDisplayNames = AsideStyle.allCases.map { (kind: $0, displayName: $0.displayName() )}
            guard let matchingCaseAndDisplayName = casesAndDisplayNames.first(where: { $0.displayName == displayName }) else {
                return nil
            }
            self = matchingCaseAndDisplayName.kind
        }

        /// Returns the style of aside to use when rendering.
        ///
        /// DocC Render currently has five styles of asides: Note, Tip, Experiment, Important, and Warning. Asides
        /// of these styles can emit their own style into the output, but other styles need to be rendered as one of
        /// these five styles. This function maps aside styles to the render style used in the output.
        func renderKind() -> Self {
            switch self {
            case .important, .warning, .experiment, .tip:
                return self
            default:
                return .note
            }
        }

        /// The heading text to use when rendering this style of aside.
        public func displayName() -> String {
            switch self {
            case .mutatingVariant:
                return "Mutating Variant"
            case .nonMutatingVariant:
                return "Non-Mutating Variant"
            case .todo:
                return "To Do"
            default:
                return self.rawValue.capitalized
            }
        }
    }
    
    /// The table headers style.
    public enum HeaderType: String, Codable, Equatable {
        /// The first row in the table contains column headers.
        case row
        /// The first column in the table contains row headers.
        case column
        /// Both the first row and column contain headers.
        case both
        /// The table doesn't contain headers.
        case none
    }
    
    /// A table row that contains a list of row cells.
    public struct TableRow: Codable, Equatable {
        /// A list of rendering block elements.
        public typealias Cell = [RenderBlockContent]
        /// The list of row cells.
        public let cells: [Cell]
        
        /// Creates a new table row.
        /// - Parameter cells: The list of row cells to use.
        public init(cells: [Cell]) {
            self.cells = cells
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(cells)
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            cells = try container.decode([Cell].self)
        }
    }
    
    /// A term definition.
    ///
    /// Includes a named term and its definition, that look like:
    ///  - term: "Generic Types"
    ///  - definition: "Custom classes, structures, and enumerations that can
    ///    work with any type, in a similar way to `Array` and `Dictionary`."
    ///
    /// The term contains a list of inline elements to allow formatting while,
    /// the definition can be any free-form content including images, paragraphs, tables, etc.
    public struct TermListItem: Codable, Equatable {
        /// A term rendered as content.
        public struct Term: Codable, Equatable {
            /// The term content.
            public let inlineContent: [RenderInlineContent]
        }
        /// A definition rendered as a list of block-content elements.
        public struct Definition: Codable, Equatable {
            /// The definition content.
            public let content: [RenderBlockContent]
        }
        
        /// The term in the term-list item.
        public let term: Term
        /// The definition in the term-list item.
        public let definition: Definition
    }
}

// Codable conformance
extension RenderBlockContent: Codable {
    private enum CodingKeys: CodingKey {
        case type
        case inlineContent, content, caption, style, name, syntax, code, level, text, items, media, runtimePreview, anchor, summary, example, metadata
        case request, response
        case header, rows
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(BlockType.self, forKey: .type)
        
        switch type {
        case .paragraph:
            self = try .paragraph(inlineContent: container.decode([RenderInlineContent].self, forKey: .inlineContent))
        case .aside:
            var style = try container.decode(AsideStyle.self, forKey: .style)
            if style == .note,
               let displayName = try container.decodeIfPresent(String.self, forKey: .name),
               let decodedKind = AsideStyle(displayName: displayName) {
                style = decodedKind
            }
            self = try .aside(style: style, content: container.decode([RenderBlockContent].self, forKey: .content))
        case .codeListing:
            self = try .codeListing(
                syntax: container.decodeIfPresent(String.self, forKey: .syntax),
                code: container.decode([String].self, forKey: .code),
                metadata: container.decodeIfPresent(RenderContentMetadata.self, forKey: .metadata)
            )
        case .heading:
            self = try .heading(level: container.decode(Int.self, forKey: .level), text: container.decode(String.self, forKey: .text), anchor: container.decodeIfPresent(String.self, forKey: .anchor))
        case .orderedList:
            self = try .orderedList(items: container.decode([ListItem].self, forKey: .items))
        case .unorderedList:
            self = try .unorderedList(items: container.decode([ListItem].self, forKey: .items))
        case .step:
            self = try .step(content: container.decode([RenderBlockContent].self, forKey: .content), caption: container.decodeIfPresent([RenderBlockContent].self, forKey: .caption) ?? [], media: container.decode(RenderReferenceIdentifier?.self, forKey: .media), code: container.decode(RenderReferenceIdentifier?.self, forKey: .code), runtimePreview: container.decode(RenderReferenceIdentifier?.self, forKey: .runtimePreview))
        case .endpointExample:
            self = try .endpointExample(
                summary: container.decodeIfPresent([RenderBlockContent].self, forKey: .summary),
                request: container.decode(CodeExample.self, forKey: .request),
                response: container.decode(CodeExample.self, forKey: .response)
            )
        case .dictionaryExample:
            self = try .dictionaryExample(summary: container.decodeIfPresent([RenderBlockContent].self, forKey: .summary), example: container.decode(CodeExample.self, forKey: .example))
        case .table:
            self = try .table(
                header: container.decode(HeaderType.self, forKey: .header),
                rows: container.decode([TableRow].self, forKey: .rows),
                metadata: container.decodeIfPresent(RenderContentMetadata.self, forKey: .metadata)
            )
        case .termList:
            self = try .termList(items: container.decode([TermListItem].self, forKey: .items))
        }
    }
    
    private enum BlockType: String, Codable {
        case paragraph, aside, codeListing, heading, orderedList, unorderedList, step, endpointExample, dictionaryExample, table, termList
    }
    
    private var type: BlockType {
        switch self {
        case .paragraph: return .paragraph
        case .aside: return .aside
        case .codeListing: return .codeListing
        case .heading: return .heading
        case .orderedList: return .orderedList
        case .unorderedList: return .unorderedList
        case .step: return .step
        case .endpointExample: return .endpointExample
        case .dictionaryExample: return .dictionaryExample
        case .table: return .table
        case .termList: return .termList
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        switch self {
        case .paragraph(let inlineContent):
            try container.encode(inlineContent, forKey: .inlineContent)
        case .aside(let style, let content):
            let renderKind = style.renderKind()
            if renderKind != style {
                // Aside styles after the first five render as notes with a special "name" field
                try container.encode(renderKind, forKey: .style)
                try container.encode(style.displayName(), forKey: .name)
                try container.encode(content, forKey: .content)
            } else {
                try container.encode(style, forKey: .style)
                try container.encode(content, forKey: .content)
            }
        case .codeListing(let syntax, let code, metadata: let metadata):
            try container.encode(syntax, forKey: .syntax)
            try container.encode(code, forKey: .code)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        case .heading(let level, let text, let anchor):
            try container.encode(level, forKey: .level)
            try container.encode(text, forKey: .text)
            try container.encode(anchor, forKey: .anchor)
        case .orderedList(let items):
            try container.encode(items, forKey: .items)
        case .unorderedList(let items):
            try container.encode(items, forKey: .items)
        case .step(let content, let caption, let media, let code, let runtimePreview):
            try container.encode(content, forKey: .content)
            try container.encode(caption, forKey: .caption)
            try container.encode(media, forKey: .media)
            try container.encode(code, forKey: .code)
            try container.encode(runtimePreview, forKey: .runtimePreview)
        case .endpointExample(summary: let summary, request: let request, response: let response):
            try container.encodeIfPresent(summary, forKey: .summary)
            try container.encode(request, forKey: .request)
            try container.encode(response, forKey: .response)
        case .dictionaryExample(summary: let summary, example: let example):
            try container.encodeIfPresent(summary, forKey: .summary)
            try container.encode(example, forKey: .example)
        case .table(header: let header, rows: let rows, metadata: let metadata):
            try container.encode(header, forKey: .header)
            try container.encode(rows, forKey: .rows)
            try container.encodeIfPresent(metadata, forKey: .metadata)
        case .termList(items: let items):
            try container.encode(items, forKey: .items)
        }
    }
}
