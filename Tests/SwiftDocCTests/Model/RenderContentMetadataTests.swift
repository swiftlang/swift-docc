/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
        
        let code = RenderBlockContent.codeListing(.init(syntax: nil, code: [], metadata: metadata))
        let data = try JSONEncoder().encode(code)
        let roundtrip = try JSONDecoder().decode(RenderBlockContent.self, from: data)
        
        guard case RenderBlockContent.codeListing(let roundtripListing) = roundtrip else {
            XCTFail("Didn't decode code listing correctly")
            return
        }
        
        XCTAssertEqual(metadata, roundtripListing.metadata)
    }
    
    func testRenderingTables() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: nil, sourceLanguage: .swift))
        
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
            default: XCTFail("Unexpected element")
        }
    }

    func testRenderingTableSpans() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: nil, sourceLanguage: .swift))

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
            default: XCTFail("Unexpected element")
        }

        try assertRoundTripCoding(renderedTable)
    }
    
    func testStrikethrough() throws {
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var renderContentCompiler = RenderContentCompiler(context: context, bundle: bundle, identifier: ResolvedTopicReference(bundleIdentifier: bundle.identifier, path: "/path", fragment: nil, sourceLanguage: .swift))
        
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
}
