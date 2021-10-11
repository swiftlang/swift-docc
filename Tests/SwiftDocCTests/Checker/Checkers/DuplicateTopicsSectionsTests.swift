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

class DuplicateTopicsSectionsTests: XCTestCase {
    func testNoTopicsSections() {
        var checker = DuplicateTopicsSections(sourceFile: nil)
        checker.visit(Document())
        XCTAssertTrue(checker.problems.isEmpty)
    }
    
    func testOneTopicsSection() {
        let markupSource = """
# Title

Blah

## Topics
"""
        let document = Document(parsing: markupSource, options: [])
        var checker = DuplicateTopicsSections(sourceFile: nil)
        checker.visit(document)
        XCTAssertTrue(checker.problems.isEmpty)
    }
    
    func testMultipleTopicsSections() {
        let markupSource = """
# Title

Abstract.

## Topics

### Topic A

## Topics

### Topic B

"""
        let document = Document(parsing: markupSource, options: [])
        var checker = DuplicateTopicsSections(sourceFile: URL(fileURLWithPath: #file))
        checker.visit(document)
        XCTAssertEqual(2, checker.foundTopicsHeadings.count)
        XCTAssertEqual(1, checker.problems.count)
        
        let problem = checker.problems[0]
        XCTAssertTrue(problem.possibleSolutions.isEmpty)
        
        let duplicateHeading = document.child(at: 4)! as! Heading
        let diagnostic = problem.diagnostic
        XCTAssertEqual("org.swift.docc.MultipleTopicsSections", diagnostic.identifier)
        XCTAssertEqual(duplicateHeading.range, problem.diagnostic.range)
        
        let originalTopicsHeading = document.child(at: 2)! as! Heading
        let note = diagnostic.notes[0]
        XCTAssertEqual(originalTopicsHeading.range, note.range)
    }
}
