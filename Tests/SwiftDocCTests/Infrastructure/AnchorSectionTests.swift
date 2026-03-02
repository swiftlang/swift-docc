/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import Markdown
@testable import SymbolKit
@testable import SwiftDocC
import DocCCommon
import DocCTestUtilities

struct AnchorSectionTests {
    @Test
    func resolvesLinksToArticleSubsections() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            TextFile(name: "First.md", utf8Content: """
            # Some article
            
            ## Some heading
            
            ### Some sub heading
            """),
            
            TextFile(name: "Second.md", utf8Content: """
            # Second article
            
            A second article that links to headings from the first article:
            
            - <doc:First#Some-heading>
            - <doc:First#Some-sub-heading>
            """),
        ])
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let firstArticleReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let headingReference      = firstArticleReference.withFragment("Some-heading")
        let subHeadingReference   = firstArticleReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let secondArticleReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "Second" }))
        let secondArticleNode = try context.entity(with: secondArticleReference)
        let links: [String] = try #require(
            (secondArticleNode.semantic as? Article)?.discussion?.content.mapFirst(where: { $0 as? UnorderedList })
        ).listItems.compactMap { listItem in
            listItem.children.mapFirst(where: { $0 as? Paragraph })?.children.mapFirst(where: { $0 as? Link })?.destination
        }
        
        #expect(links == [
            "doc://Something/documentation/Something/First#Some-heading",
            "doc://Something/documentation/Something/First#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(secondArticleNode)
        
        let renderedLinks: [String] = try #require(
            (renderNode.primaryContentSections.first as? ContentRenderSection)?.content.mapFirst(where: {
                if case .unorderedList(let list) = $0 { return list } else { return nil }
            })
        ).items.compactMap { listItem in
            let paragraph = listItem.content.mapFirst(where: {
                if case .paragraph(let paragraph) = $0 { paragraph } else { nil }
            })
            return paragraph?.inlineContent.mapFirst(where: {
                if case .reference(let reference, _, _, _) = $0 { return reference } else { return nil }
            })?.identifier
        }
        
        #expect(renderedLinks == [
            "doc://Something/documentation/Something/First#Some-heading",
            "doc://Something/documentation/Something/First#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func resolvesLinksToSymbolSubsections() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["First"], docComment: """
                ## Some heading
                ### Some sub heading
                """),
                
                makeSymbol(id: "second-symbol-id", kind: .struct, pathComponents: ["Second"], docComment: """
                A second symbol that links to headings from the first symbol:
                
                - <doc:First#Some-heading>
                - <doc:First#Some-sub-heading>
                """)
            ])),
        ])
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let firstSymbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let headingReference      = firstSymbolReference.withFragment("Some-heading")
        let subHeadingReference   = firstSymbolReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let secondSymbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "Second" }))
        let secondSymbolNode = try context.entity(with: secondSymbolReference)
        let links: [String]  = try #require(
            (secondSymbolNode.semantic as? Symbol)?.discussion?.content.mapFirst(where: { $0 as? UnorderedList })
        ).listItems.compactMap { listItem in
            listItem.children.mapFirst(where: { $0 as? Paragraph })?.children.mapFirst(where: { $0 as? Link })?.destination
        }
        
        #expect(links == [
            "doc://Something/documentation/ModuleName/First#Some-heading",
            "doc://Something/documentation/ModuleName/First#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(secondSymbolNode)
        
        let renderedLinks: [String] = try #require(
            (renderNode.primaryContentSections.first as? ContentRenderSection)?.content.mapFirst(where: {
                if case .unorderedList(let list) = $0 { return list } else { return nil }
            })
        ).items.compactMap { listItem in
            let paragraph = listItem.content.mapFirst(where: {
                if case .paragraph(let paragraph) = $0 { paragraph } else { nil }
            })
            return paragraph?.inlineContent.mapFirst(where: {
                if case .reference(let reference, _, _, _) = $0 { return reference } else { return nil }
            })?.identifier
        }
        
        #expect(renderedLinks == [
            "doc://Something/documentation/ModuleName/First#Some-heading",
            "doc://Something/documentation/ModuleName/First#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func resolvesLinksToModulePageSubsections() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .struct, pathComponents: ["SymbolName"], docComment: """
                A symbol that links to headings from the module's extension file:
                
                - <doc:ModuleName#Some-heading>
                - <doc:ModuleName#Some-sub-heading>
                """)
            ])),
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            ## Some heading
            ### Some sub heading
            """),
        ])
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let rootReference = try #require(context.soleRootModuleReference)
        let headingReference    = rootReference.withFragment("Some-heading")
        let subHeadingReference = rootReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let symbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SymbolName" }))
        let symbolNode = try context.entity(with: symbolReference)
        let links: [String]  = try #require(
            (symbolNode.semantic as? Symbol)?.discussion?.content.mapFirst(where: { $0 as? UnorderedList })
        ).listItems.compactMap { listItem in
            listItem.children.mapFirst(where: { $0 as? Paragraph })?.children.mapFirst(where: { $0 as? Link })?.destination
        }
        
        #expect(links == [
            "doc://Something/documentation/ModuleName#Some-heading",
            "doc://Something/documentation/ModuleName#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(symbolNode)
        
        let renderedLinks: [String] = try #require(
            (renderNode.primaryContentSections.first as? ContentRenderSection)?.content.mapFirst(where: {
                if case .unorderedList(let list) = $0 { return list } else { return nil }
            })
        ).items.compactMap { listItem in
            let paragraph = listItem.content.mapFirst(where: {
                if case .paragraph(let paragraph) = $0 { paragraph } else { nil }
            })
            return paragraph?.inlineContent.mapFirst(where: {
                if case .reference(let reference, _, _, _) = $0 { return reference } else { return nil }
            })?.identifier
        }
        
        #expect(renderedLinks == [
            "doc://Something/documentation/ModuleName#Some-heading",
            "doc://Something/documentation/ModuleName#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func warnsAboutCuratingSections() async throws {
        let catalog = Folder(name: "Something.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["First"], docComment: """
                ## Some symbol heading
                """),
                
                makeSymbol(id: "second-symbol-id", kind: .struct, pathComponents: ["Second"], docComment: """
                A second symbol that curates headings from the first symbol:
                
                ## Topics
                - <doc:First#Some-symbol-heading>
                - <doc:OtherArticle#Some-article-heading>
                """)
            ])),
            
            TextFile(name: "Article.md", utf8Content: """
            # Some article
            
            An article that curates headings from the first symbol:
            
            ## Topics
            - <doc:First#Some-symbol-heading>
            - <doc:OtherArticle#Some-article-heading>
            """),
            
            TextFile(name: "OtherArticle.md", utf8Content: """
            # Some other article
            
            ## Some article heading
            """),
        ])
        let context = try await load(catalog: catalog)
        
        #expect(context.problems.map(\.diagnostic.summary) == [
            "The content section link 'doc:First#Some-symbol-heading' isn\'t allowed in a Topics link group",
            "The content section link 'doc:OtherArticle#Some-article-heading' isn\'t allowed in a Topics link group",
            
            "The content section link 'doc:First#Some-symbol-heading' isn\'t allowed in a Topics link group",
            "The content section link 'doc:OtherArticle#Some-article-heading' isn\'t allowed in a Topics link group",
        ])
        
        #expect(context.problems.map(\.diagnostic.identifier) == [
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
        ], "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
    }
}
