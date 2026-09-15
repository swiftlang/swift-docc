/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import SymbolKit
@testable import SwiftDocC
import DocCTestUtilities

struct PageImageInDocCommentTests {
    
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
    
    @Test
    func emitsWarningForUnresolvedPageImageInDocComment() async throws {
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
                                @PageImage(source: "card-image", purpose: card)
                                @PageImage(source: "missing-image", purpose: icon)
                            }
                            """
                    )
                ]
            )),
            DataFile(name: "card-image.png", data: Data()),
            // Intentionally no DataFile for "missing-image" the source can't be resolved.
        ])
        let context = try await load(catalog: catalog)
        
        #expect(context.diagnostics.count == 1)
        let diagnostic = try #require(context.diagnostics.first)
        #expect(diagnostic.identifier == "org.swift.docc.unresolvedResource")
        #expect(diagnostic.severity == .warning)
        #expect(diagnostic.summary == "Resource 'missing-image' couldn't be found")
    }
}
