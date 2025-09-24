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
      
    /// Generates a writable markdown node from a given path
    /// - Parameter path: The path. If you just supply a name (no leading slash), it will prepend `/documentation/MarkdownOutput/`, otherwise the path will be used
    /// - Returns: The generated writable markdown output node
    private func generateWritableMarkdown(path: String) async throws -> WritableMarkdownOutputNode {
        let (bundle, context) = try await bundleAndContext()
        var path = path
        if !path.hasPrefix("/") {
            path = "/documentation/MarkdownOutput/\(path)"
        }
        let reference = ResolvedTopicReference(bundleID: bundle.id, path: path, sourceLanguage: .swift)
        let node = try XCTUnwrap(context.entity(with: reference))
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, node: node)
        return try XCTUnwrap(translator.createOutput())
    }
    /// Generates a markdown node from a given path
    /// - Parameter path: The path. If you just supply a name (no leading slash), it will prepend `/documentation/MarkdownOutput/`, otherwise the path will be used
    /// - Returns: The generated markdown output node
    private func generateMarkdown(path: String) async throws -> MarkdownOutputNode {
        let outputNode = try await generateWritableMarkdown(path: path)
        return outputNode.node
    }
    
    /// Generates a markdown manifest document (with relationships) from a given path
    /// - Parameter path: The path. If you just supply a name (no leading slash), it will prepend `/documentation/MarkdownOutput/`, otherwise the path will be used
    /// - Returns: The generated markdown output manifest document
    private func generateMarkdownManifestDocument(path: String) async throws -> MarkdownOutputManifest.Document {
        let outputNode = try await generateWritableMarkdown(path: path)
        return try XCTUnwrap(outputNode.manifestDocument)
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
    
    func testArticleAvailability() async throws {
        let node = try await generateMarkdown(path: "AvailabilityArticle")
        XCTAssert(node.metadata.availability(for: "Xcode")?.introduced == "14.3.0")
        XCTAssert(node.metadata.availability(for: "macOS")?.introduced == "13.0.0")
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
        XCTAssert(node.metadata.symbol?.kind == "init")
        XCTAssert(node.metadata.role == "Initializer")
    }
    
    func testSymbolSingleModule() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        XCTAssertEqual(node.metadata.symbol?.modules, ["MarkdownOutput"])
    }
    
    func testSymbolExtendedModule() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "ModuleWithSingleExtension")
        let entity = try XCTUnwrap(context.entity(with: ResolvedTopicReference(bundleID: bundle.id, path: "/documentation/ModuleWithSingleExtension/Swift/Array/asdf", sourceLanguage: .swift)))
        var translator = MarkdownOutputNodeTranslator(context: context, bundle: bundle, node: entity)
        let node = try XCTUnwrap(translator.createOutput())
        XCTAssertEqual(node.node.metadata.symbol?.modules, ["ModuleWithSingleExtension", "Swift"])
    }
    
    func testSymbolDefaultAvailabilityWhenNothingPresent() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        let availability = try XCTUnwrap(node.metadata.availability)
        XCTAssertEqual(availability[0], .init(platform: "iOS", introduced: "1.0.0", deprecated: nil, unavailable: false))
    }
    
    func testSymbolModuleDefaultAvailability() async throws {
        let node = try await generateMarkdown(path: "/documentation/MarkdownOutput")
        let availability = try XCTUnwrap(node.metadata.availability(for: "iOS"))
        XCTAssertEqual(availability.introduced, "1.0")
        XCTAssertFalse(availability.unavailable)
    }
    
    func testSymbolDeprecation() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/fullName")
        let availability = try XCTUnwrap(node.metadata.availability(for: "iOS"))
        XCTAssertEqual(availability.introduced, "1.0.0")
        XCTAssertEqual(availability.deprecated, "4.0.0")
        XCTAssertEqual(availability.unavailable, false)
        
        let macAvailability = try XCTUnwrap(node.metadata.availability(for: "macOS"))
        XCTAssertEqual(macAvailability.introduced, "2.0.0")
        XCTAssertEqual(macAvailability.deprecated, "4.0.0")
        XCTAssertEqual(macAvailability.unavailable, false)
    }
    
    func testSymbolObsolete() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol/otherName")
        let availability = try XCTUnwrap(node.metadata.availability(for: "iOS"))
        XCTAssert(availability.unavailable)
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
    
    // MARK: - Encoding / Decoding
    func testMarkdownRoundTrip() async throws {
        let node = try await generateMarkdown(path: "MarkdownSymbol")
        let data = try node.data
        let fromData = try MarkdownOutputNode(data)
        XCTAssertEqual(node.markdown, fromData.markdown)
        XCTAssertEqual(node.metadata.uri, fromData.metadata.uri)
    }
    
    // MARK: - Manifest
    func testArticleManifestLinks() async throws {
        let document = try await generateMarkdownManifestDocument(path: "Links")
        let topics = try XCTUnwrap(document.references(for: .topics))
        XCTAssertEqual(topics.count, 2)
        let ids = topics.map { $0.uri }
        XCTAssert(ids.contains("/documentation/MarkdownOutput/RowsAndColumns"))
        XCTAssert(ids.contains("/documentation/MarkdownOutput/MarkdownSymbol"))
    }
    
    func testSymbolManifestChildSymbols() async throws {
        let document = try await generateMarkdownManifestDocument(path: "MarkdownSymbol")
        let children = try XCTUnwrap(document.references(for: .memberSymbols))
        XCTAssertEqual(children.count, 4)
        let ids = children.map { $0.uri }
        XCTAssert(ids.contains("/documentation/MarkdownOutput/MarkdownSymbol/name"))
        XCTAssert(ids.contains("/documentation/MarkdownOutput/MarkdownSymbol/otherName"))
        XCTAssert(ids.contains("/documentation/MarkdownOutput/MarkdownSymbol/fullName"))
        XCTAssert(ids.contains("/documentation/MarkdownOutput/MarkdownSymbol/init(name:)"))
    }
    
    func testSymbolManifestInheritance() async throws {
        let document = try await generateMarkdownManifestDocument(path: "LocalSubclass")
        let relationships = try XCTUnwrap(document.references(for: .relationships))
        XCTAssert(relationships.contains(where: {
            $0.uri == "/documentation/MarkdownOutput/LocalSuperclass" && $0.subtype == "inheritsFrom"
        }))
    }
    
    func testSymbolManifestInheritedBy() async throws {
        let document = try await generateMarkdownManifestDocument(path: "LocalSuperclass")
        let relationships = try XCTUnwrap(document.references(for: .relationships))
        XCTAssert(relationships.contains(where: {
            $0.uri == "/documentation/MarkdownOutput/LocalSubclass" && $0.subtype == "inheritedBy"
        }))
    }
    
    func testSymbolManifestConformsTo() async throws {
        let document = try await generateMarkdownManifestDocument(path: "LocalConformer")
        let relationships = try XCTUnwrap(document.references(for: .relationships))
        XCTAssert(relationships.contains(where: {
            $0.uri == "/documentation/MarkdownOutput/LocalProtocol" && $0.subtype == "conformsTo"
        }))
    }
    
    func testSymbolManifestConformingTypes() async throws {
        let document = try await generateMarkdownManifestDocument(path: "LocalProtocol")
        let relationships = try XCTUnwrap(document.references(for: .relationships))
        XCTAssert(relationships.contains(where: {
            $0.uri == "/documentation/MarkdownOutput/LocalConformer" && $0.subtype == "conformingTypes"
        }))
    }
    
    func testSymbolManifestExternalConformsTo() async throws {
        let document = try await generateMarkdownManifestDocument(path: "ExternalConformer")
        let relationships = try XCTUnwrap(document.references(for: .relationships))
        XCTAssert(relationships.contains(where: {
            $0.uri == "/documentation/Swift/Hashable" && $0.subtype == "conformsTo"
        }))
    }
}
