/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

struct NullChecker: Checker {
    let diagnostics = [Diagnostic]()
}

struct DiagnoseEveryParagraph: Checker {
    var diagnostics = [Diagnostic]()
    mutating func visitParagraph(_ paragraph: Paragraph) {
        diagnostics.append(Diagnostic(source: nil, severity: .error, range: nil, identifier: "some-identifier", summary: "Some summary of this issue"))
    }
}

class CheckerTests: XCTestCase {
    func testNullChecker() {
        var nullChecker = NullChecker()
        nullChecker.visit(Document())
        XCTAssertTrue(nullChecker.diagnostics.isEmpty)
    }
    
    func testDiagnoseEverything() {
        var checker = DiagnoseEveryParagraph()
        let node = Paragraph(Text("Hello world!"))
        checker.visit(node)
        
        XCTAssertEqual(1, checker.diagnostics.count)
    }
}

class CompositeCheckerTests: XCTestCase {
    func testNoCheckers() {
        var checker = CompositeChecker([AnyChecker]())
        checker.visit(Paragraph())
        XCTAssertTrue(checker.diagnostics.isEmpty)
    }
    
    func testOneChecker() {
        var checker = CompositeChecker([DiagnoseEveryParagraph()])
        checker.visit(Paragraph())
        XCTAssertEqual(1, checker.diagnostics.count)
    }
    
    func testMultipleCheckers() {
        var checker = CompositeChecker([
            DiagnoseEveryParagraph(),
            DiagnoseEveryParagraph(),
        ])
        checker.visit(Paragraph())
        XCTAssertEqual(2, checker.diagnostics.count)
    }
}
