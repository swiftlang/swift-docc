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

class DocumentationExtensionTests: XCTestCase {
    func testEmpty() async throws {
        let source = "@DocumentationExtension"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(options)
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasArgument.mergeBehavior", diagnostics.first?.identifier)
    }
    
    func testAppendArgumentValue() async throws {
        let source = "@DocumentationExtension(mergeBehavior: append)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(options)
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual("org.swift.docc.DocumentationExtension.NoConfiguration", diagnostics.first?.identifier)
        XCTAssertEqual(options?.behavior, .append)
    }
    
    func testOverrideArgumentValue() async throws {
        let source = "@DocumentationExtension(mergeBehavior: override)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(options)
        XCTAssertTrue(diagnostics.isEmpty)
        XCTAssertEqual(options?.behavior, .override)
    }
    
    func testUnknownArgumentValue() async throws {
        let source = "@DocumentationExtension(mergeBehavior: somethingUnknown )"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(options)
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasArgument.mergeBehavior.ConversionFailed", diagnostics.first?.identifier)
    }
    
    func testExtraArguments() async throws {
        let source = "@DocumentationExtension(mergeBehavior: override, argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(options, "Even if there are warnings we can create an options value")
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", diagnostics.first?.identifier)
    }
    
    func testExtraDirective() async throws {
        let source = """
        @DocumentationExtension(mergeBehavior: override) {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(options, "Even if there are warnings we can create a DocumentationExtension value")
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(2, diagnostics.count)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", diagnostics.first?.identifier)
        XCTAssertEqual("org.swift.docc.DocumentationExtension.NoInnerContentAllowed", diagnostics.last?.identifier)
    }
    
    func testExtraContent() async throws {
        let source = """
        @DocumentationExtension(mergeBehavior: override) {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(options, "Even if there are warnings we can create a DocumentationExtension value")
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.DocumentationExtension.NoInnerContentAllowed")
    }
    
    func testIncorrectArgumentLabel() async throws {
        let source = "@DocumentationExtension(merge: override)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let options = DocumentationExtension(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(options)
        XCTAssertFalse(diagnostics.containsAnyError)
        XCTAssertEqual(2, diagnostics.count)
        
        XCTAssertEqual(diagnostics.map(\.identifier).sorted(), [
            "org.swift.docc.HasArgument.mergeBehavior",
            "org.swift.docc.UnknownArgument",
        ])
    }
}
