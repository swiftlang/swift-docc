/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC

class DiagnosticConsoleWriterTests: XCTestCase {

    class Logger: TextOutputStream {
        var output = ""

        func write(_ string: String) {
            output += string
        }
    }

    func testUsesStandardErrorByDefault() throws {
        let consumer = DiagnosticConsoleWriter(formattingOptions: [])
        let logHandle = try XCTUnwrap(consumer.outputStream as? LogHandle)
        switch logHandle {
        case .standardError:
            break
        default:
            XCTFail("Default output stream for \(DiagnosticConsoleWriter.self) should be stderr")
        }
    }

    func testRecieveProblem() {
        let problem = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test diagnostic"), possibleSolutions: [])

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([problem])
        XCTAssertEqual(logger.output, "warning: Test diagnostic\n")
    }

    func testRecieveMultipleProblems() {
        let problem = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test diagnostic"), possibleSolutions: [])

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([problem, problem])
        XCTAssertEqual(logger.output, """
        warning: Test diagnostic
        warning: Test diagnostic

        """)
    }
    
    func testEmitsFixits() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"
        
        let replacementRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 24, source: source)
        let replacement = Replacement(range: replacementRange, replacement: "Replacement text")
        let solution = Solution(summary: "", replacements: [replacement])
        let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
        
        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.showFixits])
        consumer.receive([problem])
        XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary)
            \(explanation)
            \(source):1:8-1:24: fixit: Replacement text
            
            """)
    }
    
    func testDoesNotEmitFixits() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"
        
        let replacementRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 24, source: source)
        let replacement = Replacement(range: replacementRange, replacement: "Replacement text")
        let solution = Solution(summary: "", replacements: [replacement])
        let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
        
        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [])
        consumer.receive([problem])
        XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary)
            \(explanation)
            
            """)
    }
}
