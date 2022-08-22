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

class ArticleTests: XCTestCase {
    func testValid() throws {
        let source = """
        # This is my article

        This is an abstract.

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertEqual(article?.abstract?.plainText, "This is an abstract.")
        XCTAssertEqual((article?.discussion?.content ?? []).map { $0.detachedFromParent.format() }.joined(separator: "\n"), "Here’s an overview.")
    }
    
    func testWithExplicitOverviewHeading() throws {
        let source = """
        # This is my article

        This is an abstract.

        ## Overview

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertEqual(article?.abstract?.plainText, "This is an abstract.")
        XCTAssertEqual((article?.discussion?.content ?? []).map { $0.detachedFromParent.format() }.joined(separator: "\n"), "## Overview\nHere’s an overview.")
        
        if let heading = (article?.discussion?.content ?? []).first as? Heading {
            XCTAssertEqual(heading.level, 2)
            XCTAssertEqual(heading.title, "Overview")
        } else {
            XCTFail("The first discussion element should be a heading")
        }
    }
    
    func testWithExplicitCustomHeading() throws {
        let source = """
        # This is my article

        This is an abstract.

        ## Some custom heading

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)")
        
        XCTAssertEqual(article?.title?.detachedFromParent.format(), "# This is my article")
        XCTAssertEqual(article?.abstract?.detachedFromParent.format(), "This is an abstract.")
        XCTAssertEqual(article?.discussion?.content.map { $0.detachedFromParent.format() }.joined(separator: "\n"),
                        "## Some custom heading\nHere’s an overview.")
        
        if let heading = (article?.discussion?.content ?? []).first as? Heading {
            XCTAssertEqual(heading.level, 2)
            XCTAssertEqual(heading.title, "Some custom heading")
        } else {
            XCTFail("The first discussion element should be a heading")
        }
    }
    
    func testOnlyTitleArticle() throws {
        let source = """
        # This is my article
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertNil(article?.abstract)
        XCTAssertNil(article?.discussion)
    }
    
    func testNoAbstract() throws {
        let source = """
        # This is my article

        - This is not an abstract.
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssert(problems.isEmpty, "Unexpectedly found problems: \(problems.localizedDescription)")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertNil(article?.abstract)
        XCTAssertEqual((article?.discussion?.content ?? []).map { $0.detachedFromParent.format() }.joined(separator: "\n"), "- This is not an abstract.")
    }
    
    func testSolutionForTitleMissingIndentation() throws {
        let source = """
         My article

         This is my article
         """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)

        XCTAssertNil(article)
        XCTAssertEqual(problems.count, 1)
        let problem = try XCTUnwrap(problems.first)
        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "# My article")
    }

    func testSolutionForEmptyArticle() throws {
        let source = """
         
        """
        let document = Document(parsing: source, options: [])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)

        XCTAssertNil(article)
        XCTAssertEqual(problems.count, 1)
        let problem = try XCTUnwrap(problems.first)
        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "# <#Title#>")
    }
    
    func testArticleWithDuplicateOptions() throws {
        let source = """
        # Article
        
        @Options {
            @AutomaticSeeAlso(disabled)
        }

        This is an abstract.
        
        @Options {
            @AutomaticSeeAlso(siblingPages)
        }

        Here's an overview.
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article)
        XCTAssertEqual(
            problems.map(\.diagnostic.identifier),
            [
                "org.swift.docc.HasAtMostOne<Article, Options, local>.DuplicateChildren",
            ]
        )
        
        XCTAssertEqual(problems.count, 1)
        XCTAssertEqual(
            problems.first?.diagnostic.identifier,
            "org.swift.docc.HasAtMostOne<Article, Options, local>.DuplicateChildren"
        )
        XCTAssertEqual(
            problems.first?.diagnostic.range?.lowerBound.line,
            9
        )
        
        XCTAssertEqual(article?.options[.local]?.automaticSeeAlsoBehavior, .disabled)
    }
}
