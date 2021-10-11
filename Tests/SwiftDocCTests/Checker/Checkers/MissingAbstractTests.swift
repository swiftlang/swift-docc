/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class MissingAbstractTests: XCTestCase, CheckerTest {
    
    func gatherProblems(for document: Document) -> [Problem] {
        var checker = MissingAbstract(sourceFile: nil)
        checker.visit(document)
        return checker.problems
    }
    
    func testDocumentHasAbstract() {
        let source = """
        # Title

        This is an abstract.
        """
        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testDocumentHasNoContentAfterTitle() {
        let document = Document(parsing: "# Title", options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 0)
    }
    
    func testDocumentIsEmpty() {
        let document = Document(parsing: "", options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 0)
    }
    
    func testDocumentHasListAfterTitle() {
        let source = """
        # Title

        - Foo
        - Bar
        """

        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 1)
        
        let problem = problems[0]
        let title = document.child(at: 0)! as! Heading
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
        XCTAssertEqual(problem.diagnostic.range, title.range)
        XCTAssertEqual(problem.diagnostic.severity, .information)

    }
    
    func testDocumentHasTitleAfterTitle() {
        let source = """
        # Title
        # Title
        """
        
        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 1)
        
        let problem = problems[0]
        let title = document.child(at: 0)! as! Heading
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
        XCTAssertEqual(problem.diagnostic.range, title.range)
    }
    
    func testNoTitle() {
        let document = Document(parsing: "- List item", options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 1)
        
        let problem = problems[0]
        
        let zeroLocation = SourceLocation(line: 1, column: 1, source: nil)
        let endOfElementLocation = SourceLocation(line: 1, column: 12, source: nil)
        XCTAssertEqual(problem.diagnostic.range, zeroLocation..<endOfElementLocation)
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.DocumentHasNoAbstract")
    }
}
