/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

@testable import SwiftDocC
import Markdown
import XCTest

class RenderContentMetadataTests: XCTestCase {
    func testImageMetadata() throws {
        let metadata = RenderContentMetadata(anchor: "anchor", title: "title", abstract: [
            RenderInlineContent.text("Content"),
        ])
        
        let image = RenderInlineContent.image(identifier: .init("image-1"), metadata: metadata)
        let data = try JSONEncoder().encode(image)
        let roundtrip = try JSONDecoder().decode(RenderInlineContent.self, from: data)
        
        guard case RenderInlineContent.image(_, let metadataRoundtrip) = roundtrip else {
            XCTFail("Didn't decode image correctly")
            return
        }
        
        XCTAssertEqual(metadata, metadataRoundtrip)
    }

    func testTableMetadata() throws {
        let metadata = RenderContentMetadata(anchor: "anchor", title: "title", abstract: [
            RenderInlineContent.text("Content"),
        ])
        
        let table = RenderBlockContent.table(.init(header: .both, rows: [], extendedData: [], metadata: metadata))
        let data = try JSONEncoder().encode(table)
        let roundtrip = try JSONDecoder().decode(RenderBlockContent.self, from: data)
        
        guard case RenderBlockContent.table(let t) = roundtrip else {
            XCTFail("Didn't decode table correctly")
            return
        }
        
        XCTAssertEqual(metadata, t.metadata)
    }

    func testCodeListingMetadata() throws {
        let metadata = RenderContentMetadata(anchor: "anchor", title: "title", abstract: [
            RenderInlineContent.text("Content"),
        ])
        
        let code = RenderBlockContent.codeListing(.init(syntax: nil, code: [], metadata: metadata, copyToClipboard: false))
        let data = try JSONEncoder().encode(code)
        let roundtrip = try JSONDecoder().decode(RenderBlockContent.self, from: data)
        
        guard case RenderBlockContent.codeListing(let roundtripListing) = roundtrip else {
            XCTFail("Didn't decode code listing correctly")
            return
        }
        
        XCTAssertEqual(metadata, roundtripListing.metadata)
    }
    
    func testRenderingTables() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        
        let source = """
        | Column 1  | Column 2 |
        | ------------- | ------------- |
        | Cell 1 | Cell 2 |
        | Cell 3 | Cell 4 |
        """
        let document = Document(parsing: source)
        
