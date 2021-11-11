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

class TopicsSectionWithoutSubheadingTests: XCTestCase {
    func testEmptyDocument() {
        let checker = visitDocument(Document())
        XCTAssertTrue(checker.problems.isEmpty)
    }
    
    func testTopicsSectionHasSubheading() {
        let markupSource = """
# Title

Testing One

## Topics

### Test 2

Testing Two

# Test
"""
        let checker = visitSource(markupSource)
        XCTAssertTrue(checker.problems.isEmpty)
    }
    
    func testTopicsSectionHasNoSubheading() {
        let markupSource = """
# Title

Abstract.

## Topics

## Information

### Topic B
"""
        
        let document = Document(parsing: markupSource)
        let checker = visitDocument(document)
        XCTAssertEqual(1, checker.problems.count)
        
        let problem = checker.problems[0]
        XCTAssertTrue(problem.possibleSolutions.isEmpty)
        
        let noSubheadingHeading = document.child(at: 2)! as! Heading
        let diagnostic = problem.diagnostic
        XCTAssertEqual("org.swift.docc.TopicsSectionWithoutSubheading", diagnostic.identifier)
        XCTAssertEqual(noSubheadingHeading.range, diagnostic.range)
    }

    func testTopicsSectionIsFinalHeading() {
        let markupSource = """
# Title

Abstract.

## User

## Information

## Topics
"""
        
        let document = Document(parsing: markupSource)
        let checker = visitDocument(document)
        XCTAssertEqual(1, checker.problems.count)
        
        let problem = checker.problems[0]
        XCTAssertTrue(problem.possibleSolutions.isEmpty)
        
        let noSubheadingHeading = document.child(at: 4)! as! Heading
        let diagnostic = problem.diagnostic
        XCTAssertEqual("org.swift.docc.TopicsSectionWithoutSubheading", diagnostic.identifier)
        XCTAssertEqual(noSubheadingHeading.range, diagnostic.range)
    }
}

extension TopicsSectionWithoutSubheadingTests {
    func visitSource(_ source: String) -> TopicsSectionWithoutSubheading {
        let document = Document(parsing: source)
        return visitDocument(document)
    }
    
    func visitDocument(_ document: Document) -> TopicsSectionWithoutSubheading {
        var checker = TopicsSectionWithoutSubheading(sourceFile: nil)
        checker.visit(document)
        
        return checker
    }
}
