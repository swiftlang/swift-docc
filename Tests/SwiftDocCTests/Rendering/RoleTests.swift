/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
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
        "/tutorials/Test-Bundle/TestTutorial2": "project",
        "/documentation/SideKit": "collection",
        "/documentation/Test-Bundle/article": "collectionGroup", // it has topic groups
        "/tutorials/Test-Bundle/TestTutorialArticle": "article",
        "/tutorials/TestOverview": "overview",
        "/documentation/SideKit/SideClass/init()": "symbol",
    ]
    
    func testNodeRoles() async throws {
        let (_, context) = try await loadFromDisk(copyingCatalogNamed: "LegacyBundle_DoNotUseInNewTests")

        // Compile docs and verify contents
        for (path, expectedRole) in expectedRoles {
            let identifier = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: path, fragment: nil, sourceLanguage: .swift)
            do {
                let node = try context.entity(with: identifier)
                var translator = RenderNodeTranslator(context: context, identifier: node.reference)
                let renderNode = translator.visit(node.semantic) as! RenderNode
                XCTAssertEqual(expectedRole, renderNode.metadata.role, "Unexpected role \(renderNode.metadata.role!.singleQuoted) for identifier \(identifier.path)")
            } catch {
                XCTFail("Failed to convert \(identifier.path). \(error.localizedDescription)")
                return
            }
        }
    }
    
    func testDocumentationRenderReferenceRoles() async throws {
        let (_, context) = try await loadFromDisk(copyingCatalogNamed: "LegacyBundle_DoNotUseInNewTests")

        let identifier = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/documentation/MyKit", fragment: nil, sourceLanguage: .swift)
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit"] as? TopicRenderReference)?.role, "collection")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/MyKit/globalFunction(_:considering:)"] as? TopicRenderReference)?.role, "symbol")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/documentation/Test-Bundle/article2"] as? TopicRenderReference)?.role, "collectionGroup")
    }

    func testTutorialsRenderReferenceRoles() async throws {
        let (_, context) = try await loadFromDisk(copyingCatalogNamed: "LegacyBundle_DoNotUseInNewTests")

        let identifier = ResolvedTopicReference(bundleID: "org.swift.docc.example", path: "/tutorials/Test-Bundle/TestTutorial", fragment: nil, sourceLanguage: .swift)
        let node = try context.entity(with: identifier)
        var translator = RenderNodeTranslator(context: context, identifier: node.reference)
        let renderNode = translator.visit(node.semantic) as! RenderNode

        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/TestOverview"] as? TopicRenderReference)?.role, "overview")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorialArticle"] as? TopicRenderReference)?.role, "article")
        XCTAssertEqual((renderNode.references["doc://org.swift.docc.example/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB"] as? TopicRenderReference)?.role, "pseudoSymbol")
    }
}