        // Verifies that a markdown table renders correctly.
        
        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
        let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)
        
        let renderCell: ([RenderBlockContent]) -> String = { cell in
            return cell.reduce(into: "") { (result, element) in
                switch element {
                    case .paragraph(let p):
                    guard let para = p.inlineContent.first else { return }
                        result.append(para.plainText)
                    default: XCTFail("Unexpected element"); return
                }
            }
        }
        
        switch renderedTable {
            case .table(let t):
                XCTAssertEqual(t.header, .row)
                XCTAssertEqual(t.rows.count, 3)
                guard t.rows.count == 3 else { return }
                XCTAssertEqual(t.rows[0].cells.map(renderCell), ["Column 1", "Column 2"])
                XCTAssertEqual(t.rows[1].cells.map(renderCell), ["Cell 1", "Cell 2"])
                XCTAssertEqual(t.rows[2].cells.map(renderCell), ["Cell 3", "Cell 4"])
                XCTAssertNil(t.alignments)
            default: XCTFail("Unexpected element")
        }
    }

    func testRenderingTableSpans() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = """
        | one | two | three |
        | --- | --- | ----- |
        | big      || small |
        | ^        || small |
        """
        let document = Document(parsing: source)

        // Verifies that a markdown table renders correctly.

        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
        let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)

        let renderCell: ([RenderBlockContent]) -> String = { cell in
            return cell.reduce(into: "") { (result, element) in
                switch element {
                    case .paragraph(let p):
                    guard let para = p.inlineContent.first else { return }
                        result.append(para.plainText)
                    default: XCTFail("Unexpected element"); return
                }
            }
        }

        let expectedExtendedData: [RenderBlockContent.TableCellExtendedData] = [
            .init(rowIndex: 1, columnIndex: 0, colspan: 2, rowspan: 2),
            .init(rowIndex: 1, columnIndex: 1, colspan: 0, rowspan: 1),
            .init(rowIndex: 2, columnIndex: 0, colspan: 2, rowspan: 0),
            .init(rowIndex: 2, columnIndex: 1, colspan: 0, rowspan: 1)
        ]

        switch renderedTable {
            case .table(let t):
                XCTAssertEqual(t.header, .row)
                XCTAssertEqual(t.rows.count, 3)
                guard t.rows.count == 3 else { return }
                XCTAssertEqual(t.rows[0].cells.map(renderCell), ["one", "two", "three"])
                XCTAssertEqual(t.rows[1].cells.map(renderCell), ["big", "", "small"])
                XCTAssertEqual(t.rows[2].cells.map(renderCell), ["", "", "small"])
                for expectedData in expectedExtendedData {
                    XCTAssert(t.extendedData.contains(expectedData))
                }
                XCTAssertNil(t.alignments)
            default: XCTFail("Unexpected element")
        }

        try assertRoundTripCoding(renderedTable)
    }

    func testRenderingTableColumnAlignments() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = """
        | one | two | three | four |
        | :-- | --: | :---: | ---- |
        | one | two | three | four |
        """
        let document = Document(parsing: source)

        // Verifies that a markdown table renders correctly.

        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
        let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)

        let renderCell: ([RenderBlockContent]) -> String = { cell in
            return cell.reduce(into: "") { (result, element) in
                switch element {
                    case .paragraph(let p):
                    guard let para = p.inlineContent.first else { return }
                        result.append(para.plainText)
                    default: XCTFail("Unexpected element"); return
                }
            }
        }

        switch renderedTable {
            case .table(let t):
                XCTAssertEqual(t.header, .row)
                XCTAssertEqual(t.rows.count, 2)
                guard t.rows.count == 2 else { return }
                XCTAssertEqual(t.rows[0].cells.map(renderCell), ["one", "two", "three", "four"])
                XCTAssertEqual(t.rows[1].cells.map(renderCell), ["one", "two", "three", "four"])
                XCTAssertEqual(t.alignments, [.left, .right, .center, .unset])
            default: XCTFail("Unexpected element")
        }

        try assertRoundTripCoding(renderedTable)
    }

    /// Verifies that a table with `nil` alignments and a table with all-unset alignments still compare as equal.
    func testRenderedTableEquality() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let source = """
        | Column 1  | Column 2 |
        | ------------- | ------------- |
        | Cell 1 | Cell 2 |
        | Cell 3 | Cell 4 |
        """
        let document = Document(parsing: source)

        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
        let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)
        guard case let .table(decodedTable) = renderedTable else {
            XCTFail("Unexpected RenderBlockContent element")
            return
        }
        XCTAssertNil(decodedTable.alignments)
        var modifiedTable = decodedTable
        modifiedTable.alignments = [.unset, .unset]

        XCTAssertEqual(decodedTable, modifiedTable)
    }

    /// Verifies that two tables with otherwise-identical contents but different column alignments compare as unequal.
    func testRenderedTableInequality() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))

        let decodedTableWithUnsetColumns: RenderBlockContent.Table
        do {
            let source = """
            | Column 1  | Column 2 |
            | ------------- | ------------- |
            | Cell 1 | Cell 2 |
            | Cell 3 | Cell 4 |
            """
            let document = Document(parsing: source)

            let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
            let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)
            guard case let .table(decodedTable) = renderedTable else {
                XCTFail("Unexpected RenderBlockContent element")
                return
            }
            decodedTableWithUnsetColumns = decodedTable
        }

        let decodedTableWithLeftColumns: RenderBlockContent.Table
        do {
            let source = """
            | Column 1  | Column 2 |
            | :------------ | :------------ |
            | Cell 1 | Cell 2 |
            | Cell 3 | Cell 4 |
            """
            let document = Document(parsing: source)

            // Verifies that a markdown table renders correctly.

            let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
            let renderedTable = try XCTUnwrap(result.first as? RenderBlockContent)
            guard case let .table(decodedTable) = renderedTable else {
                XCTFail("Unexpected RenderBlockContent element")
                return
            }
            decodedTableWithLeftColumns = decodedTable
        }

        XCTAssertNotEqual(decodedTableWithUnsetColumns, decodedTableWithLeftColumns)
    }
    
    func testStrikethrough() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        
        let source = """
        ~~Striken~~ text.
        """
        let document = Document(parsing: source)
        
        // Verifies that a markdown strikethrough text renders correctly.
        
        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!.child(at: 0)!))
        let element = try XCTUnwrap(result.first as? RenderInlineContent)
        switch element {
            case .strikethrough(inlineContent: let content):
                switch content.first {
                    case .text(let string): XCTAssertEqual(string, "Striken")
                    default: XCTFail("Unexpected element")
                }
            default: XCTFail("Unexpected element")
        }
    }
    
    func testHeadingAnchorShouldBeEncoded() async throws {
        let (bundle, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleID: bundle.id, path: "/path", fragment: nil, sourceLanguage: .swift))
        
        let source = """
        ## テスト
        """
        let document = Document(parsing: source)
        
        let result = try XCTUnwrap(renderContentCompiler.visit(document.child(at: 0)!))
        let element = try XCTUnwrap(result.first as? RenderBlockContent)
        switch element {
        case .heading(let heading):
            XCTAssertEqual(heading.level, 2)
            XCTAssertEqual(heading.text, "テスト")
            XCTAssertEqual(heading.anchor, "%E3%83%86%E3%82%B9%E3%83%88", "The UTF-8 representation of テスト is E3 83 86 E3 82 B9 E3 83 88")
        default: XCTFail("Unexpected element")
        }
    }
}
