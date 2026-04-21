/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
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

    func testReceiveDiagnostic() {
        let diagnostic = Diagnostic(source: nil, severity: .warning, range: nil, identifier: "test-identifier", summary: "Test diagnostic")

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([diagnostic])
        XCTAssertEqual(logger.output, "warning: Test diagnostic [test-identifier]\n")
    }
    
    func testDisplaysGroupIdentifier() {
        let diagnostic = Diagnostic(source: nil, severity: .warning, range: nil, identifier: "test-identifier", groupIdentifier: "test-group-identifier", summary: "Test diagnostic")

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([diagnostic])
        XCTAssertEqual(logger.output, "warning: Test diagnostic [test-group-identifier]\n")
    }
    
    func testDoesNotDisplayNotYetModernizedIdentifier() {
        let diagnostic = Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.test-identifier", summary: "Test diagnostic")

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([diagnostic])
        XCTAssertEqual(logger.output, "warning: Test diagnostic\n")
    }

    func testReceiveMultipleDiagnostics() {
        let diagnostic = Diagnostic(source: nil, severity: .warning, range: nil, identifier: "test-identifier", summary: "Test diagnostic")

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([diagnostic, diagnostic])
        XCTAssertEqual(logger.output, """
        warning: Test diagnostic [test-identifier]
        warning: Test diagnostic [test-identifier]

        """)
    }
    
    func testEmitsFixits() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "test-identifier"
        let summary = "Test diagnostic summary"
        let solutionSummary = "Test solution summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"
        
        let replacementRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 24, source: source)
        let replacement = Replacement(range: replacementRange, replacement: "Replacement text")
        
        do {
            let solution = Solution(summary: solutionSummary, replacements: [replacement])
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation, possibleSolutions: [solution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([diagnostic])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary) [\(identifier)] \(solutionSummary).
            \(explanation)
            \(source):1:8-1:24: fixit: Replacement text
            
            """)
        }
        
        do {
            let firstSolutionSummary = "Test first solution summary!"  // end with punctuation
            let secondSolutionSummary = "Test second solution summary" // end without punctuation
            let firstSolution = Solution(summary: firstSolutionSummary, replacements: [replacement])
            let secondSolution = Solution(summary: secondSolutionSummary, replacements: [])
            
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation, possibleSolutions: [firstSolution, secondSolution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([diagnostic])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary) [\(identifier)] \(firstSolutionSummary) \(secondSolutionSummary).
            \(explanation)
            
            """)
        }
        
        do {
            let firstInsertRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 8, source: source)
            let secondInsertRange = SourceLocation(line: 1, column: 14, source: source)..<SourceLocation(line: 1, column: 14, source: source)
            let firstReplacement = Replacement(range: firstInsertRange, replacement: "ABC")
            let secondReplacement = Replacement(range: secondInsertRange, replacement: "abc")
            
            let solution = Solution(summary: solutionSummary, replacements: [firstReplacement, secondReplacement])
            
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation, possibleSolutions: [solution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([diagnostic])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary) [\(identifier)] \(solutionSummary).
            \(explanation)
            \(source):1:8-1:8: fixit: ABC
            \(source):1:14-1:14: fixit: abc
            
            """)
        }
    }
}
