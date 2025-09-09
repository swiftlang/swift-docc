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
        let node = try XCTUnwrap(context.entity(with: reference))
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, node: node)
        let outputNode = try XCTUnwrap(translator.visit(node.semantic))
        return outputNode
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
    }
    
    // MARK: - Metadata
    
    func testArticleDocumentType() async throws {
        let node = try await generateMarkdown(path: "Links")
        XCTAssert(node.metadata.documentType == .article)
    }
    
    func testArticleRole() async throws {
        let node = try await generateMarkdown(path: "RowsAndColumns")
        XCTAssert(node.metadata.role == RenderMetadata.Role.article.rawValue)
    }
    
    func testAPICollectionRole() async throws {
        let node = try await generateMarkdown(path: "APICollection")
        XCTAssert(node.metadata.role == RenderMetadata.Role.collectionGroup.rawValue)
    }
    
    func testArticleTitle() async throws {
        let node = try await generateMarkdown(path: "RowsAndColumns")
        XCTAssert(node.metadata.title == "Rows and Columns")
    }
    
    func testSymbolDocumentType() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssert(node.metadata.documentType == .symbol)
    }
    
    func testSymbolTitle() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/init(name:)")
        XCTAssert(node.metadata.title == "init(name:)")
    }
    
    func testSymbolKind() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/init(name:)")
        XCTAssert(node.metadata.symbol?.kind == "Initializer")
    }
    
    func testSymbolSingleModule() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssertEqual(node.metadata.symbol?.modules, ["MarkdownOutput"])
    }
    
    func testSymbolExtendedModule() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "ModuleWithSingleExtension")
        let entity = try XCTUnwrap(context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array/asdf", sourceLanguage: .swift)))
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, node: entity)
        let node = try XCTUnwrap(translator.visit(entity.semantic))
        XCTAssertEqual(node.metadata.symbol?.modules, ["ModuleWithSingleExtension", "Swift"])
    }
    
    func testNoAvailabilityWhenNothingPresent() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssertNil(node.metadata.symbol?.availability)
    }
    
    func testSymbolDeprecation() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/fullName")
        let availability = try XCTUnwrap(node.metadata.symbol?.availability)
        XCTAssertEqual(availability[0], .init(platform: "iOS", introduced: "1.0.0", deprecated: "4.0.0", unavailable: nil))
        XCTAssertEqual(availability[1], .init(platform: "macOS", introduced: "2.0.0", deprecated: "4.0.0", unavailable: nil))
    }
    
    func testSymbolObsolete() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/otherName")
        let availability = try XCTUnwrap(node.metadata.symbol?.availability)
        XCTAssertEqual(availability[0], .init(platform: "iOS", introduced: nil, deprecated: nil, unavailable: "5.0.0"))
    }
    
    func testSymbolIdentifier() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssertEqual(node.metadata.symbol?.preciseIdentifier, "s:14MarkdownOutput0A6SymbolV")
    }
    
    func testTutorialDocumentType() async throws {
        let node = try await generateMarkdown(path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssert(node.metadata.documentType == .tutorial)
    }
    
    func testTutorialTitle() async throws {
        let node = try await generateMarkdown(path: "/tutorials/MarkdownOutput/Tutorial")
        XCTAssert(node.metadata.title == "Tutorial Title")
    }
    
    func testURI() async throws {
        let node = try await generateMarkdown(path: "Links")
        XCTAssert(node.metadata.uri == "/documentation/MarkdownOutput/Links")
    }
    
    func testFramework() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssert(node.metadata.framework == "MarkdownOutput")
    }
    
    
    
}
