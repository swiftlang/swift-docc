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

    func testDefaultFormattingSeverityHighlight() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let expectedPath = "--> /path/to/file.md:1:8-10:21"

        do {
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, highlight: true)
            let diagnostic = Diagnostic(source: source, severity: .error, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
            consumer.receive([problem])
            try? consumer.finalize()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;31merror: \(summary)\u{001B}[0;39m
            \(explanation)
            \(expectedPath)
            """)
        }

        do {
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, highlight: true)
            let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
            consumer.receive([problem])
            try? consumer.finalize()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
            \(explanation)
            \(expectedPath)
            """)
        }

        do {
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, highlight: true)
            let diagnostic = Diagnostic(source: source, severity: .hint, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
            consumer.receive([problem])
            try? consumer.finalize()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;39mnotice: \(summary)\u{001B}[0;39m
            \(explanation)
            \(expectedPath)
            """)
        }

        do {
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, highlight: true)
            let diagnostic = Diagnostic(source: source, severity: .information, range: range, identifier: identifier, summary: summary, explanation: explanation)
            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
            consumer.receive([problem])
            try? consumer.finalize()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;39mnote: \(summary)\u{001B}[0;39m
            \(explanation)
            \(expectedPath)
            """)
        }
    }

    func testDefaultFormatting_DisplaysRelativePath() {
        let baseURL = URL(string: "/path/to")!
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)
        let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        consumer.receive([problem])
        try? consumer.finalize()
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
        \(explanation)
        --> file.md:1:8-10:21
        """)
    }

    func testDefaultFormatting_DisplaysNotes() {
        let source = URL(string: "/path/to/file.md")!
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, highlight: true)

        let noteSource = URL(string: "/path/to/other/file.md")!
        let noteRange = SourceLocation(line: 1, column: 1, source: noteSource)..<SourceLocation(line: 1, column: 20, source: noteSource)

        let diagnostic = Diagnostic(
            source: source,
            severity: .warning,
            range: range,
            identifier: identifier,
            summary: summary,
            explanation: explanation,
            notes: [DiagnosticNote(source: noteSource, range: noteRange, message: "This is a note")]
        )
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        consumer.receive([problem])
        try? consumer.finalize()

        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
        \(explanation)
        /path/to/other/file.md:1:1: This is a note
        --> /path/to/file.md:1:8-10:21
        """)
    }

    func testDefaultFormatting_DisplaysMultipleDiagnosticsSorted() {
        let identifier = "org.swift.docc.test-identifier"
        let firstProblem = {
            let source = URL(string: "/path/to/file.md")!
            let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)

            return Problem(
                diagnostic: Diagnostic(
                    source: source,
                    severity: .warning,
                    range: range,
                    identifier: identifier,
                    summary: "First diagnostic summary",
                    explanation: "First diagnostic explanation",
                    notes: []
                ),
                possibleSolutions: []
            )
        }()
        let secondProblem = {
            let source = URL(string: "/path/to/file.md")!
            let range = SourceLocation(line: 12, column: 1, source: source)..<SourceLocation(line: 12, column: 10, source: source)

            return Problem(
                diagnostic: Diagnostic(
                    source: source,
                    severity: .warning,
                    range: range,
                    identifier: identifier,
                    summary: "Second diagnostic summary",
                    explanation: "Second diagnostic explanation",
                    notes: []
                ),
                possibleSolutions: []
            )
        }()

        let thirdProblem = {
            let source = URL(string: "/path/to/other/file.md")!

            return Problem(
                diagnostic: Diagnostic(
                    source: source,
                    severity: .warning,
                    range: nil,
                    identifier: identifier,
                    summary: "Third diagnostic summary",
                    explanation: "Third diagnostic explanation",
                    notes: []
                ),
                possibleSolutions: []
            )
        }()

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, highlight: true)

        consumer.receive([firstProblem, secondProblem, thirdProblem])
        try? consumer.finalize()
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: First diagnostic summary\u{001B}[0;39m
        First diagnostic explanation
        --> /path/to/file.md:1:8-10:21

        \u{001B}[1;33mwarning: Second diagnostic summary\u{001B}[0;39m
        Second diagnostic explanation
        --> /path/to/file.md:12:1-12:10

        \u{001B}[1;33mwarning: Third diagnostic summary\u{001B}[0;39m
        Third diagnostic explanation
        --> /path/to/other/file.md
        """)
    }

    func testDefaultFormatting_DisplaysSource() {
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let baseURL =  Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let source = baseURL.appendingPathComponent("TestTutorial.tutorial")
        let range = SourceLocation(line: 44, column: 59, source: source)..<SourceLocation(line: 44, column: 138, source: source)

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)

        let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        consumer.receive([problem])
        try? consumer.finalize()
        print(logger.output)
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
        \(explanation)
          --> TestTutorial.tutorial:44:59-44:138
        42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
        43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
        44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;39m
        45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
        46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
        """)
    }

    func testDefaultFormatting_DisplaysPossibleSolutionsSummary() {
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let baseURL =  Bundle.module.url(
            forResource: "TestBundle", withExtension: "docc", subdirectory: "Test Bundles")!
        let source = baseURL.appendingPathComponent("TestTutorial.tutorial")
        let diagnosticRange = SourceLocation(line: 44, column: 59, source: source)..<SourceLocation(line: 44, column: 138, source: source)
        let diagnostic = Diagnostic(source: source, severity: .warning, range: diagnosticRange, identifier: identifier, summary: summary, explanation: explanation)

        do { // Displays solutions with single replacement at the replacement's source.
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)

            let solutionRange = SourceLocation(line: 44, column: 59, source: source)..<SourceLocation(line: 44, column: 60, source: source)
            let solution = Solution(
                summary: "Solution summary",
                replacements: [.init(range: solutionRange, replacement: "replacement")]
            )

            let otherSolutionRange = SourceLocation(line: 44, column: 62, source: source)..<SourceLocation(line: 44, column: 64, source: source)
            let otherSolution = Solution(
                summary: "Other solution summary",
                replacements: [.init(range: otherSolutionRange, replacement: "replacement")]
            )

            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution, otherSolution])
            consumer.receive([problem])
            try? consumer.finalize()

            print(logger.output)
            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;39m
               |                                                           │  ╰─\u{001B}[1;39msuggestion: Other solution summary\u{001B}[0;39m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;39m
            45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
            46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
            """)
        }

        do { // Displays solution without replacement at the beginning of the diagnostic range. 
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)

            let solution = Solution(summary: "Solution summary", replacements: [])

            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            consumer.receive([problem])
            try? consumer.finalize()

            print(logger.output)
            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;39m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;39m
            45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
            46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
            """)
        }

        do { // Displays solution with many replacements at the beginning of the diagnostic range.
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)

            let firstReplacement = Replacement(
                range: SourceLocation(line: 44, column: 60, source: source)..<SourceLocation(line: 44, column: 64, source: source),
                replacement: "first replacement"
            )
            let secondReplacement = Replacement(
                range: SourceLocation(line: 44, column: 68, source: source)..<SourceLocation(line: 44, column: 70, source: source),
                replacement: "second replacement"
            )
            let solution = Solution(summary: "Solution summary", replacements: [firstReplacement, secondReplacement])

            let problem = Problem(diagnostic: diagnostic, possibleSolutions: [solution])
            consumer.receive([problem])
            try? consumer.finalize()

            print(logger.output)
            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;39m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;39m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;39m
            45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
            46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
            """)
        }
    }
}
