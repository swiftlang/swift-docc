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

final class TestParent: Semantic, DirectiveConvertible {
    static let directiveName = "Parent"
    static let introducedVersion = "1.2.3"
    let originalMarkup: BlockDirective
    let testChildren: [TestChild]
    init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, diagnostics: inout [Diagnostic]) {
        precondition(TestParent.canConvertDirective(directive))
        self.originalMarkup = directive
        self.testChildren = directive.children.compactMap { child -> TestChild? in
            guard let childDirective = child as? BlockDirective,
                childDirective.name == TestChild.directiveName else {
                    return nil
            }
            return TestChild(from: directive, source: nil, for: bundle, featureFlags: featureFlags, diagnostics: &diagnostics)
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
    init?(from directive: BlockDirective, source: URL?, for bundle: DocumentationBundle, featureFlags: FeatureFlags, diagnostics: inout [Diagnostic]) {
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
            var diagnostics = [Diagnostic]()
            if let directive {
                let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
                XCTAssertTrue(matches.isEmpty)
                XCTAssertTrue(remainder.elements.isEmpty)
            }
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.severity, .error)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasAtLeastOne<Parent, TestChild>")
        }
        
        // Test ignoring diagnostics
        do {
            var diagnostics = [Diagnostic]()
            if let directive {
                let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: nil).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
                XCTAssertTrue(matches.isEmpty)
                XCTAssertTrue(remainder.elements.isEmpty)
            }
            XCTAssertTrue(diagnostics.isEmpty)
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
        var diagnostics = [Diagnostic]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertEqual(1, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(diagnostics.isEmpty)
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
        var diagnostics = [Diagnostic]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertEqual(3, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(diagnostics.isEmpty)
    }
    
    func testAlternateDirectiveTitle() async throws {
        let source = """
@AlternateParent {
   @AlternateChild
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        var diagnostics = [Diagnostic]()
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try await testBundleAndContext()
        
        if let directive {
            let (matches, remainder) = Semantic.Analyses.HasAtLeastOne<TestParent, TestChild>(severityIfNotFound: .error).analyze(directive, children: directive.children, source: nil, for: bundle, diagnostics: &diagnostics)
            XCTAssertEqual(1, matches.count)
            XCTAssertTrue(remainder.elements.isEmpty)
        }
        XCTAssertTrue(diagnostics.isEmpty)
    }
}
