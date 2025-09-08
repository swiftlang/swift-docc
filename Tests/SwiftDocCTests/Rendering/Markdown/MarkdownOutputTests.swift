/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

final class MarkdownOutputTests: XCTestCase {

    static var loadingTask: Task<(DocumentationBundle, DocumentationContext), any Error>?
    
    func bundleAndContext() async throws -> (bundle: DocumentationBundle, context: DocumentationContext) {
                
        if let task = Self.loadingTask {
            return try await task.value
        } else {
            let task = Task {
                try await testBundleAndContext(named: "MarkdownOutput")
            }
            Self.loadingTask = task
            return try await task.value
        }
    }
        
    private func generateMarkdown(path: String) async throws -> MarkdownOutputNode {
        let (bundle, context) = try await bundleAndContext()
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/MarkdownOutput/\(path)", sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic)
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(translator.visit(article))
        return node
    }

    func testRowsAndColumns() async throws {
        let node = try await generateMarkdown(path: "RowsAndColumns")
        let expected = "I am the content of column one\n\nI am the content of column two"
        XCTAssert(node.markdown.hasSuffix(expected))
    }
    
    func testInlineDocumentLinkFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "inline link: [Rows and Columns](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testTopicListLinkFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "[Rows and Columns](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)\n\nDemonstrates how row and column directives are rendered as markdown"
        XCTAssert(node.markdown.contains(expected))
    }


}
