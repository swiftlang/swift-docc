/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
import Markdown

class AssessmentsTests: XCTestCase {
    func testEmptyAndLonely() throws {
        let source = "@Assessments"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, _) = try testBundleAndContext()
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Assessments.directiveName, directive.name)
            let assessments = Assessments(from: directive, source: nil, for: bundle, problems: &problems)
            XCTAssertNotNil(assessments)
            XCTAssertEqual(1, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            problems.first.map { problem in
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.HasAtLeastOne<\(Assessments.self), \(MultipleChoice.self)>"))
            }
        }
    }
}
