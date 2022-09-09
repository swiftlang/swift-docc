/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

extension RenderBlockContent: TextIndexing {
    public var headings: [String] {
        switch self {
        case .heading(let h):
            return [h.text]
        default:
            return []
        }
    }

    public func rawIndexableTextContent(references: [String : RenderReference]) -> String {
        switch self {
        case let .aside(a):
            return a.content.rawIndexableTextContent(references: references)
        case let .orderedList(l):
            return l.items.map {
                $0.content.rawIndexableTextContent(references: references)
            }.joined(separator: " ")
        case let .paragraph(p):
            return p.inlineContent.rawIndexableTextContent(references: references)
        case let .step(s):
            return (s.content + s.caption).rawIndexableTextContent(references: references)
        case let .unorderedList(l):
            return l.items.map {
                $0.content.rawIndexableTextContent(references: references)
            }.joined(separator: " ")
        case let .codeListing(l):
            return l.metadata?.rawIndexableTextContent(references: references) ?? ""
        case let .heading(h):
            return h.text
        case .endpointExample:
            return ""
        case .dictionaryExample(let e):
            return e.summary?.rawIndexableTextContent(references: references) ?? ""
        case .table(let t):
            let content = t.rows.map {
                return $0.cells.map {
                    return $0.rawIndexableTextContent(references: references)
                }.joined(separator: " ")
            }.joined(separator: " ")
            
            let meta = t.metadata?.rawIndexableTextContent(references: references) ?? ""
            
            return content + " " + meta
        case .termList(let l):
            return l.items.map {
                let definition = $0.definition.content.rawIndexableTextContent(references: references)
                return $0.term.inlineContent.rawIndexableTextContent(references: references)
                    + ( definition.isEmpty ? "" : " \(definition)" )
            }.joined(separator: " ")
        default:
            fatalError("unknown RenderBlockContent case in rawIndexableTextContent")
        }
    }
}
