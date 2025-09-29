/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class SnippetTests: XCTestCase {
    func testWarningAboutMissingPathPath() throws {
        let (bundle, _) = try testBundleAndContext()
        let source = """
        @Snippet()
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        XCTAssertNil(Snippet(from: directive, source: nil, for: bundle, problems: &problems))
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual(.warning, problems[0].diagnostic.severity)
        XCTAssertEqual("org.swift.docc.HasArgument.path", problems[0].diagnostic.identifier)
    }

    func testWarningAboutInnerContent() throws {
        let (bundle, _) = try testBundleAndContext()
        let source = """
        @Snippet(path: "path/to/snippet") {
            This content shouldn't be here.
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        XCTAssertNotNil(Snippet(from: directive, source: nil, for: bundle, problems: &problems))
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual(.warning, problems[0].diagnostic.severity)
        XCTAssertEqual("org.swift.docc.Snippet.NoInnerContentAllowed", problems[0].diagnostic.identifier)
    }

    func testParsesPath() throws {
        let (bundle, _) = try testBundleAndContext()
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: bundle, problems: &problems))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(problems.isEmpty)
    }
    func testLinkResolvesWithoutOptionalPrefix() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        
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
            var resolver = MarkupReferenceResolver(context: context, bundle: bundle, rootReference: try XCTUnwrap(context.soleRootModuleReference))
            _ = resolver.visit(document)
            XCTAssertTrue(resolver.problems.isEmpty, "Unexpected problems: \(resolver.problems.map(\.diagnostic.summary))")
        }
    }
    
    func testWarningAboutUnresolvedSnippetPath() throws {
        let (bundle, context) = try testBundleAndContext(named: "Snippets")
        
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
            var resolver = MarkupReferenceResolver(context: context, bundle: bundle, rootReference: try XCTUnwrap(context.soleRootModuleReference))
            _ = resolver.visit(document)
            XCTAssertEqual(1, resolver.problems.count)
            let problem = try XCTUnwrap(resolver.problems.first)
            XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.unresolvedSnippetPath")
            XCTAssertEqual(problem.diagnostic.summary, "Snippet named 'DoesNotExist' couldn't be found")
            XCTAssertEqual(problem.possibleSolutions.count, 0)
        }
    }
    
    func testParsesSlice() throws {
        let (bundle, _) = try testBundleAndContext()
        let source = """
        @Snippet(path: "Test/Snippets/MySnippet", slice: "foo")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as! BlockDirective
        var problems = [Problem]()
        let snippet = try XCTUnwrap(Snippet(from: directive, source: nil, for: bundle, problems: &problems))
        XCTAssertEqual("Test/Snippets/MySnippet", snippet.path)
        XCTAssertEqual("foo", snippet.slice)
        XCTAssertNotNil(snippet)
        XCTAssertTrue(problems.isEmpty)
    }
}
