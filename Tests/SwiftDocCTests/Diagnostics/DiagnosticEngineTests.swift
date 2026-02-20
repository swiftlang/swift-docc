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
        let exp = expectation(description: "Recieved diagnostic")
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
        let exp = expectation(description: "Recieved diagnostic")
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

        let defaultEngine = DiagnosticEngine()

        defaultEngine.emit(error)
        defaultEngine.emit(warning)
        defaultEngine.emit(information)
        XCTAssertEqual(DiagnosticConsoleWriter.formattedDescription(for: defaultEngine.problems, options: .formatConsoleOutputForTools), """
            error: Test error
            warning: Test warning
            """)

        let engine = DiagnosticEngine(filterLevel: .information)
        engine.emit(error)
        engine.emit(warning)
        engine.emit(information)
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
}
