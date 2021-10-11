/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SwiftDocCUtilities
@testable import SwiftDocC
import Markdown

class ProblemTests: XCTestCase {

    func testProblemDoesNotExposeLocalUser() {
        let problem = Problem(description: "Lorem ipsum", source: nil)
        XCTAssertNil(problem.diagnostic.source, "Convenience initializer for Problem should not capture source file location")
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.ProblemTests")
        XCTAssertEqual(problem.diagnostic.localizedSummary, "Lorem ipsum")
    }
}
