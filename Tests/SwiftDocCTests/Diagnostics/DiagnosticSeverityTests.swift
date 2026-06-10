/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DiagnosticSeverityTests: XCTestCase {
    func testDiagnosticSeverityFromString() {
        XCTAssertEqual(DiagnosticSeverity("error"), .error)
        XCTAssertEqual(DiagnosticSeverity("warning"), .warning)
        XCTAssertEqual(DiagnosticSeverity("information"), .information)
        XCTAssertEqual(DiagnosticSeverity("info"), .information)
        XCTAssertEqual(DiagnosticSeverity("note"), .information)
        XCTAssertEqual(DiagnosticSeverity("hint"), .information)
        XCTAssertEqual(DiagnosticSeverity("notice"), .information)
        XCTAssertNil(DiagnosticSeverity(""))
        XCTAssertNil(DiagnosticSeverity(nil))
    }
    
    func testDiagnosticOrder() {
        // Verify that: error < warning < information
        XCTAssertLessThan(DiagnosticSeverity.error, .warning)
        XCTAssertLessThan(DiagnosticSeverity.warning, .information)
    }
}
