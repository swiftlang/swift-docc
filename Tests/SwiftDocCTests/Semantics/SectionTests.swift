/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class TutorialSectionTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Section"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let section = TutorialSection(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(section)
        XCTAssertEqual(2, problems.count)
        XCTAssertEqual(
            problems.map { $0.diagnostic.identifier },
            [
                "org.swift.docc.HasArgument.title",
                "org.swift.docc.HasExactlyOne<Section, Steps>.Missing",
            ]
        )
        XCTAssert(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
    }
}
