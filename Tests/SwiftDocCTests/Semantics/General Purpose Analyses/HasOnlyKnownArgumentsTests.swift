/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
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
        
        var diagnostics = [Diagnostic]()
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar"]).analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
        
        XCTAssertTrue(diagnostics.isEmpty)
    }
    
    /// When there are no allowed arguments, diagnose for any provided argument.
    func testNoArguments() throws {
        let source = "@dir(foo: x, bar: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        var diagnostics = [Diagnostic]()
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: []).analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
        
        XCTAssertEqual(diagnostics.count, 2)
    }
    
    /// When there are arguments that aren't allowed, diagnose.
    func testInvalidArguments() throws {
        let source = "@dir(foo: x, bar: x, baz: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        var diagnostics = [Diagnostic]()
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar"]).analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
        
        XCTAssertEqual(diagnostics.count, 1)
    }
    
    func testInvalidArgumentsWithSuggestions() throws {
        let source = "@dir(foo: x, bar: x, baz: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        
        var diagnostics = [Diagnostic]()
        _ = Semantic.Analyses.HasOnlyKnownArguments<Intro>(severityIfFound: .error, allowedArguments: ["foo", "bar", "woof", "bark"]).analyze(directive, children: directive.children, source: nil, diagnostics: &diagnostics)
        
        XCTAssertEqual(diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual("error: Unknown argument 'baz' in Intro. These arguments are currently unused but allowed: 'bark', 'woof'.", DiagnosticConsoleWriter.formattedDescription(for: diagnostic, options: .formatConsoleOutputForTools))
    }
}
