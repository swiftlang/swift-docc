/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class AbstractContainsFormattedTextOnlyTests: XCTestCase {
    var checker = AbstractContainsFormattedTextOnly(sourceFile: nil)
    
    private func verifyDiagnostic(diagnostic: Diagnostic, expectedIdentifier: String, expectedRange: SourceRange) {
        XCTAssertEqual(expectedIdentifier, diagnostic.identifier)
        XCTAssertEqual(expectedRange, diagnostic.range)
    }
    
    func testFormattedText() {
        let source = """
# Title

This __is__ an *abstract*.

This paragraph isn't [analyzed](http://example.com/image.jpg).
"""
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        XCTAssertTrue(checker.problems.isEmpty)
    }
    
    func testTopLevelImage() {
        let source = """
# Title

![](http://example.com/image.jpg) Abstract.
"""
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 1 else {
            XCTFail("Expected 1 problems")
            return
        }

        
        let problem = checker.problems[0]
        XCTAssertTrue(problem.possibleSolutions.isEmpty)
        
        let image = document.child(at: 1)!.child(at: 0)! as! Image
        verifyDiagnostic(diagnostic: problem.diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsImage", expectedRange: image.range!)
    }
    
    func testTopLevelLink() {
        let source = """
# Title

More info [here](http://example.com/image.jpg).
"""
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 1 else {
            XCTFail("Expected 1 problem")
            return
        }
        
        let problem = checker.problems[0]
        XCTAssertTrue(problem.possibleSolutions.isEmpty)
        
        let link = document.child(at: 1)!.child(at: 1)! as! Link
        verifyDiagnostic(diagnostic: problem.diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsLink", expectedRange: link.range!)
    }
    
    func testMultipleTopLevelInvalidElements() {
        let source = """
# Title

![](http://example.com/image1.jpg) Hello [there](http://example.com/) World ![](http://example.com/image3.jpg)
"""
        
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 3 else {
            XCTFail("Expected 3 problems")
            return
        }

        let abstract = document.child(at: 1)!
        
        let image1 = abstract.child(at: 0)! as! Image
        let image2 = abstract.child(at: 2)! as! Link
        let image3 = abstract.child(at: 4)! as! Image
        
        verifyDiagnostic(diagnostic: checker.problems[0].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsImage", expectedRange: image1.range!)
        verifyDiagnostic(diagnostic: checker.problems[1].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsLink", expectedRange: image2.range!)
        verifyDiagnostic(diagnostic: checker.problems[2].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsImage", expectedRange: image3.range!)
    }
    
    func testLinkWithinEmphasis() {
        let source = """
# Title

Hello *[world](http://example.com)*.
"""
        
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 1 else {
            XCTFail("Expected 1 problem")
            return
        }

        let link = document.child(at: 1)!.child(at: 1)!.child(at: 0)! as! Link
        verifyDiagnostic(diagnostic: checker.problems[0].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsLink", expectedRange: link.range!)
    }
    
    func testImagesWithinBold() {
        let source = """
# Title

Hello **![image](http://example.com/image1.jpg)** World
"""
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 1 else {
            XCTFail("Expected 1 problem")
            return
        }

        let image = document.child(at: 1)!.child(at: 1)!.child(at: 0)! as! Image
        verifyDiagnostic(diagnostic: checker.problems[0].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsImage", expectedRange: image.range!)
    }
    
    func testImageInALink() {
        let source = """
# Title

Hello **[![image](http://example.com/image1.jpg)](http://example.com)** World.
"""
        let document = Document(parsing: source, options: [])
        checker.visit(document)
        guard checker.problems.count == 2 else {
            XCTFail("Expected 2 problems")
            return
        }
        let link = document.child(at: 1)!.child(at: 1)!.child(at: 0)! as! Link
        let image = document.child(at: 1)!.child(at: 1)!.child(at: 0)!.child(at: 0)! as! Image
        
        verifyDiagnostic(diagnostic: checker.problems[0].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsLink", expectedRange: link.range!)
        verifyDiagnostic(diagnostic: checker.problems[1].diagnostic, expectedIdentifier: "org.swift.docc.SummaryContainsImage", expectedRange: image.range!)
    }
}
