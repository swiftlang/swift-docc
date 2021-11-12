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

class StepTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@Step
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let step = Step(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertEqual([
            "org.swift.docc.HasContent",
        ], problems.map { $0.diagnostic.identifier })
        XCTAssertNotNil(step)
        step.map {
            XCTAssertTrue($0.content.isEmpty)
            XCTAssertTrue($0.caption.isEmpty)
        }
    }
    
    func testValid() throws {
        let source = """
@Step {
   This is the step's content.

   This is the step's caption.

   > Important: This is important.
   
   @Image(source: test.png, alt: "Test image")
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let step = Step(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertTrue(problems.isEmpty)
        XCTAssertNotNil(step)
        
        let expectedDump = """
Step @1:1-9:2
├─ MarkupContainer (1 element)
└─ MarkupContainer (2 elements)
"""
        
        let expectedContentDump = """
├─ Paragraph @2:4-2:31
│  └─ Text @2:4-2:31 "This is the step’s content."
"""
        
        let expectedCaptionDump = """
├─ Paragraph @4:4-4:31
│  └─ Text @4:4-4:31 "This is the step’s caption."
"""
        
        step.map { step in
            XCTAssertEqual(expectedDump, step.dump())
            
            XCTAssertEqual(1, step.content.count)
            step.content.first.map { content in
                XCTAssertEqual(expectedContentDump, content.debugDescription(options: .printSourceLocations))
            }
            
            XCTAssertEqual(2, step.caption.count)
            step.caption.first.map { caption in
                XCTAssertEqual(expectedCaptionDump, caption.debugDescription(options: .printSourceLocations))
            }
        }
    }
    
    func testExtraneousContent() throws {
        let source = """
@Step {
   This is the step's content.
   
   @Image(source: test.png, alt: "Test image")

   - A
   - B

   This is the step's caption.

   > Important: This is not extraneous.

   This is an extranous paragraph.

   > Note: More than one aside is technically allowed per design.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let step = Step(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertEqual(2, problems.count)
        
        XCTAssertEqual([
            "org.swift.docc.Step.ExtraneousContent",
            "org.swift.docc.Step.ExtraneousContent",
        ], problems.map { $0.diagnostic.identifier })
        
        XCTAssertNotNil(step)
        
                let expectedDump = """
Step @1:1-16:2
├─ MarkupContainer (1 element)
└─ MarkupContainer (3 elements)
"""
        
        let expectedContentDump = """
├─ Paragraph @2:4-2:31
│  └─ Text @2:4-2:31 "This is the step’s content."
"""
        
        let expectedCaptionDump = """
├─ Paragraph @9:4-9:31
│  └─ Text @9:4-9:31 "This is the step’s caption."
├─ BlockQuote @11:4-11:40
│  └─ Paragraph @11:6-11:40
│     └─ Text @11:6-11:40 "Important: This is not extraneous."
└─ BlockQuote @15:4-15:66
└─ Paragraph @15:6-15:66
   └─ Text @15:6-15:66 "Note: More than one aside is technically allowed per design."
"""
        
        step.map { step in
            XCTAssertEqual(expectedDump, step.dump())
            
            XCTAssertEqual(1, step.content.count)
            XCTAssertEqual(expectedContentDump, step.content.elements.map { $0.debugDescription(options: .printSourceLocations) }.joined(separator: "\n"))
            
            XCTAssertEqual(3, step.caption.count)
            XCTAssertEqual(expectedCaptionDump, step.caption.elements.map { $0.debugDescription(options: .printSourceLocations) }.joined(separator: "\n"))
        }
    }
}
