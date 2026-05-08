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
        
        directive.map { directive in
            var problems = [Problem]()
            let arguments = directive.arguments(problems: &problems)
            let x = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
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
            
            directive.map { directive in
                var problems = [Problem]()
                let arguments = directive.arguments(problems: &problems)
                let x = Semantic.Analyses.HasArgument<Intro, IntArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
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
            
            directive.map { directive in
                var problems = [Problem]()
                let arguments = directive.arguments(problems: &problems)
                let x = Semantic.Analyses.HasArgument<Intro, IntArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
                XCTAssertNil(x)
                XCTAssertEqual(1, problems.count)
                problems.first.map { problem in
                    XCTAssertEqual("org.swift.docc.HasArgument.x.ConversionFailed", problem.diagnostic.identifier)
                }
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
            
            directive.map { directive in
                var problems = [Problem]()
                let arguments = directive.arguments(problems: &problems)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
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
            
            directive.map { directive in
                var problems = [Problem]()
                let arguments = directive.arguments(problems: &problems)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
                XCTAssertTrue(problems.isEmpty)
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
            
            directive.map { directive in
                var problems = [Problem]()
                let arguments = directive.arguments(problems: &problems)
                let x = Semantic.Analyses.HasArgument<Intro, BoolArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
                XCTAssertEqual(1, problems.count)
                XCTAssertNil(x)
                problems.first.map { problem in
                    XCTAssertEqual("org.swift.docc.HasArgument.x.ConversionFailed", problem.diagnostic.identifier)
                    XCTAssertEqual(.warning, problem.diagnostic.severity)
                }
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
        
        directive.map { directive in
            var problems = [Problem]()
            let arguments = directive.arguments(problems: &problems)
            let x = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: nil).analyze(directive, arguments: arguments, problems: &problems)
            XCTAssertTrue(problems.isEmpty)
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
        
        directive.map { directive in
            var problems = [Problem]()
            let arguments = directive.arguments(problems: &problems)
            _ = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .error).analyze(directive, arguments: arguments, problems: &problems)
            _ = Semantic.Analyses.HasArgument<Intro, StringArgument>(severityIfNotFound: .warning).analyze(directive, arguments: arguments, problems: &problems)
            XCTAssertEqual([.error, .warning], problems.map { $0.diagnostic.severity })
        }
    }
}
