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

class HasExactlyOneTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Parent"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasExactlyOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertEqual(1, diagnostics.count)
            if let diagnostic = diagnostics.first {
                XCTAssertEqual(diagnostic.identifier, "org.swift.docc.HasExactlyOne<Parent, TestChild>.Missing")
                XCTAssertEqual(
                    DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: .formatConsoleOutputForTools),
                    """
                    error: Missing 'Child' child directive
                    The 'Parent' directive must have exactly one 'Child' child directive
                    """
                )
            }
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
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasExactlyOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
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
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasExactlyOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertEqual(2, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasExactlyOne<Parent, \(TestChild.self)>.DuplicateChildren")
            XCTAssertEqual(diagnostics.last?.identifier,  "org.swift.docc.HasExactlyOne<Parent, \(TestChild.self)>.DuplicateChildren")
            XCTAssert(diagnostics.allSatisfy { $0.severity == .error })
            XCTAssertEqual("""
                 error: Duplicate 'Child' child directive
                 The 'Parent' directive must have exactly one 'Child' child directive
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
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let (match, remainder) = Semantic.Analyses.HasExactlyOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertNotNil(match)
            XCTAssertTrue(remainder.isEmpty)
            XCTAssertTrue(diagnostics.isEmpty)
        }
    }
}
