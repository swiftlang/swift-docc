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

class XcodeRequirementTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@XcodeRequirement"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(XcodeRequirement.directiveName, directive.name)
            let requirement = XcodeRequirement(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNil(requirement)
            XCTAssertEqual(2, diagnostics.count)
            XCTAssertEqual(diagnostics.map(\.identifier), [
                "org.swift.docc.HasArgument.title",
                "org.swift.docc.HasArgument.destination",
            ])
            XCTAssert(diagnostics.allSatisfy { $0.severity == .warning })
        }
    }
    
    func testValid() async throws {
        let title = "Xcode 10.2 Beta 3"
        let destination = "https://www.example.com/download"
        let source = """
@XcodeRequirement(title: "\(title)", destination: "\(destination)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)
        
        let context = try await makeEmptyContext()
        
        if let directive {
            var diagnostics = [Diagnostic]()
            XCTAssertEqual(XcodeRequirement.directiveName, directive.name)
            let requirement = XcodeRequirement(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
            XCTAssertNotNil(requirement)
            XCTAssertTrue(diagnostics.isEmpty)
            requirement.map { requirement in
                XCTAssertEqual(title, requirement.title)
                XCTAssertEqual(destination, requirement.destination.absoluteString)
            }
        }
    }
}
