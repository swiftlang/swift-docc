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
import DocCTestUtilities

class ChoiceTests: XCTestCase {
    func testInvalidEmpty() async throws {
        let source = "@Choice"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(choice)
            XCTAssertEqual(2, diagnostics.count)
            XCTAssertEqual(diagnostics.map(\.identifier).sorted(), [
                "org.swift.docc.HasArgument.isCorrect",
                "org.swift.docc.HasExactlyOne<\(Choice.self), \(Justification.self)>.Missing",
            ])
            XCTAssertTrue(diagnostics.allSatisfy { $0.severity == .warning })
        }
    }
    
    func testInvalidMissingContent() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(choice)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.\(Choice.self).Empty")
        }
    }
    
    func testInvalidMissingJustification() async throws {
        let source = """
@Choice(isCorrect: true) {
   This is some content.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(choice)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasExactlyOne<Choice, Justification>.Missing")
        }
    }
    
    func testInvalidMissingIsCorrect() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(choice)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.isCorrect")
        }
    }
    
    func testInvalidIsCorrect() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(choice)
            XCTAssertEqual(1, diagnostics.count)
            let diagnostic = try XCTUnwrap(diagnostics.first)
            
            XCTAssertEqual("org.swift.docc.HasArgument.isCorrect.ConversionFailed", diagnostic.identifier)
            XCTAssertEqual(2, diagnostic.solutions.count)
            XCTAssertEqual("Use allowed value 'true'", diagnostic.solutions[0].summary)
            XCTAssertEqual("Use allowed value 'false'", diagnostic.solutions[1].summary)
        }
    }
    
    func testValidParagraph() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(choice)
            XCTAssertTrue(diagnostics.isEmpty)
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
    
    func testValidCode() async throws {
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
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(choice)
            XCTAssertTrue(diagnostics.isEmpty)
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
    
    func testValidImage() async throws {
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
        
        let (_, context) = try await loadBundle(catalog: Folder(name: "unit-test.docc", content: [
            InfoPlist(identifier: "org.swift.docc.example"),
            DataFile(name: "blah.png", data: Data()),
        ]))
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Choice.directiveName, directive.name)
            let choice = Choice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(choice)
            XCTAssertTrue(diagnostics.isEmpty)
            choice.map { choice in
                let expectedDump = """
Choice @1:1-7:2 isCorrect: true
├─ MarkupContainer (empty)
├─ ImageMedia @2:4-2:39 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "blah.png")' altText: 'blah'
└─ Justification @4:4-6:5
   └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, choice.dump())
            }
        }
    }
}
