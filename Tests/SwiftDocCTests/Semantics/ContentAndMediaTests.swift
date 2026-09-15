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

class ContentAndMediaTests: XCTestCase {
    func testEmpty() async throws {
        let source = """
@ContentAndMedia {
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertEqual(0, diagnostics.count)
    }
    
    func testValid() async throws {
        let source = """
@ContentAndMedia {
   
   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(diagnostics.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.leading, contentAndMedia.mediaPosition)
        }
    }
    
    func testTrailingMiddleMediaPosition() async throws {
        let source = """
@ContentAndMedia {
   
   Blah.
   
   @Image(source: "/path/to/image", alt: blah)
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(diagnostics.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.trailing, contentAndMedia.mediaPosition)
        }
    }
    
    func testTrailingMediaPosition() async throws {
        let source = """
@ContentAndMedia {
   
   Foo.
   
   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertTrue(diagnostics.isEmpty)
        contentAndMedia.map { contentAndMedia in
            XCTAssertEqual(.trailing, contentAndMedia.mediaPosition)
        }
    }

    func testDeprecatedArguments() async throws {
        let source = """
@ContentAndMedia(layout: horizontal, eyebrow: eyebrow, title: title) {

   @Image(source: "/path/to/image", alt: blah)

   Blah.
}
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let contentAndMedia = ContentAndMedia(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(contentAndMedia)
        XCTAssertEqual(.leading, contentAndMedia?.mediaPosition)
        XCTAssertEqual(diagnostics.count, 3)
        XCTAssertEqual(diagnostics.map(\.identifier), [
            "org.swift.docc.DeprecatedArgument.eyebrow",
            "org.swift.docc.DeprecatedArgument.title",
            "org.swift.docc.DeprecatedArgument.layout",
        ])
    }
}
