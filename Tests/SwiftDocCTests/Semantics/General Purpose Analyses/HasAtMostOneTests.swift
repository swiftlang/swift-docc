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

class HasAtMostOneTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Parent"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>().analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(problems.isEmpty)
        }
    }
    
    func testHasOne() throws {
        let source = """
@Parent {
   @Child
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>().analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(problems.isEmpty)
        }
    }
    
    func testHasMany() throws {
        let source = """
@Parent {
   @Child
   @Child
   @Child
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>().analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertEqual(2, problems.count)
            XCTAssertEqual("org.swift.docc.HasAtMostOne<Parent, \(TestChild.self)>.DuplicateChildren", problems[0].diagnostic.identifier)
            XCTAssertEqual("org.swift.docc.HasAtMostOne<Parent, \(TestChild.self)>.DuplicateChildren", problems[1].diagnostic.identifier)
            XCTAssertEqual("""
                 warning: Duplicate 'Child' child directive
                 The 'Parent' directive must have at most one 'Child' child directive
                 """, problems[0].diagnostic.localizedDescription)
        }
    }
    
    func testAlternateDirectiveTitle() throws {
        let source = """
@AlternateParent {
   @AlternateChild
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>().analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(problems.isEmpty)
        }
    }
}

