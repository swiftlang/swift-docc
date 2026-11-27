/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC
import SymbolKit
import DocCTestUtilities

struct DirectivePathComponentsTests {
    @Test(arguments: [
        "Tab": ["TabNavigator", "Tab"],
        "Column": ["Row", "Column"],
        "Available": ["Metadata", "Available"],
        "PageKind": ["Metadata", "PageKind"],
        "TabNavigator": ["TabNavigator"],
        "DisplayName": ["DisplayName"],
    ])
    func followsSwiftTypeHierarchyOfImplementation(directiveName: String, expectedPathComponents: [String]) throws {
        let directive = try #require(DirectiveIndex.shared.indexedDirectives[directiveName])
        #expect(DirectiveIndex.shared.pathComponents(of: directive) == expectedPathComponents)
    }
    
    @Test
    func onlyContainsIndexedDirectivesAndEndsWithDirectiveName() {
        for (name, directive) in DirectiveIndex.shared.indexedDirectives {
            let pathComponents = DirectiveIndex.shared.pathComponents(of: directive)
            #expect(pathComponents.last == name, "Unexpected path components for '\(name)': \(pathComponents)")
            for component in pathComponents.dropLast() {
                #expect(DirectiveIndex.shared.indexedDirectives[component] != nil, "'\(component)' in the path components for '\(name)' isn't an indexed directive")
            }
        }
    }
    
    // The symbol graph has to be generated first.
    @Test
    func directiveSymbolGraphFollowsSwiftTypeHierarchy() throws {
        let symbolGraph = try JSONDecoder().decode(SymbolGraph.self, from: Data(contentsOf: Self.directiveSymbolGraphURL))
        let documentedDirectives = DirectiveIndex.shared.indexedDirectives.values.filter { !$0.hiddenFromDocumentation }
        let documentedDirectiveNames = Set(documentedDirectives.map(\.name))
        
        for directive in documentedDirectives {
            let symbol = try #require(symbolGraph.symbols.values.first(where: { $0.names.title == directive.name }), "Missing symbol for '\(directive.name)'")
            let expectedPathComponents = DirectiveIndex.shared.pathComponents(of: directive).filter(documentedDirectiveNames.contains)
            #expect(symbol.pathComponents == expectedPathComponents, "Unexpected path components for '\(directive.name)'")
            
            let parentUSRs = symbolGraph.relationships
                .filter { $0.kind == .memberOf && $0.source == symbol.identifier.precise }
                .map(\.target)
            let expectedParentUSRs = expectedPathComponents.dropLast().last.map { parentName in
                symbolGraph.symbols.values.filter { $0.names.title == parentName }.map(\.identifier.precise)
            } ?? []
            #expect(parentUSRs == expectedParentUSRs, "Unexpected 'memberOf' relationships for '\(directive.name)'")
        }
    }
    
    @Test(arguments: [
        ("TabNavigator/Tab", "Tab", nil),
        ("Row/Column", "Column", "Small"),
        ("Metadata/Available", "Available", "DeprecationSummary"),
        ("Metadata/PageKind", "PageKind", nil),
        ("Column", "Column", "Row"),
    ] as [(String, String, String?)]) // Link, Expected directive, Directive page
    func resolvesSwiftTypeHierarchyLinksInDirectiveDocumentation(link: String, expectedDirectiveName: String, linkSourceDirectiveName: String?) async throws {
        let catalog = Folder(name: "docc.docc", content: [
            CopyOfFile(original: Self.directiveSymbolGraphURL),
        ])
        let context = try await load(catalog: catalog)
        let tree = context.linkResolver.localResolver.pathHierarchy
        
        let parentID = try linkSourceDirectiveName.map { try tree.find(path: "/docc/\($0)", onlyFindSymbols: true) }
        let foundID = try tree.find(path: link, parent: parentID, onlyFindSymbols: true)
        #expect(tree.lookup[foundID]?.symbol?.identifier.precise == "__docc_universal_symbol_reference_$\(expectedDirectiveName)")
    }
    
    private static let directiveSymbolGraphURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/docc/DocCDocumentation.docc/docc.symbols.json")
}
