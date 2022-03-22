/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class RoleTests: XCTestCase {
    let expectedRoles: [String: String] = [
        "/documentation/MyKit/MyClass": "symbol",
        "/documentation/MyKit/globalFunction(_:considering:)": "symbol",
        "/tutorials/Test-Catalog/TestTutorial2": "project",
        "/documentation/SideKit": "collection",
        "/documentation/Test-Catalog/article": "collectionGroup", // it has topic groups
        "/tutorials/Test-Catalog/TestTutorialArticle": "article",
        "/tutorials/TestOverview": "overview",
        "/documentation/SideKit/SideClass/init()": "symbol",
    ]
    
    func testNodeRoles() throws {
        let (url, catalog, context) = try testCatalogAndContext(copying: "TestCatalog")
        defer { try? FileManager.default.removeItem(at: url) }

        // Compile docs and verify contents
        for (path, expectedRole) in expectedRoles {
            let identifier = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: path, fragment: nil, sourceLanguage: .swift)
            let source = context.documentURL(for: identifier)
            do {
                let node = try context.entity(with: identifier)
                var translator = RenderNodeTranslator(context: context, catalog: catalog, identifier: node.reference, source: source)
                let renderNode = translator.visit(node.semantic) as! RenderNode
                XCTAssertEqual(expectedRole, renderNode.metadata.role, "Unexpected role \(renderNode.metadata.role!.singleQuoted) for identifier \(identifier.path)")
            } catch {
                XCTFail("Failed to convert \(identifier.path). \(error.localizedDescription)")
                return
            }
        }
    }
    
    func testDocumentationRenderReferenceRoles() throws {
        let (url, catalog, context) = try testCatalogAndContext(copying: "TestCatalog")
        defer { try? FileManager.default.removeItem(at: url) }

        let identifier = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
        let source = context.documentURL(for: identifier)
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, catalog: catalog, identifier: node.reference, source: source)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit"] as? TopicRenderReference)?.role, "collection")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)"] as? TopicRenderReference)?.role, "symbol")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/Test-Catalog/article2"] as? TopicRenderReference)?.role, "collectionGroup")
    }

    func testTutorialsRenderReferenceRoles() throws {
        let (url, catalog, context) = try testCatalogAndContext(copying: "TestCatalog")
        defer { try? FileManager.default.removeItem(at: url) }

        let identifier = ResolvedTopicReference(catalogIdentifier: "org.swift.docc.example", path: "/tutorials/Test-Catalog/TestTutorial", fragment: nil, sourceLanguage: .swift)
        let source = context.documentURL(for: identifier)
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, catalog: catalog, identifier: node.reference, source: source)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/TestOverview"] as? TopicRenderReference)?.role, "overview")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/Test-Catalog/TestTutorialArticle"] as? TopicRenderReference)?.role, "article")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/Test-Catalog/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"] as? TopicRenderReference)?.role, "pseudoSymbol")
    }
}
