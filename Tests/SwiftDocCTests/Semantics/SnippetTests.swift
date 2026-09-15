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

class SnippetTests: XCTestCase {
    func testWarningAboutMissingPathPath() async throws {
        let context = try await makeEmptyContext()
        let source = """
        @Snippet()
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var diagnostics = [Diagnostic]()
        XCTAssertNil(Snippet(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics))
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.severity, .warning)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasArgument.path")
    }

    func testWarningAboutInnerContent() async throws {
        let context = try await makeEmptyContext()
        let source = """
        @Snippet(path: "path/to/snippet") {
            This content shouldn't be here.
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var diagnostics = [Diagnostic]()
        XCTAssertNotNil(Snippet(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics))
        XCTAssertEqual(1, diagnostics.count)
        XCTAssertEqual(diagnostics.first?.severity, .warning)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.Snippet.NoInnerContentAllowed")
    }

    func testParsesPath() async throws {
        let context = try await makeEmptyContext()
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var diagnostics = [Diagnostic]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(diagnostics.isEmpty)
    }
    func testLinkResolvesWithoutOptionalPrefix() async throws {
        let (_, context) = try await testBundleAndContext(named: "Snippets")
        
        for snippetPath in [
            "/Test/Snippets/MySnippet",
             "Test/Snippets/MySnippet",
                  "Snippets/MySnippet",
                           "MySnippet",
        ] {
            let source = """
            @Snippet(path: "\(snippetPath)")
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            var resolver = MarkupReferenceResolver(context: context, rootReference: try XCTUnwrap(context.soleRootModuleReference))
            _ = resolver.visit(document)
            XCTAssertTrue(resolver.diagnostics.isEmpty, "Unexpected diagnostics: \(resolver.diagnostics.map(\.summary))")
        }
    }
    
    func testWarningAboutUnresolvedSnippetPath() async throws {
        let (_, context) = try await testBundleAndContext(named: "Snippets")
        
        for snippetPath in [
            "/Test/Snippets/DoesNotExist",
             "Test/Snippets/DoesNotExist",
                  "Snippets/DoesNotExist",
                           "DoesNotExist",
        ] {
            let source = """
            @Snippet(path: "\(snippetPath)")
            """
            let document = Document(parsing: source, options: .parseBlockDirectives)
            var resolver = MarkupReferenceResolver(context: context, rootReference: try XCTUnwrap(context.soleRootModuleReference))
            _ = resolver.visit(document)
            XCTAssertEqual(1, resolver.diagnostics.count)
            let diagnostic = try XCTUnwrap(resolver.diagnostics.first)
            XCTAssertEqual(diagnostic.identifier, "org.swift.docc.unresolvedSnippetPath")
            XCTAssertEqual(diagnostic.summary, "Snippet named 'DoesNotExist' couldn't be found")
            XCTAssertEqual(diagnostic.solutions.count, 0)
        }
    }
    
    func testParsesSlice() async throws {
        let context = try await makeEmptyContext()
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet", slice: "foo")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var diagnostics = [Diagnostic]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertEqual("foo", snippet.slice)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(diagnostics.isEmpty)
    }
}
