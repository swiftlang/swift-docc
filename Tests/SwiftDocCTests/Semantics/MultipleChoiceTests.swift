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

class MultipleChoiceTests: XCTestCase {
    func testInvalidEmpty() async throws {
        let source = "@MultipleChoice"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(multipleChoice)
            XCTAssertEqual(3, diagnostics.count)
            let diagnosticIdentifiers = Set(diagnostics.map { $0.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).missingPhrasing"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).CorrectNumberOfChoices"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).CorrectChoiceProvided"))
        }
    }
    
    func testInvalidTooFewChoices() async throws {
        let source = """
@MultipleChoice {
  What is your favorite color?

  Here's the first question.

  @Choice(isCorrect: true) {
     A.
     @Justification {
        Because.
     }
   }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(multipleChoice)
            XCTAssertEqual(1, diagnostics.count)
            let diagnostic = try XCTUnwrap(diagnostics.first { $0.identifier == "org.swift.docc.\(MultipleChoice.self).CorrectNumberOfChoices" })
            XCTAssertEqual(diagnostic.severity, .warning)
        }
    }
    
    func testInvalidCodeAndImage() async throws {
        let source = """
@MultipleChoice {
  Question 1

  Here's the first question.

  ```swift
  func foo() {}
  ```

  @Image(source: blah.png, alt: blah)

  @Choice(isCorrect: true) {
     A.
     @Justification {
        Because.
     }
   }
  @Choice(isCorrect: false) {
     B.
     @Justification {
        Because.
     }
  }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (_, context) = try await loadBundle(catalog: Folder(name: "Something.docc", content: [
            DataFile(name: "blah.png", data: Data()),
            InfoPlist(identifier: "org.swift.docc.example")
        ]))
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(multipleChoice)
            XCTAssertFalse(diagnostics.isEmpty)
            diagnostics.first.map {
                XCTAssertEqual("org.swift.docc.MultipleChoice.CodeOrImage", $0.identifier)
            }
            
            multipleChoice.map { multipleChoice in
                let expectedDump = """
MultipleChoice @1:1-24:2 title: 'SwiftDocC.MarkupContainer'
├─ MarkupContainer (2 elements)
├─ ImageMedia @10:3-10:38 source: 'ResourceReference(bundleID: org.swift.docc.example, path: "blah.png")' altText: 'blah'
├─ Choice @12:3-17:5 isCorrect: true
│  ├─ MarkupContainer (1 element)
│  └─ Justification @14:6-16:7
│     └─ MarkupContainer (1 element)
└─ Choice @18:3-23:4 isCorrect: false
   ├─ MarkupContainer (1 element)
   └─ Justification @20:6-22:7
      └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, multipleChoice.dump())
            }
        }

    }
    
    func testValidNoCodeOrMedia() async throws {
        let source = """
@MultipleChoice {
  Question 1

  Here's the first question.

  @Choice(isCorrect: true) {
     A.
     @Justification {
        Because.
     }
   }
  @Choice(isCorrect: false) {
     B.
     @Justification {
        Because.
     }
  }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(multipleChoice)
            XCTAssertTrue(diagnostics.isEmpty)
            
            multipleChoice.map { multipleChoice in
                let expectedDump = """
MultipleChoice @1:1-18:2 title: 'SwiftDocC.MarkupContainer'
├─ MarkupContainer (1 element)
├─ Choice @6:3-11:5 isCorrect: true
│  ├─ MarkupContainer (1 element)
│  └─ Justification @8:6-10:7
│     └─ MarkupContainer (1 element)
└─ Choice @12:3-17:4 isCorrect: false
   ├─ MarkupContainer (1 element)
   └─ Justification @14:6-16:7
      └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, multipleChoice.dump())
            }
        }
    }
    
    func testValidCode() async throws {
        let source = """
@MultipleChoice {
  Question 1

  Here's the first question.

  ```swift
  func foo() {}
  ```

  @Choice(isCorrect: true) {
     A.
     @Justification {
        Because.
     }
   }
  @Choice(isCorrect: false) {
     B.
     @Justification {
        Because.
     }
  }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(multipleChoice)
            XCTAssertTrue(diagnostics.isEmpty)
            
            multipleChoice.map { multipleChoice in
                XCTAssertNil(multipleChoice.image)
            }
            
            multipleChoice.map { multipleChoice in
                let expectedDump = """
MultipleChoice @1:1-22:2 title: 'SwiftDocC.MarkupContainer'
├─ MarkupContainer (2 elements)
├─ Choice @10:3-15:5 isCorrect: true
│  ├─ MarkupContainer (1 element)
│  └─ Justification @12:6-14:7
│     └─ MarkupContainer (1 element)
└─ Choice @16:3-21:4 isCorrect: false
   ├─ MarkupContainer (1 element)
   └─ Justification @18:6-20:7
      └─ MarkupContainer (1 element)
"""
                XCTAssertEqual(expectedDump, multipleChoice.dump())
            }
        }

    }
    
    func testMultipleCorrectAnswers() async throws {
        let source = """
@MultipleChoice {
  Question 1

  Here's the first question.

  ```swift
  func foo() {}
  ```

  @Choice(isCorrect: true) {
     A.
     @Justification {
        Because.
     }
   }
  @Choice(isCorrect: true) {
     B.
     @Justification {
        Because.
     }
  }
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = try XCTUnwrap(document.child(at: 0) as? BlockDirective)
        let context = try await makeEmptyContext()
        
        var diagnostics = [Diagnostic]()
        XCTAssertEqual(MultipleChoice.directiveName, directive.name)
        
        let multipleChoice = MultipleChoice(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(multipleChoice)
        
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.map(\.identifier), ["org.swift.docc.MultipleChoice.MultipleCorrectChoicesProvided"])
        
        let diagnostic = try XCTUnwrap(diagnostics.first)
        let lines = source.splitByNewlines
        
        for note in diagnostic.notes {
            let sourceLine = lines[note.range.lowerBound.line-1]
            let sourceStartIndex = sourceLine.index(sourceLine.startIndex, offsetBy: note.range.lowerBound.column-1)
            let sourceEndIndex = sourceLine.index(sourceLine.startIndex, offsetBy: note.range.upperBound.column-1)
            let sourceText = sourceLine[sourceStartIndex...sourceEndIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            XCTAssertEqual("isCorrect: true", sourceText)
        }
    }
}
