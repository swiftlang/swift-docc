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

class HasOnlyKnownArgumentsTests: XCTestCase {
    /// No diagnostics when there are two allowed arguments, one of which is optional and unused.
    func testValidDirective() throws {
        let source = "@dir(foo: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertTrue(problems.isEmpty)
    }
    
    /// When there are no allowed arguments, diagnose for any provided argument.
    func testNoArguments() throws {
        let source = "@dir(foo: x, bar: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: []).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 2)
    }
    
    /// When there are arguments that aren't allowed, diagnose.
    func testInvalidArguments() throws {
        let source = "@dir(foo: x, bar: x, baz: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 1)
    }
    
    func testInvalidArgumentsWithSuggestions() throws {
        let source = "@dir(foo: x, bar: x, baz: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar", "woof", "bark"]).analyze(directive, children: directive.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.count, 1)
        guard let first = problems.first else { return }
        XCTAssertEqual("error: Unknown argument 'baz' in Intro. These arguments are currently unused but allowed: 'bark', 'woof'.", first.diagnostic.localizedDescription)
    }
}
