/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
@testable import SwiftDocC
import SymbolKit
import XCTest

class SemaToRenderNodeSourceRepositoryTests: XCTestCase {
    func testDoesNotEmitsSourceRepositoryInformationWhenNoSourceIsGiven() async throws {
        let outputConsumer = try await renderNodeConsumer(
            for: "SourceLocations",
            sourceRepository: nil
        )
        
        XCTAssertNil(try outputConsumer.renderNode(withTitle: "MyStruct").metadata.remoteSource)
    }
    
    func testEmitsSourceRepositoryInformationForSymbolsWhenPresent() async throws {
        let outputConsumer = try await renderNodeConsumer(
            for: "SourceLocations",
            sourceRepository: SourceRepository.github(
                checkoutPath: "/path/to/checkout",
                sourceServiceBaseURL: URL(string: "https://example.com/my-repo")!
            )
        )
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "MyStruct").metadata.remoteSource,
            RenderMetadata.RemoteSource(
                fileName: "MyStruct.swift",
                url: URL(string: "https://example.com/my-repo/SourceLocations/MyStruct.swift#L10")!
            )
        )
    }
    
    func testEmitsCustomEditLinkForArticles() async throws {
        let (_, _, context) = try await testBundleAndContext(
            copying: "SampleBundle",
            configureBundle: { bundleURL in
                let articleURL = bundleURL.appendingPathComponent("MyArticle.md")
                let content = """
                # MyArticle
                
                @Metadata {
                  @EditLink(url: "https://example.com/edit/main/MyArticle.md")
                }
                
                Article abstract.
                """
                try content.write(to: articleURL, atomically: true, encoding: .utf8)
            }
        )
        
        let outputConsumer = TestRenderNodeOutputConsumer()
        try await ConvertActionConverter.convert(
            context: context,
            outputConsumer: outputConsumer,
            htmlContentConsumer: nil,
            sourceRepository: nil,
            emitDigest: false,
            documentationCoverageOptions: .noCoverage
        )
        
        XCTAssertEqual(
            try outputConsumer.renderNode(withTitle: "MyArticle").metadata.remoteSource,
            RenderMetadata.RemoteSource(
                fileName: "MyArticle.md",
                url: URL(string: "https://example.com/edit/main/MyArticle.md")!
            )
        )
    }
    
    func testDisabledEditLinkRemovesArticleRemoteSource() async throws {
        let (bundleURL, _, context) = try await testBundleAndContext(
            copying: "SampleBundle",
            configureBundle: { bundleURL in
                let articleURL = bundleURL.appendingPathComponent("MyArticle.md")
                let content = """
                # MyArticle
                
                @Metadata {
                  @EditLink(isDisabled: true)
                }
                
                Article abstract.
                """
                try content.write(to: articleURL, atomically: true, encoding: .utf8)
            }
        )
        
        let outputConsumer = TestRenderNodeOutputConsumer()
        try await ConvertActionConverter.convert(
            context: context,
            outputConsumer: outputConsumer,
            htmlContentConsumer: nil,
            sourceRepository: SourceRepository.github(
                checkoutPath: bundleURL.deletingLastPathComponent().path,
                sourceServiceBaseURL: URL(string: "https://example.com/my-repo")!
            ),
            emitDigest: false,
            documentationCoverageOptions: .noCoverage
        )
        
        XCTAssertNil(try outputConsumer.renderNode(withTitle: "MyArticle").metadata.remoteSource)
    }
}
