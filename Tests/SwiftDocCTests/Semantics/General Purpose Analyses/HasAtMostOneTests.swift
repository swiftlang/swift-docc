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

class HasAtMostOneTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Parent"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>(featureFlags: context.configuration.featureFlags).analyze(directive, children: directive.children, source: nil, for: context.inputs, diagnostics: &diagnostics)
            XCTAssertNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(diagnostics.isEmpty)
        }
    }
    
    func testHasOne() async throws {
        let source = """
@Parent {
   @Child
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>(featureFlags: context.configuration.featureFlags).analyze(directive, children: directive.children, source: nil, for: context.inputs, diagnostics: &diagnostics)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(diagnostics.isEmpty)
        }
    }
    
    func testHasMany() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>(featureFlags: context.configuration.featureFlags).analyze(directive, children: directive.children, source: nil, for: context.inputs, diagnostics: &diagnostics)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertEqual(2, diagnostics.count)
            XCTAssertEqual("org.swift.docc.HasAtMostOne<Parent, \(TestChild.self)>.DuplicateChildren", diagnostics.first?.identifier)
            XCTAssertEqual("org.swift.docc.HasAtMostOne<Parent, \(TestChild.self)>.DuplicateChildren", diagnostics.last?.identifier)
            XCTAssertEqual("""
                 warning: Duplicate 'Child' child directive
                 The 'Parent' directive must have at most one 'Child' child directive
                 """, diagnostics.first.map { DiagnosticConsoleWriter.formattedDescription(for: $0, options: .formatConsoleOutputForTools) }
            )
        }
    }
    
    func testAlternateDirectiveTitle() async throws {
        let source = """
@AlternateParent {
   @AlternateChild
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasAtMostOne<TestParent, TestChild>(featureFlags: context.configuration.featureFlags).analyze(directive, children: directive.children, source: nil, for: context.inputs, diagnostics: &diagnostics)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(diagnostics.isEmpty)
        }
    }
}

