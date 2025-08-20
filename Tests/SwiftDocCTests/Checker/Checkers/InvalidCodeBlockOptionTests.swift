/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class InvalidCodeBlockOptionTests: XCTestCase {

    func testOption() {
        let markupSource = """
```nocopy
let a = 1
```
"""
        let document = Document(parsing: markupSource, options: [])
        var checker = InvalidCodeBlockOption(sourceFile: nil)
        checker.visit(document)
        XCTAssertTrue(checker.problems.isEmpty)
    }

    func testMultipleOptionTypos() {
        let markupSource = """
```nocoy
let b = 2
```

```nocoy
let c = 3
```
"""
        let document = Document(parsing: markupSource, options: [])
        var checker = InvalidCodeBlockOption(sourceFile: URL(fileURLWithPath: #file))
        checker.visit(document)
        XCTAssertEqual(2, checker.problems.count)

        for problem in checker.problems {
            XCTAssertEqual("org.swift.docc.InvalidCodeBlockOption", problem.diagnostic.identifier)
            XCTAssertEqual(problem.diagnostic.summary, "Unknown option 'nocoy' in code block.")
            XCTAssertEqual(problem.possibleSolutions.map(\.summary), ["Replace 'nocoy' with 'nocopy'."])
        }
    }

    func testOptionDifferentTypos() throws {
        let markupSource = """
```swift, nocpy
let d = 4
```         

```unknown, nocpoy
let e = 5
```

```nocopy
let f = 6
```   

```ncopy
let g = 7
```  
"""
        let document = Document(parsing: markupSource, options: [])
        var checker = InvalidCodeBlockOption(sourceFile: URL(fileURLWithPath: #file))
        checker.visit(document)

        XCTAssertEqual(3, checker.problems.count)

        let summaries = checker.problems.map { $0.diagnostic.summary }
        XCTAssertEqual(summaries, [
            "Unknown option 'nocpy' in code block.",
            "Unknown option 'nocpoy' in code block.",
            "Unknown option 'ncopy' in code block.",
        ])

        for problem in checker.problems {
            XCTAssertEqual(
                "org.swift.docc.InvalidCodeBlockOption",
                problem.diagnostic.identifier
            )

            XCTAssertEqual(problem.possibleSolutions.count, 1)
            let solution = try XCTUnwrap(problem.possibleSolutions.first)
            XCTAssert(solution.summary.hasSuffix("with 'nocopy'."))

        }
    }
}

