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

class ChoiceTests: XCTestCase {
    func testInvalidEmpty() throws {
        let source = "@Choice"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(choice)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertEqual(2, problems.count)
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.HasExactlyOne<\(Choice.self), \(Justification.self)>.Missing"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.HasArgument.isCorrect"))
            XCTAssertTrue(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
        }
    }
    
    func testInvalidMissingContent() throws {
        let source = """
@Choice(isCorrect: true) {
   @Justification {
      Trust me, it's right.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(choice)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertEqual(1, problems.count)
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(Choice.self).Empty"))
        }
    }
    
    func testInvalidMissingJustification() throws {
        let source = """
@Choice(isCorrect: true) {
   This is some content.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(choice)
            XCTAssertEqual(1, problems.count)
            problems.first.map { problem in
                XCTAssertEqual("org.swift.docc.HasExactlyOne<Choice, Justification>.Missing", problem.diagnostic.identifier)
            }
        }
    }
    
    func testInvalidMissingIsCorrect() throws {
        let source = """
@Choice {
   This is some content.
   @Justification {
      Trust me, it's right.
   }
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(choice)
            XCTAssertEqual(1, problems.count)
            problems.first.map { problem in
                XCTAssertEqual("org.swift.docc.HasArgument.isCorrect", problem.diagnostic.identifier)
            }
        }
    }
    
    func testInvalidIsCorrect() throws {
        let source = """
@Choice(isCorrect: blah) {
   This is some content.
   @Justification {
      Trust me, it's right.
   }
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(choice)
            XCTAssertEqual(1, problems.count)
            problems.first.map { problem in
                XCTAssertEqual("org.swift.docc.HasArgument.isCorrect.ConversionFailed", problem.diagnostic.identifier)
                XCTAssertEqual(2, problem.possibleSolutions.count)
                XCTAssertEqual("Use allowed value 'true'", problem.possibleSolutions[0].summary)
                XCTAssertEqual("Use allowed value 'false'", problem.possibleSolutions[1].summary)
            }
        }
    }
    
    func testValidParagraph() throws {
        let source = """
@Choice(isCorrect: true) {
   This is some content.
   @Justification {
      Trust me, it's right.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(choice)
            XCTAssertTrue(problems.isEmpty)
            choice.map { choice in
                let expectedDump = """
Choice @1:1-6:2 isCorrect: true
├─ MarkupContainer (1 element)
└─ Justification @3:4-5:5
   └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, choice.dump())
            }
        }
    }
    
    func testValidCode() throws {
        let source = """
@Choice(isCorrect: true) {
   ```swift
   func foo() {}
   ```

   @Justification {
      Trust me, it's right.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(choice)
            XCTAssertTrue(problems.isEmpty)
            choice.map { choice in
                let expectedDump = """
Choice @1:1-9:2 isCorrect: true
├─ MarkupContainer (1 element)
└─ Justification @6:4-8:5
   └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, choice.dump())
            }
        }
    }
    
    func testValidImage() throws {
        let source = """
@Choice(isCorrect: true) {
   @Image(source: blah.png, alt: blah)

   @Justification {
      Trust me, it's right.
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(choice)
            XCTAssertTrue(problems.isEmpty)
            choice.map { choice in
                let expectedDump = """
Choice @1:1-7:2 isCorrect: true
├─ MarkupContainer (empty)
├─ ImageMedia @2:4-2:39 source: 'ResourceReference(bundleIdentifier: "org.swift.docc.example", path: "blah.png")' altText: 'blah'
└─ Justification @4:4-6:5
   └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, choice.dump())
            }
        }
    }
}
