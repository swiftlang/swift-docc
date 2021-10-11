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

class XcodeRequirementTests: XCTestCase {
    func testEmpty() throws {
        let source = "@XcodeRequirement"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(XcodeRequirement.directiveName, directive.name)
            let requirement = XcodeRequirement(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(requirement)
            XCTAssertEqual(2, problems.count)
            XCTAssertEqual(
                [
                    "org.swift.docc.HasArgument.title",
                    "org.swift.docc.HasArgument.destination",
                ],
                problems.map { $0.diagnostic.identifier }
            )
            XCTAssert(problems.map { $0.diagnostic.severity }.allSatisfy { $0 == .warning })
        }
    }
    
    func testValid() throws {
        let title = "Xcode 10.2 Beta 3"
        let destination = "https://www.example.com/download"
        let source = """
@XcodeRequirement(title: "\(title)", destination: "\(destination)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(XcodeRequirement.directiveName, directive.name)
            let requirement = XcodeRequirement(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(requirement)
            XCTAssertTrue(problems.isEmpty)
            requirement.map { requirement in
                XCTAssertEqual(title, requirement.title)
                XCTAssertEqual(destination, requirement.destination.absoluteString)
            }
        }
    }
}
