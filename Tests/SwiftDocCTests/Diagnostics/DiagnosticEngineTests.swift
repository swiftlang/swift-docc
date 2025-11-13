/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DiagnosticEngineTests: XCTestCase {

    class TestConsumer: DiagnosticConsumer {
        let expectation: XCTestExpectation
        init(_ exp: XCTestExpectation) {
            expectation = exp
        }
        func receive(_ problems: [Problem]) {
            expectation.fulfill()
        }
        func flush() { }
    }

    func testEmitDiagnostic() {
        let diagnostic = Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.test", summary: "Test diagnostic")
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        let engine = DiagnosticEngine()
        let exp = expectation(description: "Received diagnostic")
        let consumer = TestConsumer(exp)

        XCTAssertEqual(engine.problems.count, 0)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 0)

        engine.add(consumer)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 1)

        engine.emit(problem)
        waitForExpectations(timeout: 0.5)
        XCTAssertEqual(engine.problems.count, 1)

        engine.remove(consumer)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 0)

        engine.clearDiagnostics()
        XCTAssertEqual(engine.problems.count, 0)
    }

    func testMultipleConsumers() {
        let diagnostic = Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.test", summary: "Test diagnostic")
        let problem = Problem(diagnostic: diagnostic, possibleSolutions: [])
        let engine = DiagnosticEngine()
        let exp = expectation(description: "Received diagnostic")
        exp.expectedFulfillmentCount = 2
        let consumerA = TestConsumer(exp)
        let consumerB = TestConsumer(exp)

        XCTAssertEqual(engine.problems.count, 0)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 0)

        engine.add(consumerA)
        engine.add(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 2)

        engine.emit(problem)
        waitForExpectations(timeout: 0.5)

        XCTAssertEqual(engine.problems.count, 1)
    }

    func testAddConsumers() {
        let exp = XCTestExpectation()
        let consumerA = TestConsumer(exp)
        let consumerB = TestConsumer(exp)
        let engine = DiagnosticEngine()

        engine.add(consumerA)
        engine.add(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 2)

        engine.add(consumerA)
        engine.add(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 2, "A diagnostic engine shouldn't be able to add duplicate references to consumers")
    }

    func testRemoveConsumers() {
        let exp = XCTestExpectation()
        let consumerA = TestConsumer(exp)
        let consumerB = TestConsumer(exp)
        let engine = DiagnosticEngine()

        engine.add(consumerA)
        engine.add(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 2)

        engine.remove(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 1)

        engine.remove(consumerB)
        XCTAssertEqual(engine.consumers.sync { $0.count }, 1, "Removing a consumer more than once shouldn't have a side effect on a diagnostic engine")
    }

    func testProblemFiltering() {
        let error = Problem(diagnostic: Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.tests", summary: "Test error"), possibleSolutions: [])
        let warning = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test warning"), possibleSolutions: [])
        let information = Problem(diagnostic: Diagnostic(source: nil, severity: .information, range: nil, identifier: "org.swift.docc.tests", summary: "Test information"), possibleSolutions: [])
        let hint = Problem(diagnostic: Diagnostic(source: nil, severity: .hint, range: nil, identifier: "org.swift.docc.tests", summary: "Test hint"), possibleSolutions: [])

        let defaultEngine = DiagnosticEngine()

        defaultEngine.emit(error)
        defaultEngine.emit(warning)
        defaultEngine.emit(information)
        defaultEngine.emit(hint)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: defaultEngine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            warning: Test warning
            """)

        let engine = DiagnosticEngine(filterLevel: .information)
        engine.emit(error)
        engine.emit(warning)
        engine.emit(information)
        engine.emit(hint)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            warning: Test warning
            note: Test information
            """)
    }
    
    func testTreatWarningsAsErrors() {
        let error = Problem(diagnostic: Diagnostic(source: nil, severity: .error, range: nil, identifier: "org.swift.docc.tests", summary: "Test error"), possibleSolutions: [])
        let warning = Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: "org.swift.docc.tests", summary: "Test warning"), possibleSolutions: [])
        let information = Problem(diagnostic: Diagnostic(source: nil, severity: .information, range: nil, identifier: "org.swift.docc.tests", summary: "Test information"), possibleSolutions: [])

        let defaultEngine = DiagnosticEngine()
        defaultEngine.emit(error)
        defaultEngine.emit(warning)
        defaultEngine.emit(information)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: defaultEngine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            warning: Test warning
            """)

        let engine = DiagnosticEngine(filterLevel: .information, treatWarningsAsErrors: true)
        engine.emit(error)
        engine.emit(warning)
        engine.emit(information)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            error: Test warning
            note: Test information
            """)
        
        let errorFilterLevelEngine = DiagnosticEngine(filterLevel: .error, treatWarningsAsErrors: true)
        errorFilterLevelEngine.emit(error)
        errorFilterLevelEngine.emit(warning)
        errorFilterLevelEngine.emit(information)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: errorFilterLevelEngine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            error: Test warning
            """)
    }
    
    func testRaiseSeverityOfSpecificDiagnostics() {
        let warnings = ["One", "Two", "Three"].map { id in
            Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: id, summary: "Test diagnostic \(id.lowercased())"), possibleSolutions: [])
        }
        
        let defaultEngine = DiagnosticEngine()
        defaultEngine.emit(warnings)
        
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: defaultEngine.problems, options: .formatConsoleOutputForTools), """
        warning: Test diagnostic one
        warning: Test diagnostic two
        warning: Test diagnostic three
        """)
        
        let engineWithSpecificDiagnosticsRaised = DiagnosticEngine(diagnosticIDsWithErrorSeverity: ["Two", "Unknown"])
        engineWithSpecificDiagnosticsRaised.emit(warnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithSpecificDiagnosticsRaised.problems, options: .formatConsoleOutputForTools), """
        warning: Test diagnostic one
        error: Test diagnostic two
        warning: Test diagnostic three
        """)
        
        let engineWithFilterAndSpecificDiagnosticsRaised = DiagnosticEngine(filterLevel: .error, diagnosticIDsWithErrorSeverity: ["Two", "Unknown"])
        engineWithFilterAndSpecificDiagnosticsRaised.emit(warnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithFilterAndSpecificDiagnosticsRaised.problems, options: .formatConsoleOutputForTools), """
        error: Test diagnostic two
        """)
    }
    
    func testLowerSeverityOfSpecificDiagnostics() {
        let warnings = ["One", "Two", "Three"].map { id in
            Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: id, summary: "Test diagnostic \(id.lowercased())"), possibleSolutions: [])
        }
        
        let engineWithRaisedSeverity = DiagnosticEngine(treatWarningsAsErrors: true)
        engineWithRaisedSeverity.emit(warnings)
        
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithRaisedSeverity.problems, options: .formatConsoleOutputForTools), """
        error: Test diagnostic one
        error: Test diagnostic two
        error: Test diagnostic three
        """)
        
        let engineWithSpecificDiagnosticsLowered = DiagnosticEngine(treatWarningsAsErrors: true, diagnosticIDsWithWarningSeverity: ["Two", "Unknown"])
        engineWithSpecificDiagnosticsLowered.emit(warnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithSpecificDiagnosticsLowered.problems, options: .formatConsoleOutputForTools), """
        error: Test diagnostic one
        warning: Test diagnostic two
        error: Test diagnostic three
        """)
        
        let engineWithFilterAndSpecificDiagnosticsLowered = DiagnosticEngine(filterLevel: .error, treatWarningsAsErrors: true, diagnosticIDsWithWarningSeverity: ["Two", "Unknown"])
        engineWithFilterAndSpecificDiagnosticsLowered.emit(warnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithFilterAndSpecificDiagnosticsLowered.problems, options: .formatConsoleOutputForTools), """
        error: Test diagnostic one
        error: Test diagnostic three
        """)
    }
    
    func testRaiseSeverityOfDiagnosticGroups() {
        let letterWarnings = ["A", "B", "C"].map { id in
            Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: id, groupIdentifier: "Letter", summary: "Test diagnostic \(id)"), possibleSolutions: [])
        }
        let numberWarnings = ["1", "2", "3"].map { id in
            Problem(diagnostic: Diagnostic(source: nil, severity: .warning, range: nil, identifier: id, groupIdentifier: "Number", summary: "Test diagnostic \(id)"), possibleSolutions: [])
        }
        
        let engineWithRaisedLetterSeverity = DiagnosticEngine(diagnosticIDsWithErrorSeverity: ["Letter"])
        engineWithRaisedLetterSeverity.emit(letterWarnings)
        engineWithRaisedLetterSeverity.emit(numberWarnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithRaisedLetterSeverity.problems, options: .formatConsoleOutputForTools), """
        error: Test diagnostic A
        error: Test diagnostic B
        error: Test diagnostic C
        warning: Test diagnostic 1
        warning: Test diagnostic 2
        warning: Test diagnostic 3
        """)
        
        let engineWithRaisedNumberSeverity = DiagnosticEngine(diagnosticIDsWithErrorSeverity: ["Number"])
        engineWithRaisedNumberSeverity.emit(letterWarnings)
        engineWithRaisedNumberSeverity.emit(numberWarnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithRaisedNumberSeverity.problems, options: .formatConsoleOutputForTools), """
        warning: Test diagnostic A
        warning: Test diagnostic B
        warning: Test diagnostic C
        error: Test diagnostic 1
        error: Test diagnostic 2
        error: Test diagnostic 3
        """)
        
        let engineWithRaisedNumberSeverityAndOneLetter = DiagnosticEngine(diagnosticIDsWithErrorSeverity: ["Number", "B"])
        engineWithRaisedNumberSeverityAndOneLetter.emit(letterWarnings)
        engineWithRaisedNumberSeverityAndOneLetter.emit(numberWarnings)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: engineWithRaisedNumberSeverityAndOneLetter.problems, options: .formatConsoleOutputForTools), """
        warning: Test diagnostic A
        error: Test diagnostic B
        warning: Test diagnostic C
        error: Test diagnostic 1
        error: Test diagnostic 2
        error: Test diagnostic 3
        """)
    }
}
