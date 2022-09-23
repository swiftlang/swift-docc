/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC
import Markdown

class HasOnlyKnownDirectivesTests: XCTestCase {
    /// No diagnostics when there are two allowed directives, one of which is optional and unused.
    func testValidDirective() throws {
        let source = """
@dir {
   @valid
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: ["valid", "bar"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertTrue(problems.isEmpty)
    }
    
    /// When there are no allowed directives, diagnose for any provided directive.
    func testNoArguments() throws {
        let source = """
@dir {
   @invalid1
   
   @invalid2
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: []).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 2)
    }
    
    /// When there are directives that aren't allowed, diagnose.
    func testInvalidArguments() throws {
        let source = """
@dir {
   @valid
   
   @invalid
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: ["valid"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 1)
    }
    
    /// When there are directives that aren't allowed, diagnose.
    func testAllowsMarkup() throws {
        let source = """
@dir {
   @valid

   arbitrary markup
   
   @invalid
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        // Does allow arbitrary markup
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: ["valid"], allowsMarkup: true).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 1)
        
        // Doesn't allow arbitrary markup
        problems = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: ["valid"], allowsMarkup: false).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 2)
    }
    
    func testInvalidDirectivesWithSuggestions() throws {
        let source = """
@dir {
   @foo
   
   @bar
   
   @baz
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlyKnownDirectives<Intro>(severityIfFound: .error, allowedDirectives: ["foo", "bar", "woof", "bark"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 1)
        guard let first = problems.first else { return }
        XCTAssertEqual("error: 'baz' directive is unsupported as a child of the 'dir' directive\nThese directives are allowed: 'Comment', 'bar', 'bark', 'foo', 'woof'", first.diagnostic.localizedDescription)
    }
}

