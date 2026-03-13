/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Markdown
@testable import SwiftDocC
import DocCTestUtilities

class DiagnosticConsoleWriterDefaultFormattingTest: XCTestCase {

    class Logger: TextOutputStream {
        var output = ""

        func write(_ string: String) {
            output += string
        }
    }

    func testSeverityHighlight() {
        let source = URL(fileURLWithPath: "/path/to/file.md")
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
            try? consumer.flush()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;31merror: \(summary)\u{001B}[0;0m
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
            try? consumer.flush()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
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
            try? consumer.flush()
            XCTAssertEqual(logger.output, """
            \u{001B}[1;39mnote: \(summary)\u{001B}[0;0m
            \(explanation)
            \(expectedPath)
            
            """)
        }
    }

    func testDisplaysRelativePath() {
        let baseURL = URL(fileURLWithPath: "/path/to")
        let source = URL(fileURLWithPath: "/path/to/file.md")
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)
        let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        consumer.receive([problem])
        try? consumer.flush()
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
        \(explanation)
        --> file.md:1:8-10:21
        
        """)
    }

    func testDisplaysNotes() {
        let source = URL(fileURLWithPath: "/path/to/file.md")
        let range = SourceLocation(line: 1, column: 8, source: source)..<SourceLocation(line: 10, column: 21, source: source)
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, highlight: true)

        let noteSource = URL(fileURLWithPath: "/path/to/other/file.md")
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
        try? consumer.flush()

        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
        \(explanation)
        /path/to/other/file.md:1:1: This is a note
        --> /path/to/file.md:1:8-10:21
        
        """)
    }

    func testDisplaysMultipleDiagnosticsSorted() {
        let identifier = "org.swift.docc.test-identifier"
        let firstProblem = {
            let source = URL(fileURLWithPath: "/path/to/file.md")
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
            let source = URL(fileURLWithPath: "/path/to/file.md")
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
            let source = URL(fileURLWithPath: "/path/to/other/file.md")

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
        try? consumer.flush()
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: First diagnostic summary\u{001B}[0;0m
        First diagnostic explanation
        --> /path/to/file.md:1:8-10:21

        \u{001B}[1;33mwarning: Second diagnostic summary\u{001B}[0;0m
        Second diagnostic explanation
        --> /path/to/file.md:12:1-12:10

        \u{001B}[1;33mwarning: Third diagnostic summary\u{001B}[0;0m
        Third diagnostic explanation
        --> /path/to/other/file.md
        
        """)
    }

    func testDisplaysSource() {
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let baseURL =  Bundle.module.url(
            forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
        let source = baseURL.appendingPathComponent("TestTutorial.tutorial")
        let range = SourceLocation(line: 44, column: 59, source: source)..<SourceLocation(line: 44, column: 138, source: source)

        let logger = Logger()
        let consumer = DiagnosticConsoleWriter(logger, baseURL: baseURL, highlight: true)

        let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: identifier, summary: summary, explanation: explanation)
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        consumer.receive([problem])
        try? consumer.flush()
        
        XCTAssertEqual(logger.output, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
        \(explanation)
          --> TestTutorial.tutorial:44:59-44:138
        42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
        43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
        44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;0m
        45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
        46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
        
        """)
    }

    func testDisplaysSourceAndProperlyHighlightsRangesSpanningEmoji() throws {
        let fs = try TestFileSystem(folders: [
            Folder(name: "Something.docc", content: [
                Folder(name: "Nested folder", content: [
                    TextFile(name: "Article.md", utf8Content: """
                    # Title
                    
                    A short abstract with emoji 💻 in it.
                    
                    @Metadata {
                      @TechnologyRoot
                    }
                    
                    """)
                ])
            ])
        ])
        
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        
        let (bundle, _) = try DocumentationContext.InputsProvider(fileManager: fs)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
        
        let baseURL = bundle.baseURL
        let source = try XCTUnwrap(bundle.markupURLs.first)
        let range = SourceLocation(line: 3, column: 18, source: source)..<SourceLocation(line: 3, column: 36, source: source)

        let logStorage = LogHandle.LogStorage()
        let consumer = DiagnosticConsoleWriter(LogHandle.memory(logStorage), baseURL: baseURL, highlight: true, dataProvider: fs)

        let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: "org.swift.docc.test-identifier", summary: summary, explanation: explanation)
        consumer.receive([Problem(diagnostic: diagnostic, possibleSolutions: [])])
        try consumer.flush()
        
        XCTAssertEqual(logStorage.text, """
        \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
        \(explanation)
         --> Something.docc/Nested folder/Article.md:3:18-3:36
        1 | # Title
        2 |
        3 + A short abstract \u{001B}[1;32mwith emoji 💻 in\u{001B}[0;0m it.
        4 |
        5 | @Metadata {
        
        """)
    }

    func testDisplaysPossibleSolutionsSummary() {
        let identifier = "org.swift.docc.test-identifier"
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        let baseURL =  Bundle.module.url(
            forResource: "LegacyBundle_DoNotUseInNewTests", withExtension: "docc", subdirectory: "Test Bundles")!
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
            try? consumer.flush()

            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;0m
               |                                                           │  ╰─\u{001B}[1;39msuggestion: Other solution summary\u{001B}[0;0m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;0m
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
            try? consumer.flush()

            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;0m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;0m
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
            try? consumer.flush()

            XCTAssertEqual(logger.output, """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
              --> TestTutorial.tutorial:44:59-44:138
            42 |          ut labore et dolore magna aliqua. Phasellus faucibus scelerisque eleifend donec pretium.
            43 |          Ultrices dui sapien eget mi proin sed libero enim. Quis auctor elit sed vulputate mi sit amet.
            44 +          This section link refers to this section itself: \u{001B}[1;32m<doc:/tutorials/Test-Bundle/TestTutorial#Create-a-New-AR-Project-%F0%9F%92%BB>.\u{001B}[0;0m
               |                                                           ╰─\u{001B}[1;39msuggestion: Solution summary\u{001B}[0;0m
            45 |          This is an external link to Swift documentation: [Swift Documentation](https://swift.org/documentation/).
            46 |          This section link refers to the next section in this file: <doc:/tutorials/Test-Bundle/TestTutorial#Initiate-ARKit-Plane-Detection>.
            
            """)
        }
    }
    
    func testClampsDiagnosticRangeToSourceRange() throws {
        let fs = try TestFileSystem(folders: [
            Folder(name: "Something.docc", content: [
                TextFile(name: "Article.md", utf8Content: """
                # Title
                
                A very short article with only an abstract.
                """)
            ])
        ])
        
        let summary = "Test diagnostic summary"
        let explanation = "Test diagnostic explanation."
        
        let (bundle, _) = try DocumentationContext.InputsProvider(fileManager: fs)
            .inputsAndDataProvider(startingPoint: URL(fileURLWithPath: "/"), options: .init())
        
        let baseURL = bundle.baseURL
        let source = try XCTUnwrap(bundle.markupURLs.first)
        
        typealias Location = (line: Int, column: Int)
        func logMessageFor(start: Location, end: Location) throws -> String {
            let range = SourceLocation(line: start.line, column: start.column, source: source)..<SourceLocation(line: end.line, column: end.column, source: source)
            
            let logStorage = LogHandle.LogStorage()
            let consumer = DiagnosticConsoleWriter(LogHandle.memory(logStorage), baseURL: baseURL, highlight: true, dataProvider: fs)
            
            let diagnostic = Diagnostic(source: source, severity: .warning, range: range, identifier: "org.swift.docc.test-identifier", summary: summary, explanation: explanation)
            consumer.receive([Problem(diagnostic: diagnostic, possibleSolutions: [])])
            try consumer.flush()
            
            // There are no lines before line 1
            return logStorage.text
        }
        
        // Highlight the "Title" word on line 1
        XCTAssertEqual(try logMessageFor(start: (line: 1, column: 3), end: (line: 1, column: 8)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
             --> Something.docc/Article.md:1:3-1:8
            1 + # \u{001B}[1;32mTitle\u{001B}[0;0m
            2 |
            3 | A very short article with only an abstract.
            
            """)
                       
        // Highlight the "short" word on line 3
        XCTAssertEqual(try logMessageFor(start: (line: 3, column: 8), end: (line: 3, column: 13)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
             --> Something.docc/Article.md:3:8-3:13
            1 | # Title
            2 |
            3 + A very \u{001B}[1;32mshort\u{001B}[0;0m article with only an abstract.
            
            """)
        
        // Extend the highlight beyond the end of that line
        XCTAssertEqual(try logMessageFor(start: (line: 3, column: 8), end: (line: 3, column: 100)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
             --> Something.docc/Article.md:3:8-3:100
            1 | # Title
            2 |
            3 + A very \u{001B}[1;32mshort article with only an abstract.\u{001B}[0;0m
            
            """)
        
        // Extend the highlight beyond the start of that line
        XCTAssertEqual(try logMessageFor(start: (line: 3, column: -4), end: (line: 3, column: 13)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
             --> Something.docc/Article.md:3:1-3:13
            1 | # Title
            2 |
            3 + \u{001B}[1;32mA very short\u{001B}[0;0m article with only an abstract.
            
            """)
        
        // Highlight a line before the start of the file
        XCTAssertEqual(try logMessageFor(start: (line: -4, column: 1), end: (line: -4, column: 5)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
            --> Something.docc/Article.md:1:1-1:5
            
            """)
        
        // Highlight a line after the end of the file
        XCTAssertEqual(try logMessageFor(start: (line: 100, column: 1), end: (line: 100, column: 5)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
            --> Something.docc/Article.md:100:1-100:5
            
            """)
        
        // Extended the highlighted lines before the start of the file
        XCTAssertEqual(try logMessageFor(start: (line: -4, column: 1), end: (line: 1, column: 5)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
            --> Something.docc/Article.md:1:1-1:5
            
            """)
        
        // Extended the highlighted lines after the end of the file
        XCTAssertEqual(try logMessageFor(start: (line: 1, column: 1), end: (line: 100, column: 5)), """
            \u{001B}[1;33mwarning: \(summary)\u{001B}[0;0m
            \(explanation)
            --> Something.docc/Article.md:1:1-100:5
            
            """)
    }
    
    func testEmitAdditionReplacementSolution() throws {
        func problemsLoggerOutput(possibleSolutions: [Solution]) -> String {
            let logger = Logger()
            let consumer = DiagnosticConsoleWriter(logger, highlight: true)
            let problem = Problem(diagnostic: Diagnostic(source: URL(fileURLWithPath: "/path/to/file.md"), severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test diagnostic"), possibleSolutions: possibleSolutions)
            consumer.receive([problem])
            try? consumer.flush()
            return logger.output
        }
        let sourceLocation = SourceLocation(line: 1, column: 1, source: nil)
        let range = sourceLocation..<sourceLocation
        XCTAssertEqual(
            problemsLoggerOutput(possibleSolutions: [
                Solution(summary: "Create a sloth.", replacements: [
                    Replacement(
                        range: range,
                        replacement: """
                        var slothName = "slothy"
                        var slothDiet = .vegetarian
                        """
                    )
                ])
            ]),
            """
            \u{1B}[1;33mwarning: Test diagnostic\u{1B}[0;0m
            --> /path/to/file.md
            Create a sloth.
            suggestion:
            0 + var slothName = \"slothy\"
            1 + var slothDiet = .vegetarian
            
            """
        )
        
        XCTAssertEqual(
            problemsLoggerOutput(possibleSolutions: [
                Solution(summary: "Create a sloth.", replacements: [
                    Replacement(
                        range: range,
                        replacement: """
                        var slothName = "slothy"
                        var slothDiet = .vegetarian
                        """
                    ),
                    Replacement(
                        range: range,
                        replacement: """
                        var slothName = SlothGenerator().generateName()
                        var slothDiet = SlothGenerator().generateDiet()
                        """
                    )
                ])
            ]),
            """
            \u{1B}[1;33mwarning: Test diagnostic\u{1B}[0;0m
            --> /path/to/file.md
            Create a sloth.
            suggestion:
            0 + var slothName = "slothy"
            1 + var slothDiet = .vegetarian
            suggestion:
            0 + var slothName = SlothGenerator().generateName()
            1 + var slothDiet = SlothGenerator().generateDiet()
            
            """
        )
        
        XCTAssertEqual(
            problemsLoggerOutput(possibleSolutions: [
                Solution(summary: "Create a sloth.", replacements: [
                    Replacement(
                        range: range,
                        replacement: """
                        var slothName = "slothy"
                        var slothDiet = .vegetarian
                        """
                    ),
                ]),
                Solution(summary: "Create a bee.", replacements: [
                    Replacement(
                        range: range,
                        replacement: """
                        var beeName = "Bee"
                        var beeDiet = .vegetarian
                        """
                    )
                ])
            ]),
            """
            \u{1B}[1;33mwarning: Test diagnostic\u{1B}[0;0m
            --> /path/to/file.md
            Create a sloth.
            suggestion:
            0 + var slothName = "slothy"
            1 + var slothDiet = .vegetarian
            Create a bee.
            suggestion:
            0 + var beeName = "Bee"
            1 + var beeDiet = .vegetarian
            
            """
        )
    }
}
