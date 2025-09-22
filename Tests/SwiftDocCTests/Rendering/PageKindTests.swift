/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import XCTest
@testable import SwiftDocC

class PageKindTests: XCTestCase {
    
    private func generateRenderNodeFromBundle(bundleName: String, resolvedTopicPath: String) async throws -> RenderNode {
        let (inputs, context) = try await testBundleAndContext(named: bundleName)
        let reference = ResolvedTopicReference(
            bundleID: inputs.id,
            path: resolvedTopicPath,
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(context: context, identifier: reference)
        return try XCTUnwrap(translator.visitArticle(article) as? RenderNode)
    }
    
    func testPageKindSampleCode() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "SampleBundle",
            resolvedTopicPath: "/documentation/SampleBundle/MyLocalSample"
        )
        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.sampleCode.rawValue)
        XCTAssertEqual(renderNode.metadata.roleHeading, Metadata.PageKind.Kind.sampleCode.titleHeading)
    }

    func testPageKindArticle() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "SampleBundle",
            resolvedTopicPath: "/documentation/SampleBundle/MySample"
        )

        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.article.rawValue)
        XCTAssertEqual(renderNode.metadata.roleHeading, Metadata.PageKind.Kind.article.titleHeading)
    }

    func testPageKindDefault() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "AvailabilityBundle",
            resolvedTopicPath: "/documentation/AvailabilityBundle/ComplexAvailable"
        )
        XCTAssertEqual(renderNode.metadata.role, "article")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Article")
    }

    func testPageKindReference() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "SampleBundle",
            resolvedTopicPath: "/documentation/SomeSample"
        )
        let sampleReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.sample/documentation/SampleBundle/MyLocalSample"] as? TopicRenderReference)
        XCTAssertEqual(sampleReference.role, RenderMetadata.Role.sampleCode.rawValue)
    }

    func testValidMetadataWithOnlyPageKind() async throws {
        let source = """
        @Metadata {
            @PageKind(article)
        }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, _) = try await testBundleAndContext(named: "SampleBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Metadata.directiveName, directive.name)
            let metadata = Metadata(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNotNil(metadata)
            XCTAssertNotNil(metadata?.pageKind)
            XCTAssertEqual(metadata?.pageKind?.kind, .article)
            XCTAssert(problems.isEmpty)
        }
    }
    
    // Verify that we assign the `Collection` role to the root article of a
    // documentation catalog that contains only one article.
    func testRoleForSingleArticleCatalog() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "BundleWithSingleArticle",
            resolvedTopicPath: "/documentation/Article"
        )
        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.collection.rawValue)
    }
    
    // Verify we assign the `Collection` role to the root article of an article-only
    // documentation catalog that doesn't include manual curation
    func testRoleForArticleOnlyCatalogWithNoCuration() async throws {
        let renderNode = try await generateRenderNodeFromBundle(
            bundleName: "BundleWithArticlesNoCurated",
            resolvedTopicPath: "/documentation/Article"
        )
        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.collection.rawValue)
    }
}
