/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
import Markdown
@testable import SwiftDocC

class RenderNodeTranslatorSymbolVariantsTests: XCTestCase {
    
//    func testEncodesNilTopicsSectionsForArticleVariantIfDefaultIsNonEmpty() throws {
//        try assertMultiVariantArticle(
//            configureArticle: { article in
//                article.automaticTaskGroups = []
//                article.topics = makeTopicsSection(
//                    taskGroupName: "Swift Task Group",
//                    destination: "doc://org.swift.docc.example/documentation/MyKit/MyProtocol"
//                )
//            },
//            assertOriginalRenderNode: { renderNode in
//                XCTAssertEqual(renderNode.topicSections.count, 1)
//                let taskGroup = try XCTUnwrap(renderNode.topicSections.first)
//                XCTAssertEqual(taskGroup.title, "Swift Task Group")
//                
//                XCTAssertEqual(
//                    taskGroup.identifiers,
//                    ["doc://org.swift.docc.example/documentation/MyKit/MyProtocol"]
//                )
//            },
//            assertDataAfterApplyingVariant: { renderNodeData in
//                // What we want to validate here is that the Objective-C render JSON's `topicSections` is `null` rather
//                // than `[]`. Since the `RenderNode` decoder implementation encodes `[]` rather than `nil` into the
//                // model when the JSON value is `null` (`topicSections` is not optional in the model), we can't use it
//                // for this test. Instead, we decode the JSON using a proxy type that has an optional `topicSections`.
//                
//                struct RenderNodeProxy: Codable {
//                    var topicSections: [TaskGroupRenderSection]?
//                }
//                
//                XCTAssertNil(
//                    try JSONDecoder().decode(RenderNodeProxy.self, from: renderNodeData).topicSections,
//                    "Expected topicSections to be null in the JSON because the article has no Objective-C topics."
//                )
//            }
//        )
//    }
    
//    func testArticleAutomaticTaskGroupsForArticleOnlyIncludeTopicsAvailableInTheArticleLanguage() throws {
//        func referenceWithPath(_ path: String) -> ResolvedTopicReference {
//            ResolvedTopicReference(
//                bundleIdentifier: "org.swift.docc.example",
//                path: path,
//                fragment: nil,
//                sourceLanguage: .swift
//            )
//        }
//        
//        try assertMultiVariantArticle(
//            configureContext: { context, reference in
//                let articleTopicGraphNode = TopicGraph.Node(
//                    reference: reference,
//                    kind: .article,
//                    source: .external,
//                    title: "Article"
//                )
//                
//                let myProtocolReference = referenceWithPath("/documentation/MyKit/MyProtocol")
//                let myClassReference = referenceWithPath("/documentation/MyKit/MyClass")
//                
//                let myProtocolTopicGraphNode = TopicGraph.Node(
//                    reference: myProtocolReference,
//                    kind: .protocol,
//                    source: .external,
//                    title: "MyProtocol"
//                )
//                
//                let myClassTopicGraphNode = TopicGraph.Node(
//                    reference: myClassReference,
//                    kind: .protocol,
//                    source: .external,
//                    title: "MyProtocol"
//                )
//                
//                // Remove MyProtocol and MyClass's parents and make them children of the article instead.
//                context.topicGraph.reverseEdges[myProtocolReference] = nil
//                context.topicGraph.reverseEdges[myClassReference] = nil
//                
//                context.topicGraph.addEdge(
//                    from: articleTopicGraphNode,
//                    to: myProtocolTopicGraphNode
//                )
//                
//                context.topicGraph.addEdge(
//                    from: articleTopicGraphNode,
//                    to: myClassTopicGraphNode
//                )
//                
//                try makeSymbolAvailableInSwiftAndObjectiveC(
//                    symbolPath: "/documentation/MyKit/MyProtocol",
//                    bundleIdentifier: reference.bundleIdentifier,
//                    context: context
//                )
//                
//                // Add an Objective-C kind to MyProtocol to make it a multi-language symbol.
//                try XCTUnwrap(context.documentationCache[myProtocolReference]?.semantic as? Symbol)
//                    .kindVariants[.objectiveC] = SymbolGraph.Symbol.Kind(
//                        parsedIdentifier: .protocol,
//                        displayName: "Protocol"
//                    )
//            },
//            configureArticle: { article in
//                article.automaticTaskGroups = []
//                article.topics = nil
//            },
//            assertOriginalRenderNode: { renderNode in
//                XCTAssertEqual(
//                    renderNode.topicSections.flatMap { topicSection in
//                        [topicSection.title] + topicSection.identifiers
//                    },
//                    [
//                        "Classes",
//                        "doc://org.swift.docc.example/documentation/MyKit/MyClass",
//                        "Protocols",
//                        "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
//                    ]
//                )
//            },
//            assertAfterApplyingVariant: { renderNode in
//                XCTAssertEqual(
//                    renderNode.topicSections.flatMap { topicSection in
//                        [topicSection.title] + topicSection.identifiers
//                    },
//                    [
//                        "Protocols",
//                        "doc://org.swift.docc.example/documentation/MyKit/MyProtocol",
//                    ]
//                )
//            }
//        )
//    }
    
    private func assertMultiVariantArticle(
        configureContext: (DocumentationContext, ResolvedTopicReference) throws -> () = { _, _ in },
        configureArticle: (Article) throws -> () = { _ in },
//        configureRenderNodeTranslator: (inout RenderNodeTranslator) -> () = { _ in },
        assertOriginalRenderNode: (RenderNode) throws -> (),
        assertAfterApplyingVariant: (RenderNode) throws -> () = { _ in },
        assertDataAfterApplyingVariant: (Data) throws -> () = { _ in }
    ) throws {
        let (_, bundle, context) = try testBundleAndContext(copying: "TestBundle")
        
        let identifier = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/Test-Bundle/article",
            sourceLanguage: .swift
        )
        
        try configureContext(context, identifier)
        context.documentationCache[identifier]?.availableSourceLanguages = [.swift, .objectiveC]
        
        let node = try context.entity(with: identifier)
        
        let article = try XCTUnwrap(node.semantic as? Article)
        
        try configureArticle(article)
       
//        try assertMultiLanguageSemantic(
//            article,
//            context: context,
//            bundle: bundle,
//            identifier: identifier,
//            assertOriginalRenderNode: assertOriginalRenderNode,
//            assertAfterApplyingVariant: assertAfterApplyingVariant,
//            assertDataAfterApplyingVariant: assertDataAfterApplyingVariant
//        )
    }
}
