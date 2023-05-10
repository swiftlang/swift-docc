/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2023 Apple Inc. and the Swift project authors
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

    func testReceiveProblem() {
        let problem = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test diagnostic"), possibleSolutions: [])

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
        XCTAssert(logger.output.isEmpty)
        consumer.receive([problem])
        XCTAssertEqual(logger.output, "warning: Test diagnostic\n")
    }

    func testReceiveMultipleProblems() {
        let problem = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test diagnostic"), possibleSolutions: [])

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
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
        let solutionSummary = "Test solution summary"
        let explanation = "Test diagnostic explanation."
        let expectedLocation = "/path/to/file.md:1:8"
        
        let replacementRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 24, source: source)
        let replacement = Replacement(range: replacementRange, replacement: "Replacement text")
        
        do {
            let solution = Solution(summary: solutionSummary, replacements: [replacement])
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([problem])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary). \(solutionSummary).
            \(explanation)
            \(source):1:8-1:24: fixit: Replacement text
            
            """)
        }
        
        do {
            let firstSolutionSummary = "Test first solution summary!"  // end with punctuation
            let secondSolutionSummary = "Test second solution summary" // end without punctuation
            let firstSolution = Solution(summary: firstSolutionSummary, replacements: [replacement])
            let secondSolution = Solution(summary: secondSolutionSummary, replacements: [])
            
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [firstSolution, secondSolution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([problem])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary). \(firstSolutionSummary) \(secondSolutionSummary).
            \(explanation)
            
            """)
        }
        
        do {
            let firstInsertRange = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 1, column: 8, source: source)
            let secondInsertRange = SourceLocation(line: 1, column: 14, source: source)..<SourceLocation(line: 1, column: 14, source: source)
            let firstReplacement = Replacement(range: firstInsertRange, replacement: "ABC")
            let secondReplacement = Replacement(range: secondInsertRange, replacement: "abc")
            
            let solution = Solution(summary: solutionSummary, replacements: [firstReplacement, secondReplacement])
            
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, formattingOptions: [.formatConsoleOutputForTools])
            consumer.receive([problem])
            XCTAssertEqual(logger.output, """
            \(expectedLocation): error: \(summary). \(solutionSummary).
            \(explanation)
            \(source):1:8-1:8: fixit: ABC
            \(source):1:14-1:14: fixit: abc
            
            """)
        }
    }
}
