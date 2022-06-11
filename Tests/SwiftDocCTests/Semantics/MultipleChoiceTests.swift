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

class MultipleChoiceTests: XCTestCase {
    func testInvalidEmpty() throws {
        let source = "@MultipleChoice"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(multipleChoice)
            XCTAssertEqual(3, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).missingPhrasing"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).CorrectNumberOfChoices"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MultipleChoice.self).CorrectChoiceProvided"))
        }
    }
    
    func testInvalidTooFewChoices() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        try directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(multipleChoice)
            XCTAssertEqual(1, problems.count)
            let problem = try XCTUnwrap(
                problems.first {
                    $0.diagnostic.identifier == "org.swift.docc.\(MultipleChoice.self).CorrectNumberOfChoices"
                }
            )
            XCTAssertEqual(problem.diagnostic.severity, .warning)
        }
    }
    
    func testInvalidCodeAndImage() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(multipleChoice)
            XCTAssertFalse(problems.isEmpty)
            problems.first.map {
                XCTAssertEqual("org.swift.docc.MultipleChoice.CodeOrImage", $0.diagnostic.identifier)
            }
            
            multipleChoice.map { multipleChoice in
                let expectedDump = """
MultipleChoice @1:1-24:2 title: 'SwiftDocC.MarkupContainer'
├─ MarkupContainer (2 elements)
├─ ImageMedia @10:3-10:38 source: 'ResourceReference(bundleIdentifier: "org.swift.docc.example", path: "blah.png")' altText: 'blah'
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
    
    func testValidNoCodeOrMedia() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(multipleChoice)
            XCTAssertTrue(problems.isEmpty)
            
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
    
    func testValidCode() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MultipleChoice.directiveName, directive.name)
            let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(multipleChoice)
            XCTAssertTrue(problems.isEmpty)
            
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
    
    func testMultipleCorrectAnswers() throws {
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
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems = [Problem]()
        XCTAssertEqual(MultipleChoice.directiveName, directive.name)
        
        let multipleChoice = MultipleChoice(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertNotNil(multipleChoice)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual(["org.swift.docc.MultipleChoice.MultipleCorrectChoicesProvided"], problems.map {$0.diagnostic.identifier})
        
        guard problems.count == 1 else { return }
        
        let problem = problems[0]
        let lines = source.splitByNewlines
        
        for note in problem.diagnostic.notes {
            let sourceLine = lines[note.range.lowerBound.line-1]
            let sourceStartIndex = sourceLine.index(sourceLine.startIndex, offsetBy: note.range.lowerBound.column-1)
            let sourceEndIndex = sourceLine.index(sourceLine.startIndex, offsetBy: note.range.upperBound.column-1)
            let sourceText = sourceLine[sourceStartIndex...sourceEndIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            
            XCTAssertEqual("isCorrect: true", sourceText)
        }
    }
}
