/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import benchmark

final class TextUtilityTests: XCTestCase {
    
    func testSuperScript() {
        XCTAssertEqual(DiffResultsTable.superscript(1234), "¹²³⁴")
        XCTAssertEqual(DiffResultsTable.superscript(99), "⁹⁹")
        XCTAssertEqual(DiffResultsTable.superscript(400), "⁴⁰⁰")
        XCTAssertEqual(DiffResultsTable.superscript(1), "¹")
        
        XCTAssertEqual(DiffResultsTable.superscript(0), "")
        XCTAssertEqual(DiffResultsTable.superscript(-1), "")
    }
}
