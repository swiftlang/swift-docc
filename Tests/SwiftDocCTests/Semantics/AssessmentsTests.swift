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

class AssessmentsTests: XCTestCase {
    func testEmptyAndLonely() async throws {
        let source = "@Assessments"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(Assessments.directiveName, directive.name)
            let assessments = Assessments(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(assessments)
            XCTAssertEqual(1, diagnostics.count)
            XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasAtLeastOne<\(Assessments.self), \(MultipleChoice.self)>")
        }
    }
}
