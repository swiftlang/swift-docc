/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class DisplayNameTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@DisplayName"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(displayName)
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.unlabeled")
    }
    
    func testUnlabeledArgumentValue() async throws {
        let source = "@DisplayName(\"Custom Symbol Name\")"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(displayName?.style, .conceptual)
    }
    
    func testConceptualStyleArgumentValue() async throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: conceptual)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(displayName?.style, .conceptual)
    }
    
    func testSymbolStyleArgumentValue() async throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: symbol)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(displayName?.style, .symbol)
    }
    
    func testUnknownStyleArgumentValue() async throws {
        let source = "@DisplayName(\"Custom Symbol Name\", style: somethingUnknown)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName)
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasArgument.style.ConversionFailed", diagnostics.first?.identifier)
    }
    
    func testExtraArguments() async throws {
        let source = "@DisplayName(\"Custom Symbol Name\", argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a displayName value")
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", diagnostics.first?.identifier)
    }
    
    func testExtraDirective() async throws {
        let source = """
        @DisplayName(\"Custom Symbol Name\") {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a DisplayName value")
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(2, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", diagnostics.first?.identifier)
        XCTAssertEqual("org.swift.docc.DisplayName.NoInnerContentAllowed", diagnostics.last?.identifier)
    }
    
    func testExtraContent() async throws {
        let source = """
        @DisplayName(\"Custom Symbol Name\") {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let displayName = DisplayName(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(displayName, "Even if there are warnings we can create a DisplayName value")
        XCTAssertFalse(diagnostics.containsError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.DisplayName.NoInnerContentAllowed", diagnostics.first?.identifier)
        XCTAssertNotNil(diagnostics.first?.possibleSolutions.first)
    }
}
