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

class InvalidAdditionalTitleTests: XCTestCase, CheckerTest {
    func gatherProblems(for document: Document) -> [Problem] {
        var checker = InvalidAdditionalTitle(sourceFile: nil)
        checker.visit(document)
        return checker.problems
    }
    
    func testDocumentHasOneTitle() {
        let source = """
            # Title
            
            ## Topics
            """
        
        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testDocumentHasTwoTitles() {
        let source = """
            # Title
            
            ## Topics
            
            # Title 2

            Hello
            """
        
        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 1)
        
        let problem = problems[0]
        
        let invalidHeading = document.child(at: 2) as? Heading
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.InvalidAdditionalTitle")
        XCTAssertEqual(invalidHeading?.range, problem.diagnostic.range)
    }
    
    func testDocumentHasFourTitles() {
        let source = """
            # Title
            
            ## Topics
            
            # Title 2
            # Title 3
            # Title
            """
        
        let document = Document(parsing: source, options: [])
        let problems = gatherProblems(for: document)
        XCTAssertEqual(problems.count, 3)
        
        let problem1 = problems[0]
        let problem2 = problems[1]
        let problem3 = problems[2]
        
        let invalidHeading1 = document.child(at: 2) as? Heading
        let invalidHeading2 = document.child(at: 3) as? Heading
        let invalidHeading3 = document.child(at: 4) as? Heading
        XCTAssertEqual(problem1.diagnostic.identifier, "org.swift.docc.InvalidAdditionalTitle")
        XCTAssertEqual(problem2.diagnostic.identifier, "org.swift.docc.InvalidAdditionalTitle")
        XCTAssertEqual(problem3.diagnostic.identifier, "org.swift.docc.InvalidAdditionalTitle")
        
        XCTAssertEqual(invalidHeading1?.range, problem1.diagnostic.range)
        XCTAssertEqual(invalidHeading2?.range, problem2.diagnostic.range)
        XCTAssertEqual(invalidHeading3?.range, problem3.diagnostic.range)
    }
}
