/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
import Markdown

@testable import SwiftDocC

struct ParseDirectiveArgumentsTests {
    @Test(arguments: [
        // Missing quotation marks around string parameter
        "@Directive(argument: multiple words)": "org.swift.docc.Directive.MissingExpectedCharacter",
        // Missing quotation marks around string parameter in 2nd parameter
        "@Directive(argumentA: value, argumentB: multiple words)": "org.swift.docc.Directive.MissingExpectedCharacter",
        // Duplicate argument
        "@Directive(argumentA: value, argumentA: value)": "org.swift.docc.Directive.DuplicateArgument",
    ])
    func emitsWarningsForInvalidMarkup(_ invalidMarkup: String, expectedDiagnosticID: String) throws {
        let document = Document(parsing: invalidMarkup, options: .parseBlockDirectives)
        var problems = [Problem]()
        _ = (document.child(at: 0) as? BlockDirective)?.arguments(problems: &problems)
        
        let diagnostic = try #require(problems.first?.diagnostic)
        
        #expect(diagnostic.identifier == expectedDiagnosticID)
        #expect(diagnostic.severity == .warning)
    }
}
