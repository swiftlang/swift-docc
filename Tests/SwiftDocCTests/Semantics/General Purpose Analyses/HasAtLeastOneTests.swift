/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

final class TestParent: Semantic, DirectiveConvertible {
    static let directiveName = "Parent"
    static let introducedVersion = "1.2.3"
    let originalMarkup: BlockDirective
    let testChildren: [TestChild]
    init?(from directive: BlockDirective, source: URL?, for inputs: DocumentationContext.Inputs, problems: inout [Problem]) {
        precondition(TestParent.canConvertDirective(directive))
        self.originalMarkup = directive
        self.testChildren = directive.children.compactMap { child -> TestChild? in
            guard let childDirective = child as? BlockDirective,
                childDirective.name == TestChild.directiveName else {
                    return nil
            }
            return TestChild(from: directive, source: nil, for: inputs, problems: &problems)
        }
    }
    
    static func canConvertDirective(_ directive: BlockDirective) -> Bool {
        return directiveName == directive.name || "AlternateParent" == directive.name
    }
}

final class TestChild: Semantic, DirectiveConvertible {
    static let directiveName = "Child"
    static let introducedVersion = "1.2.3"
    let originalMarkup: BlockDirective
    init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationContext.Inputs, problems: inout [Problem]) {
        precondition(TestChild.canConvertDirective(directive))
        self.originalMarkup = directive
    }
    
    static func canConvertDirective(_ directive: BlockDirective) -> Bool {
        return directiveName == directive.name || "AlternateChild" == directive.name
    }
}

class HasAtLeastOneTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Parent"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        do {
            var problems = [Problem]()
            directive.map { directive in
                let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, problems: &problems)
                XCTAssertTrue(matches.isEmpty)
                XCTAssertTrue(remainder.elements.isEmpty)
            }
            XCTAssertEqual(1, problems.count)
            problems.first.map { problem in
                XCTAssertEqual(.error, problem.diagnostic.severity)
                XCTAssertEqual("org.swift.docc.HasAtLeastOne<Parent, TestChild>", problem.diagnostic.identifier)
            }
        }
        
        // Test ignoring diagnostics
        do {
            var problems = [Problem]()
            directive.map { directive in
                let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: nil, for: bundle, problems: &problems)
                XCTAssertTrue(matches.isEmpty)
                XCTAssertTrue(remainder.elements.isEmpty)
            }
            XCTAssertTrue(problems.isEmpty)
        }
    }
    
    func testOne() async throws {
        let source = """
@Parent {
   @Child
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        var problems = [Problem]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        directive.map { directive in
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, problems: &problems)
            XCTAssertEqual(1, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testMany() async throws {
        let source = """
@Parent {
   @Child
   @Child
   @Child
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        var problems = [Problem]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        directive.map { directive in
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, problems: &problems)
            XCTAssertEqual(3, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testAlternateDirectiveTitle() async throws {
        let source = """
@AlternateParent {
   @AlternateChild
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        var problems = [Problem]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        directive.map { directive in
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, problems: &problems)
            XCTAssertEqual(1, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(problems.isEmpty)
    }
}
