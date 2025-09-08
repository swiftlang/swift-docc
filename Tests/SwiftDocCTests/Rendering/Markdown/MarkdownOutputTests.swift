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
        
    /// Generates markdown from a given path
    /// - Parameter path: The path. If you just supply a name (no leading slash), it will prepend `/documentation/MarkdownOutput/`, otherwise the path will be used
    /// - Returns: The generated markdown output node
    private func generateMarkdown(path: String) async throws -> MarkdownOutputNode {
        let (bundle, context) = try await bundleAndContext()
        var path = path
        if !path.hasPrefix("/") {
            path = "/documentation/MarkdownOutput/\(path)"
        }
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: path, sourceLanguage: .swift)
        let article = try XCTUnwrap(context.entity(with: reference).semantic)
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, identifier: reference)
        let node = try XCTUnwrap(translator.visit(article))
        return node
    }

    // MARK: Directive special processing
    
    func testRowsAndColumns() async throws {
        let node = try await generateMarkdown(path: "RowsAndColumns")
        let expected = "I am the content of column one\n\nI am the content of column two"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testInlineDocumentLinkArticleFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "inline link: [Rows and Columns](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testTopicListLinkArticleFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "[Rows and Columns](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/RowsAndColumns)\n\nDemonstrates how row and column directives are rendered as markdown"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testInlineDocumentLinkSymbolFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "inline link: [`MarkdownSymbol`](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/MarkdownSymbol)"
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testTopicListLinkSymbolFormatting() async throws {
        let node = try await generateMarkdown(path: "Links")
        let expected = "[`MarkdownSymbol`](doc://org.swift.MarkdownOutput/documentation/MarkdownOutput/MarkdownSymbol)\n\nA basic symbol to test markdown output."
        XCTAssert(node.markdown.contains(expected))
    }
    
    func testLanguageTabOnlyIncludesPrimaryLanguage() async throws {
        let node = try await generateMarkdown(path: "Tabs")
        XCTAssertFalse(node.markdown.contains("I am an Objective-C code block"))
        XCTAssertTrue(node.markdown.contains("I am a Swift code block"))
    }
    
    func testNonLanguageTabIncludesAllEntries() async throws {
        let node = try await generateMarkdown(path: "Tabs")
        XCTAssertTrue(node.markdown.contains("**Left:**\n\nLeft text"))
        XCTAssertTrue(node.markdown.contains("**Right:**\n\nRight text"))
    }
    
    func testTutorialCodeIsOnlyTheFinalVersion() async throws {
        let node = try await generateMarkdown(path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssertFalse(node.markdown.contains("// STEP ONE"))
        XCTAssertFalse(node.markdown.contains("// STEP TWO"))
        XCTAssertTrue(node.markdown.contains("// STEP THREE"))
    }
    
    func testTutorialCodeAddedAtFinalReferencedStep() async throws {
        let node = try await generateMarkdown(path: "/tutorials/MarkdownOutput/Tutorial")
        let codeIndex = try XCTUnwrap(node.markdown.firstRange(of: "// STEP THREE"))
        let step4Index = try XCTUnwrap(node.markdown.firstRange(of: "### Step 4"))
        XCTAssert(codeIndex.lowerBound < step4Index.lowerBound)
    }
    
    func testTutorialCodeWithNewFileIsAdded() async throws {
        let node = try await generateMarkdown(path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssertTrue(node.markdown.contains("struct StartCodeAgain {"))
        print(node.markdown)
    }
    
    
    
}
