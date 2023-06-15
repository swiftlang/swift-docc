/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Markdown
import XCTest
@testable import SwiftDocC

class PageKindTests: XCTestCase {
    func testPageKindSampleCode() throws {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SampleBundle/MyLocalSample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.sampleCode.rawValue)
        XCTAssertEqual(renderNode.metadata.roleHeading, Metadata.PageKind.Kind.sampleCode.titleHeading)
    }

    func testPageKindArticle() throws {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SampleBundle/MySample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

        XCTAssertEqual(renderNode.metadata.role, RenderMetadata.Role.article.rawValue)
        XCTAssertEqual(renderNode.metadata.roleHeading, Metadata.PageKind.Kind.article.titleHeading)
    }

    func testPageKindDefault() throws {
        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/AvailabilityBundle/ComplexAvailable",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

        XCTAssertEqual(renderNode.metadata.role, "article")
        XCTAssertEqual(renderNode.metadata.roleHeading, "Article")
    }

    func testPageKindReference() throws {
        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")
        let reference = ResolvedTopicReference(
            bundleIdentifier: bundle.identifier,
            path: "/documentation/SomeSample",
            sourceLanguage: .swift
        )
        let article = try XCTUnwrap(context.entity(with: reference).semantic as? Article)
        var translator = RenderNodeTranslator(
            context: context,
            bundle: bundle,
            identifier: reference,
            source: nil
        )
        let renderNode = try XCTUnwrap(translator.visitArticle(article) as? RenderNode)

        let sampleReference = try XCTUnwrap(renderNode.references["doc://org.swift.docc.sample/documentation/SampleBundle/MyLocalSample"] as? TopicRenderReference)

        XCTAssertEqual(sampleReference.role, RenderMetadata.Role.sampleCode.rawValue)
    }

    func testValidMetadataWithOnlyPageKind() throws {
        let source = """
        @Metadata {
            @PageKind(article)
        }
        """

        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Metadata.directiveName, directive.name)
            let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(metadata)
            XCTAssertNotNil(metadata?.pageKind)
            XCTAssertEqual(metadata?.pageKind?.kind, .article)
            XCTAssert(problems.isEmpty)
        }
    }
}
