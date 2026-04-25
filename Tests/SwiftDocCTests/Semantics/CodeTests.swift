/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class CodeTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@Code"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let code = Code(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(code)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasArgument.file", diagnostics.first?.identifier)
        XCTAssert(diagnostics.allSatisfy { $0.severity == .warning })
    }
}
