/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class SnippetTests: XCTestCase {
    func testNoPath() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let source = """
        @Snippet()
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        XCTAssertNil(Snippet(from: directive, source: nil, for: bundle, in: context, problems: &problems))
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual(.warning, problems[0].diagnostic.severity)
        XCTAssertEqual("org.swift.docc.HasArgument.path", problems[0].diagnostic.identifier)
    }

    func testHasInnerContent() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let source = """
        @Snippet(path: "path/to/snippet") {
            This content shouldn't be here.
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        XCTAssertNotNil(Snippet(from: directive, source: nil, for: bundle, in: context, problems: &problems))
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual(.warning, problems[0].diagnostic.severity)
        XCTAssertEqual("org.swift.docc.Snippet.NoInnerContentAllowed", problems[0].diagnostic.identifier)
    }

    func testLinkResolves() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: bundle, in: context, problems: &problems))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testUnresolvedSnippetPathDiagnostic() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let source = """
        @Snippet(path: "Test/Snippets/DoesntExist")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        var resolver = MarkupReferenceResolver(context: context, bundle: bundle, source: nil, rootReference: context.rootModules[0])
        _ = resolver.visit(document)
        XCTAssertEqual(1, resolver.problems.count)
        resolver.problems.first.map {
            XCTAssertEqual("org.swift.docc.unresolvedTopicReference", $0.diagnostic.identifier)
        }
    }
    
    func testSliceResolves() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet", slice: "foo")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: bundle, in: context, problems: &problems))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertEqual("foo", snippet.slice)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(problems.isEmpty)
    }
}
