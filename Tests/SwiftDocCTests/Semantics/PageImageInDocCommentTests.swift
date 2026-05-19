//
//  PageImageInDocCommentTests.swift
//  SwiftDocC
//
//  Created by Demian Yoo on 5/20/26.
//

import Foundation
import Testing
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct PageImageInDocCommentTests {
    
    @Test
    func parsesPageImageDirectiveFromDocComment() async throws {
        let catalog = Folder (name : "unit-test.docc", content : [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                     symbols: [
                        makeSymbol(
                            id: "some-symbol-id",
                            kind: .class,
                            pathComponents: ["SomeClass"],
                            docComment: """
                            The symbol's abstract.
                                
                            @Metadata {
                                @PageImage(source: "my-image", purpose: icon)
                            }
                            """
                        )
                     ]
            )),
            DataFile(name: "my-image.png", data: Data()),
        ])
        let context = try await load(catalog: catalog)
        
        #expect(context.diagnostics.isEmpty, "Unexpected diagnostics: \(context.diagnostics.map(\.summary))")
        
        let node = try #require(context.documentationCache["some-symbol-id"])
        let pageImages = try #require(node.metadata?.pageImages)
        #expect(pageImages.count == 1)
        
        let pageImage = try #require(pageImages.first)
        #expect(pageImage.purpose == .icon)
        #expect(pageImage.source.path == "my-image")
    }
    
    @Test
    func parsesMultiplePageImageDirectivesFromDocComment() async throws {
        let catalog = Folder(name: "unit-test.docc", content: [
            JSONFile(name: "ModuleName.symbols.json", content: makeSymbolGraph(
                moduleName: "ModuleName",
                symbols: [
                    makeSymbol(
                        id: "some-symbol-id",
                        kind: .class,
                        pathComponents: ["SomeClass"],
                        docComment: """
                        The symbol's abstract.
                            
                        @Metadata {
                            @PageImage(source: "icon-image", purpose: icon)
                            @PageImage(source: "card-image", purpose: card)
                        }
                        """
                    )
                ]
                )),
            DataFile(name: "icon-image.png", data: Data()),
            DataFile(name: "card-image.png", data: Data()),
        ])
        
        let context = try await load(catalog: catalog)
        #expect(context.diagnostics.isEmpty, "Unexpected diagnostics: \(context.diagnostics.map(\.summary))")
        
        let node = try #require(context.documentationCache["some-symbol-id"])
        let pageImages = try #require(node.metadata?.pageImages)
        #expect(pageImages.count == 2)
        
        let iconImage = pageImages.first { $0.purpose == .icon }
        let cardImage = pageImages.first { $0.purpose == .card }
        #expect(iconImage?.source.path == "icon-image")
        #expect(cardImage?.source.path == "card-image")
    }
}
