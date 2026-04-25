/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class MissingAbstractTests: XCTestCase {
    
    private func gatherDiagnostics(for document: Document) -> [Diagnostic] {
        var checker = MissingAbstract(sourceFile: nil)
        checker.visit(document)
        return checker.diagnostics
    }
    
    func testDocumentHasAbstract() {
        let source = """
        # Title

        This is an abstract.
        """
        let document = Document(parsing: source, options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertTrue(diagnostics.isEmpty)
    }
    
    func testDocumentHasNoContentAfterTitle() {
        let document = Document(parsing: "# Title", options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertEqual(diagnostics.count, 0)
    }
    
    func testDocumentIsEmpty() {
        let document = Document(parsing: "", options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertEqual(diagnostics.count, 0)
    }
    
    func testDocumentHasListAfterTitle() throws {
        let source = """
        # Title

        - Foo
        - Bar
        """

        let document = Document(parsing: source, options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertEqual(diagnostics.count, 1)
        
        let diagnostic = try XCTUnwrap(diagnostics.first)
        let title = document.child(at: 0)! as! Heading
        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
        XCTAssertEqual(diagnostic.range, title.range)
        XCTAssertEqual(diagnostic.severity, .information)

    }
    
    func testDocumentHasTitleAfterTitle() throws {
        let source = """
        # Title
        # Title
        """
        
        let document = Document(parsing: source, options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertEqual(diagnostics.count, 1)
        
        let diagnostic = try XCTUnwrap(diagnostics.first)
        let title = document.child(at: 0)! as! Heading
        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
        XCTAssertEqual(diagnostic.range, title.range)
    }
    
    func testNoTitle() throws {
        let document = Document(parsing: "- List item", options: [])
        let diagnostics = gatherDiagnostics(for: document)
        XCTAssertEqual(diagnostics.count, 1)
        
        let diagnostic = try XCTUnwrap(diagnostics.first)
        
        let zeroLocation = SourceLocation(line: 1, column: 1, source: nil)
        let endOfElementLocation = SourceLocation(line: 1, column: 12, source: nil)
        XCTAssertEqual(diagnostic.range, zeroLocation..<endOfElementLocation)
        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
    }
}
