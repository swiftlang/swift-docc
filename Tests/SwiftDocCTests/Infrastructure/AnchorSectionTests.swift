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
        let catalog = Folder(name: "Something.docc") {
            TextFile(name: "First.md", utf8Content: """
            # Some article
            
            ## Some heading
            
            ### Some sub heading
            """)
            
            TextFile(name: "Second.md", utf8Content: """
            # Second article
            
            A second article that links to headings from the first article:
            
            - <doc:First#Some-heading>
            - <doc:First#Some-sub-heading>
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let firstArticleReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let headingReference      = firstArticleReference.withFragment("Some-heading")
        let subHeadingReference   = firstArticleReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let secondArticleReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "Second" }))
        let secondArticleNode = try context.entity(with: secondArticleReference)
        
        let links = try Self.firstUnorderedLinks(in: #require((secondArticleNode.semantic as? Article)?.discussion))
        #expect(links == [
            "doc://Something/documentation/Something/First#Some-heading",
            "doc://Something/documentation/Something/First#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(secondArticleNode)
        
        let renderedLinks = try Self.firstUnorderedLinks(in: renderNode)
        #expect(renderedLinks == [
            "doc://Something/documentation/Something/First#Some-heading",
            "doc://Something/documentation/Something/First#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func resolvesLinksToSymbolSubsections() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["First"], docComment: """
                ## Some heading
                ### Some sub heading
                """),
                
                makeSymbol(id: "second-symbol-id", kind: .struct, pathComponents: ["Second"], docComment: """
                A second symbol that links to headings from the first symbol:
                
                - <doc:First#Some-heading>
                - <doc:First#Some-sub-heading>
                """),
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let firstSymbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let headingReference      = firstSymbolReference.withFragment("Some-heading")
        let subHeadingReference   = firstSymbolReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let secondSymbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "Second" }))
        let secondSymbolNode = try context.entity(with: secondSymbolReference)
        let links = try Self.firstUnorderedLinks(in: #require((secondSymbolNode.semantic as? Symbol)?.discussion))
        #expect(links == [
            "doc://Something/documentation/ModuleName/First#Some-heading",
            "doc://Something/documentation/ModuleName/First#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(secondSymbolNode)
        
        let renderedLinks = try Self.firstUnorderedLinks(in: renderNode)
        #expect(renderedLinks == [
            "doc://Something/documentation/ModuleName/First#Some-heading",
            "doc://Something/documentation/ModuleName/First#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func resolvesLinksToModulePageSubsections() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "some-symbol-id", kind: .struct, pathComponents: ["SymbolName"], docComment: """
                A symbol that links to headings from the module's extension file:
                
                - <doc:ModuleName#Some-heading>
                - <doc:ModuleName#Some-sub-heading>
                """),
            ]))
            
            TextFile(name: "ModuleName.md", utf8Content: """
            # ``ModuleName``
            ## Some heading
            ### Some sub heading
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
        
        let rootReference = try #require(context.soleRootModuleReference)
        let headingReference    = rootReference.withFragment("Some-heading")
        let subHeadingReference = rootReference.withFragment("Some-sub-heading")
        
        #expect(context.nodeAnchorSections[headingReference]?.title    == "Some heading")
        #expect(context.nodeAnchorSections[subHeadingReference]?.title == "Some sub heading")
        
        let symbolReference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "SymbolName" }))
        let symbolNode = try context.entity(with: symbolReference)
        let links = try Self.firstUnorderedLinks(in: #require((symbolNode.semantic as? Symbol)?.discussion))
        #expect(links == [
            "doc://Something/documentation/ModuleName#Some-heading",
            "doc://Something/documentation/ModuleName#Some-sub-heading",
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(symbolNode)
        
        let renderedLinks = try Self.firstUnorderedLinks(in: renderNode)
        #expect(renderedLinks == [
            "doc://Something/documentation/ModuleName#Some-heading",
            "doc://Something/documentation/ModuleName#Some-sub-heading",
        ], "Both links should be resolved")
    }
    
    @Test
    func warnsAboutCuratingSections() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "first-symbol-id",  kind: .class, pathComponents: ["First"], docComment: """
                ## Some symbol heading
                """),
                
                makeSymbol(id: "second-symbol-id", kind: .struct, pathComponents: ["Second"], docComment: """
                A second symbol that curates headings from the first symbol:
                
                ## Topics
                - <doc:First#Some-symbol-heading>
                - <doc:OtherArticle#Some-article-heading>
                """),
            ]))
            
            TextFile(name: "Article.md", utf8Content: """
            # Some article
            
            An article that curates headings from the first symbol:
            
            ## Topics
            - <doc:First#Some-symbol-heading>
            - <doc:OtherArticle#Some-article-heading>
            """)
            
            TextFile(name: "OtherArticle.md", utf8Content: """
            # Some other article
            
            ## Some article heading
            """)
        }
        let context = try await load(catalog: catalog)
        
        #expect(context.problems.map(\.diagnostic.summary) == [
            "The content section link 'doc:First#Some-symbol-heading' isn't allowed in a Topics link group",
            "The content section link 'doc:OtherArticle#Some-article-heading' isn't allowed in a Topics link group",
            
            "The content section link 'doc:First#Some-symbol-heading' isn't allowed in a Topics link group",
            "The content section link 'doc:OtherArticle#Some-article-heading' isn't allowed in a Topics link group",
        ])
        
        #expect(context.problems.map(\.diagnostic.identifier) == [
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
            "org.swift.docc.SectionCuration",
        ], "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")
    }
    
    @Test
    func prefersSymbolMatchOverHeadingMatch() async throws {
        let catalog = Folder(name: "Something.docc") {
            JSONFile(symbolGraph: makeSymbolGraph(moduleName: "ModuleName", symbols: [
                makeSymbol(id: "first-symbol-id", kind: .class, pathComponents: ["First"], docComment: """
                The heading below has the same name as the second symbol.
                
                ## Second
                
                These links, with and without a '#' prefix, resolve to different things:
                - <doc:#Second>
                - <doc:Second>
                """),
                
                makeSymbol(id: "second-symbol-id", kind: .class, pathComponents: ["Second"]),
            ]))
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")

        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let symbolNode = try context.entity(with: reference)
        
        let links = try Self.firstUnorderedLinks(in: #require((symbolNode.semantic as? Symbol)?.discussion))
        #expect(links == [
            "doc://Something/documentation/ModuleName/First#Second", // `#Second` resolves to the heading
            "doc://Something/documentation/ModuleName/Second"        //  `Second` resolves to the other page
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(symbolNode)
        
        let renderedLinks = try Self.firstUnorderedLinks(in: renderNode)
        #expect(renderedLinks == [
            "doc://Something/documentation/ModuleName/First#Second", // `#Second` resolves to the heading
            "doc://Something/documentation/ModuleName/Second"        //  `Second` resolves to the other page
        ], "Both links should be resolved")
    }
    
    @Test
    func prefersArticleMatchOverHeadingMatch() async throws {
        let catalog = Folder(name: "Something.docc") {
            TextFile(name: "First.md", utf8Content: """
            # Some article
            
            The heading below has the same name as the second article.
            
            ## Second
            
            These links, with and without a '#' prefix, resolve to different things:
            - <doc:#Second>
            - <doc:Second>
            """)
            
            TextFile(name: "Second.md", utf8Content: """
            # Second article
            
            This article has the same name as the heading in the first article.
            """)
        }
        let context = try await load(catalog: catalog)
        #expect(context.problems.isEmpty, "Unexpected problems: \(context.problems.map(\.diagnostic.summary))")

        let reference = try #require(context.knownPages.first(where: { $0.lastPathComponent == "First" }))
        let articleNode = try context.entity(with: reference)
        
        let links = try Self.firstUnorderedLinks(in: #require((articleNode.semantic as? Article)?.discussion))
        #expect(links == [
            "doc://Something/documentation/Something/First#Second", // `#Second` resolves to the heading
            "doc://Something/documentation/Something/Second"        //  `Second` resolves to the other page
        ], "Both links should be resolved")
        
        let converter = DocumentationNodeConverter(context: context)
        let renderNode = converter.convert(articleNode)
        
        let renderedLinks = try Self.firstUnorderedLinks(in: renderNode)
        #expect(renderedLinks == [
            "doc://Something/documentation/Something/First#Second", // `#Second` resolves to the heading
            "doc://Something/documentation/Something/Second"        //  `Second` resolves to the other page
        ], "Both links should be resolved")
    }
    
    private static func firstUnorderedLinks(in discussion: DiscussionSection, sourceLocation: Testing.SourceLocation = #_sourceLocation) throws -> [String] {
        try #require(
            discussion.content.mapFirst(where: { $0 as? UnorderedList }), "Didn't find an unordered list", sourceLocation: sourceLocation
        ).listItems.enumerated().compactMap { index, listItem in
            let paragraph = try #require(
                listItem.children.mapFirst(where: { $0 as? Paragraph }), "Didn't find an paragraph in list item \(index)", sourceLocation: sourceLocation
            )
            return try #require(
                paragraph.children.mapFirst(where: { $0 as? Link }), "Didn't find a link in paragraph inside list item \(index)", sourceLocation: sourceLocation
            ).destination
        }
    }
    
    private static func firstUnorderedLinks(in renderNode: RenderNode, sourceLocation: Testing.SourceLocation = #_sourceLocation) throws -> [String] {
        try #require(
            (renderNode.primaryContentSections.first as? ContentRenderSection)?.content.mapFirst(where: {
                if case .unorderedList(let list) = $0 { list } else { nil }
            }),
            "Didn't find an unordered list", sourceLocation: sourceLocation
        ).items.enumerated().compactMap { index, listItem in
            let paragraph = try #require(
                listItem.content.mapFirst(where: {
                    if case .paragraph(let paragraph) = $0 { paragraph } else { nil }
                }),
                "Didn't find an paragraph in list item \(index)", sourceLocation: sourceLocation
            )
            return try #require(
                paragraph.inlineContent.mapFirst(where: {
                    if case .reference(let reference, _, _, _) = $0 { reference } else { nil }
                }),
                "Didn't find a link in paragraph inside list item \(index)", sourceLocation: sourceLocation
            ).identifier
        }
    }
}
