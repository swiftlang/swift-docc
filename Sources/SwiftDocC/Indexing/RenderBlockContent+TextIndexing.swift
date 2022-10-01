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
        case .row(let row):
            return row.columns.map { column in
                return column.content.rawIndexableTextContent(references: references)
            }.joined(separator: " ")
        case .small(let small):
            return small.inlineContent.rawIndexableTextContent(references: references)
        case .tabNavigator(let tabNavigator):
            return tabNavigator.tabs.map { tab in
                return tab.content.rawIndexableTextContent(references: references)
            }.joined(separator: " ")
        case .links(let links):
            // Matches the behavior in `RenderInlineContent+TextIndexing` for a
            // `RenderInlineContent.reference`
            return links.items
                .compactMap { references[$0] as? TopicRenderReference }
                .map(\.title)
                .joined(separator: " ")
        case .video(let video):
            return video.metadata?.rawIndexableTextContent(references: references) ?? ""
        default:
            fatalError("unknown RenderBlockContent case in rawIndexableTextContent")
        }
    }
}
