/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

import Markdown

@testable import SwiftDocC

class ParseDirectiveArgumentsTests: XCTestCase {
    func testEmitsWarningForMissingExpectedCharacter() throws {
        let diagnostic = try XCTUnwrap(
            parse(rawDirective: "@Directive(argument: multiple words)").first
        )

        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.Directive.MissingExpectedCharacter")
        XCTAssertEqual(diagnostic.severity, .warning)
    }
    
    func testEmitsWarningForUnexpectedCharacter() throws {
        let diagnostic = try XCTUnwrap(
            parse(rawDirective: "@Directive(argumentA: value, argumentB: multiple words").first
        )

        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.Directive.MissingExpectedCharacter")
        XCTAssertEqual(diagnostic.severity, .warning)
    }
    
    func testEmitsWarningsForDuplicateArgument() throws {
        let diagnostic = try XCTUnwrap(
            parse(rawDirective: "@Directive(argumentA: value, argumentA: value").first
        )

        XCTAssertEqual(diagnostic.identifier, "org.swift.docc.Directive.DuplicateArgument")
        XCTAssertEqual(diagnostic.severity, .warning)
    }
    
    func parse(rawDirective: String) -> [Diagnostic] {
        let document = Document(parsing: rawDirective, options: .parseBlockDirectives)
        
        var problems = [Problem]()
        _ = (document.child(at: 0) as? BlockDirective)?.arguments(problems: &problems)
        return problems.map(\.diagnostic)
    }
}
