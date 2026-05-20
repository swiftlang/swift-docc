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

class HasArgumentOfTypeTests: XCTestCase {
    func testString() throws {
        enum StringArgument: SwiftDocC.DirectiveArgument {
            typealias ArgumentValue = String
            static let argumentName = "x"
        }
        let source = "@dir(x: x)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let arguments = directive.arguments(diagnostics: &diagnostics)
            let x = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
            XCTAssertNotNil(x)
            x.map { x in
                XCTAssertEqual("x", x)
            }
        }
    }
    
    func testInt() throws {
        enum IntArgument: SwiftDocC.DirectiveArgument {
            typealias ArgumentValue = Int
            static let argumentName = "x"
        }

        do { // Valid
            let source = "@dir(x: 1)"
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            if let directive {
                var diagnostics = [Diagnostic]()
                let arguments = directive.arguments(diagnostics: &diagnostics)
                let x = Semantic.Analyses.HasArgument<Intro, IntArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
                XCTAssertNotNil(x)
                x.map { x in
                    XCTAssertEqual(1, x)
                }
            }
        }
        
        do { // Invalid
            let source = "@dir(x: blah)"
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            if let directive {
                var diagnostics = [Diagnostic]()
                let arguments = directive.arguments(diagnostics: &diagnostics)
                let x = Semantic.Analyses.HasArgument<Intro, IntArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
                XCTAssertNil(x)
                XCTAssertEqual(1, diagnostics.count)
                XCTAssertEqual("org.swift.docc.HasArgument.x.ConversionFailed", diagnostics.first?.identifier)
            }
        }
    }
    
    func testBool() throws {
        enum BoolArgument: SwiftDocC.DirectiveArgument {
            typealias ArgumentValue = Bool
            static let argumentName = "x"
        }

        do { // Valid: true
            let source = "@dir(x: true)"
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            if let directive {
                var diagnostics = [Diagnostic]()
                let arguments = directive.arguments(diagnostics: &diagnostics)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
                XCTAssertNotNil(x)
                x.map { x in
                    XCTAssertTrue(x)
                }
            }
        }
        
        do {
            let source = "@dir(x: false)"
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            if let directive {
                var diagnostics = [Diagnostic]()
                let arguments = directive.arguments(diagnostics: &diagnostics)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
                XCTAssertTrue(diagnostics.isEmpty)
                XCTAssertNotNil(x)
                x.map { x in
                    XCTAssertFalse(x)
                }
            }
        }
        
        do {
            let source = "@dir(x: blah)"
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)
            
            if let directive {
                var diagnostics = [Diagnostic]()
                let arguments = directive.arguments(diagnostics: &diagnostics)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
                XCTAssertEqual(1, diagnostics.count)
                XCTAssertNil(x)
                
                XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.x.ConversionFailed")
                XCTAssertEqual(diagnostics.first?.severity, .warning)
            }
        }
    }
    
    func testOptionalArgument() throws {
        enum StringArgument: SwiftDocC.DirectiveArgument {
            typealias ArgumentValue = String
            static let argumentName = "x"
        }

        let source = "@dir"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let arguments = directive.arguments(diagnostics: &diagnostics)
            let x = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: nil).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
            XCTAssertTrue(diagnostics.isEmpty)
            XCTAssertNil(x)
        }
    }
    
    func testParameterizedSeverity() throws {
        enum StringArgument: SwiftDocC.DirectiveArgument {
            typealias ArgumentValue = String
            static let argumentName = "x"
        }
        
        let source = "@dir"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        if let directive {
            var diagnostics = [Diagnostic]()
            let arguments = directive.arguments(diagnostics: &diagnostics)
            _ = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
            _ = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, diagnostics: &diagnostics)
            XCTAssertEqual([.error, .warning], diagnostics.map(\.severity))
        }
    }
}
