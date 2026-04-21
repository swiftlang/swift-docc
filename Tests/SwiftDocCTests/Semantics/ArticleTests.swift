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
import DocCCommon

class ArticleTests: XCTestCase {
    func testValid() async throws {
        let source = """
        # This is my article

        This is an abstract.

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertEqual(article?.abstract?.plainText, "This is an abstract.")
        XCTAssertEqual((article?.discussion?.content ?? []).map { $0.detachedFromParent.format() }.joined(separator: "\n"), "Here’s an overview.")
    }
    
    func testWithExplicitOverviewHeading() async throws {
        let source = """
        # This is my article

        This is an abstract.

        ## Overview

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")
        
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
    
    func testWithExplicitCustomHeading() async throws {
        let source = """
        # This is my article

        This is an abstract.

        ## Some custom heading

        Here's an overview.
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")
        
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
    
    func testOnlyTitleArticle() async throws {
        let source = """
        # This is my article
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertNil(article?.abstract)
        XCTAssertNil(article?.discussion)
    }
    
    func testNoAbstract() async throws {
        let source = """
        # This is my article

        - This is not an abstract.
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")
        
        XCTAssertEqual(article?.title?.plainText, "This is my article")
        XCTAssertNil(article?.abstract)
        XCTAssertEqual((article?.discussion?.content ?? []).map { $0.detachedFromParent.format() }.joined(separator: "\n"), "- This is not an abstract.")
    }
    
    func testSolutionForTitleMissingIndentation() async throws {
        let source = """
         My article

         This is my article
         """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)

        XCTAssertNil(article)
        XCTAssertEqual(diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual(diagnostic.severity, .warning)
        XCTAssertEqual(diagnostic.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(diagnostic.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "# My article")
    }

    func testSolutionForEmptyArticle() async throws {
        let source = """
         
        """
        let document = Document(parsing: source, options: [])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)

        XCTAssertNil(article)
        XCTAssertEqual(diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual(diagnostic.severity, .warning)
        XCTAssertEqual(diagnostic.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(diagnostic.possibleSolutions.first)
        XCTAssertEqual(solution.replacements.count, 1)
        let replacement = try XCTUnwrap(solution.replacements.first)
        XCTAssertEqual(replacement.replacement, "# <#Title#>")
    }
    
    func testArticleWithDuplicateOptions() async throws {
        let source = """
        # Article
        
        @Options {
            @AutomaticSeeAlso(disabled)
        }

        This is an abstract.
        
        @Options {
            @AutomaticSeeAlso(enabled)
        }

        Here's an overview.
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(article)
        XCTAssertEqual(diagnostics.map(\.identifier), [
            "org.swift.docc.HasAtMostOne<Article, Options, local>.DuplicateChildren",
        ])
        
        XCTAssertEqual(diagnostics.count, 1)
        XCTAssertEqual(diagnostics.first?.identifier, "org.swift.docc.HasAtMostOne<Article, Options, local>.DuplicateChildren")
        XCTAssertEqual(diagnostics.first?.range?.lowerBound.line, 9)
        
        XCTAssertEqual(article?.options[.local]?.automaticSeeAlsoEnabled, false)
    }
    
    func testDisplayNameDirectiveIsRemoved() async throws {
        let source = """
        # Root
        
        @Metadata {
          @TechnologyRoot
          @PageColor(purple)
          @DisplayName("Example")
        }
        
        Adding @DisplayName to an article will result in a warning.
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        
        XCTAssertEqual(diagnostics.map(\.summary), [
            "A 'DisplayName' directive is only supported in documentation extension files. To customize the display name of an article, change the content of the level-1 heading."
        ])
        
        let semantic = try XCTUnwrap(article)
        XCTAssertNotNil(semantic.metadata, "Article should have a metadata container since the markup has a @Metadata directive")
        XCTAssertNotNil(semantic.metadata?.technologyRoot, "Article should have a technology root configuration since the markup has a @TechnologyRoot directive")
        XCTAssertNotNil(semantic.metadata?.pageColor, "Article should have a page color configuration since the markup has a @PageColor directive")
        
        XCTAssertNil(semantic.metadata?.displayName, "Articles shouldn't have a display name metadata configuration, even though the markup has a @DisplayName directive. Article names are specified by the level-1 header instead of a metadata directive.")
        
        // Non-optional child directives should be initialized.
        XCTAssertEqual(semantic.metadata?.pageImages, [])
        XCTAssertEqual(semantic.metadata?.customMetadata, [])
        XCTAssertEqual(semantic.metadata?.availability, [])
        XCTAssertEqual(semantic.metadata?.supportedLanguages, [])
        
        // Optional child directives should default to nil
        XCTAssertNil(semantic.metadata?.documentationOptions)
        XCTAssertNil(semantic.metadata?.callToAction)
        XCTAssertNil(semantic.metadata?.pageKind)
        XCTAssertNil(semantic.metadata?.titleHeading)
    }

    func testSupportedLanguageDirective() async throws {
        let source = """
        # Root

        @Metadata {
          @SupportedLanguage(swift)
          @SupportedLanguage(objc)
          @SupportedLanguage(data)
        }
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives])
        let context = try await makeEmptyContext()
        var diagnostics = [Diagnostic]()
        let article = Article(from: document, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)

        XCTAssert(diagnostics.isEmpty, "Unexpectedly found diagnostics: \(diagnostics.map(\.summary))")

        XCTAssertNotNil(article)
        XCTAssertNotNil(article?.metadata, "Article should have a metadata container since the markup has a @Metadata directive")
        XCTAssertEqual(article?.metadata?.supportedLanguages.map(\.language), [.swift, .objectiveC, .data])
    }
}
