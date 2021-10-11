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

class JustificationTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Justification"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(directive.name, Justification.directiveName)
            let justification = Justification(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(justification)
            XCTAssertNil(justification?.reaction)
            XCTAssertTrue(problems.isEmpty)
            justification.map { justification in
                
            }
        }
    }
    
    func testValid() throws {
        let source = """
@Justification(reaction: "Correct!") {
   Here is some content.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(directive.name, Justification.directiveName)
            let justification = Justification(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertTrue(problems.isEmpty)
            XCTAssertNotNil(justification)
            XCTAssertEqual(justification?.reaction, "Correct!")
            justification.map { justification in
                let expectedDump = """
Justification @1:1-3:2 reaction: 'Correct!'
└─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, justification.dump())
            }
        }
    }
}
