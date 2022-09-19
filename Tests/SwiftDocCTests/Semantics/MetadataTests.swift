/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation

import XCTest
@testable import SwiftDocC
import Markdown

class MetadataTests: XCTestCase {
    func testEmpty() throws {
        let source = "@Metadata"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata, "Even if a Metadata directive is empty we can create it")
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.Metadata.NoConfiguration", problems.first?.diagnostic.identifier)
        XCTAssertEqual(.information, problems.first?.diagnostic.severity)
        XCTAssertNotNil(problems.first?.possibleSolutions.first)
    }
    
    func testUnexpectedArgument() throws {
        let source = "@Metadata(argument: value)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata, "Even if there are warnings we can create a metadata value")
        XCTAssertEqual(2, problems.count)
        XCTAssertEqual("org.swift.docc.UnknownArgument", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Metadata.NoConfiguration", problems.last?.diagnostic.identifier)
    }
    
    func testUnexpectedDirective() throws {
        let source = """
        @Metadata {
           @Image
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata, "Even if there are warnings we can create a Metadata value")
        XCTAssertEqual(3, problems.count)
        XCTAssertEqual("org.swift.docc.HasOnlyKnownDirectives", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Metadata.UnexpectedContent", problems.dropFirst().first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Metadata.NoConfiguration", problems.last?.diagnostic.identifier)

    }
    
    func testExtraContent() throws {
        let source = """
        @Metadata {
           Some text
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata, "Even if there are warnings we can create a Metadata value")
        XCTAssertEqual(2, problems.count)
        XCTAssertEqual("org.swift.docc.Metadata.UnexpectedContent", problems.first?.diagnostic.identifier)
        XCTAssertEqual("org.swift.docc.Metadata.NoConfiguration", problems.last?.diagnostic.identifier)
    }
    
    // MARK: - Supported metadata directives
    
    func testDocumentationExtensionSupport() throws {
        let source = """
        @Metadata {
           @DocumentationExtension(mergeBehavior: append)
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata)
        XCTAssertEqual(0, problems.count)
        XCTAssertEqual(metadata?.documentationOptions?.behavior, .append)
    }
    
    func testRepeatDocumentationExtension() throws {
        let source = """
        @Metadata {
           @DocumentationExtension(mergeBehavior: append)
           @DocumentationExtension(mergeBehavior: override)
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata)
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasAtMostOne<Metadata, DocumentationExtension>.DuplicateChildren", problems.first?.diagnostic.identifier)
        XCTAssertEqual(metadata?.documentationOptions?.behavior, .append)
    }
    
    func testDisplayNameSupport() throws {
        let source = """
        @Metadata {
           @DisplayName("Custom Name")
        }
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let metadata = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(metadata)
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        XCTAssertEqual(metadata?.displayName?.name, "Custom Name")
    }
    
    // MARK: - Metadata Support
    
    func testArticleSupportsMetadata() throws {
        let source = """
        # Plain article
        
        @Metadata {
           @DocumentationExtension(mergeBehavior: override)
        }

        The abstract of this article
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Metadata child.")
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got:\n \(analyzer.problems.localizedDescription)")
    }
    
    func testSymbolArticleSupportsMetadataDisplayName() throws {
        let source = """
        # ``SomeSymbol``
        
        @Metadata {
           @DisplayName("Custom Name")
        }

        The abstract of this documentation extension
        """
        let document = Document(parsing: source, options:  [.parseBlockDirectives, .parseSymbolLinks])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Metadata child with a DisplayName child.")
        XCTAssertNotNil(article?.metadata?.displayName, "The Article has the parsed DisplayName metadata.")
        
        XCTAssert(problems.isEmpty, "There shouldn't be any problems. Got:\n\(problems.map { $0.diagnostic.localizedSummary })")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        XCTAssert(analyzer.problems.isEmpty, "Expected no problems. Got:\n \(analyzer.problems.localizedDescription)")
    }
    
    func testArticleDoesNotSupportsMetadataDisplayName() throws {
        let source = """
        # Article title
        
        @Metadata {
           @DisplayName("Custom Name")
        }

        The abstract of this documentation extension
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Metadata child with a DisplayName child.")
        XCTAssertNotNil(article?.metadata, "The Article has the parsed Metadata")
        XCTAssertNil(article?.metadata?.displayName, "The Article doesn't have the DisplayName")
        
        XCTAssertEqual(problems.count, 1)
        let problem = try XCTUnwrap(problems.first)
        
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.Article.DisplayName.NotSupported")
        XCTAssertEqual(problem.diagnostic.localizedSummary, "A 'DisplayName' directive is only supported in documentation extension files. To customize the display name of an article, change the content of the level-1 heading.")
        
        XCTAssertEqual(problem.possibleSolutions.count, 1)
        let solution = try XCTUnwrap(problem.possibleSolutions.first)
        
        XCTAssertEqual(solution.summary, "Change the title")
        XCTAssertEqual(solution.replacements.count, 2)
        XCTAssertEqual(solution.replacements.first?.range, SourceLocation(line: 4, column: 4, source: nil) ..< SourceLocation(line: 4, column: 31, source: nil))
        XCTAssertEqual(solution.replacements.first?.replacement, "")
        
        XCTAssertEqual(solution.replacements.last?.range, SourceLocation(line: 1, column: 1, source: nil) ..< SourceLocation(line: 1, column: 16, source: nil))
        XCTAssertEqual(solution.replacements.last?.replacement, "# Custom Name")
    }
    
    func testDuplicateMetadata() throws {
        let source = """
        # Article title
        
        @Metadata {
          @DocumentationExtension(mergeBehavior: append)
        }
        @Metadata {
          @DocumentationExtension(mergeBehavior: override)
        }

        The abstract of this documentation extension
        """
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(article, "An Article value can be created with a Metadata child with a DisplayName child.")
        XCTAssertNotNil(article?.metadata, "The Article has the parsed Metadata")
        XCTAssertNil(article?.metadata?.displayName, "The Article doesn't have the DisplayName")
        
        XCTAssertEqual(1, problems.count)
        XCTAssertEqual("org.swift.docc.HasAtMostOne<Article, Metadata>.DuplicateChildren", problems.first?.diagnostic.identifier)
        
    }
    
    func testPageImageSupport() throws {
        let (problems, metadata) = try parseMetadataFromSource(
            """
            # Article title
            
            @Metadata {
                @PageImage(source: "plus", purpose: icon)
                @PageImage(source: "sloth", alt: "A sloth on a branch.", purpose: card)
            }
            
            The abstract of this article.
            """
        )
        
        XCTAssertEqual(problems, [])
        XCTAssertEqual(metadata.pageImages.count, 2)
        
        let plusImage = metadata.pageImages.first { pageImage in
            pageImage.source.path == "plus"
        }
        XCTAssertEqual(plusImage?.purpose, .icon)
        XCTAssertEqual(plusImage?.alt, nil)
        
        let slothImage = metadata.pageImages.first { pageImage in
            pageImage.source.path == "sloth"
        }
        XCTAssertEqual(slothImage?.purpose, .card)
        XCTAssertEqual(slothImage?.alt, "A sloth on a branch.")
    }
    
    func testDuplicatePageImage() throws {
        let (problems, _) = try parseMetadataFromSource(
            """
            # Article title
            
            @Metadata {
                @PageImage(source: "plus", purpose: icon)
                @PageImage(source: "sloth", alt: "A sloth on a branch.", purpose: icon)
            }
            
            The abstract of this article.
            """
        )
        
        XCTAssertEqual(
            problems,
            [
                "4: warning – org.swift.docc.DuplicatePageImage",
                "5: warning – org.swift.docc.DuplicatePageImage",
            ]
        )
    }
    
    func parseMetadataFromSource(
        _ source: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> (problems: [String], metadata: Metadata) {
        let document = Document(parsing: source, options: [.parseBlockDirectives, .parseSymbolLinks])
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var analyzer = SemanticAnalyzer(source: nil, context: context, bundle: bundle)
        _ = analyzer.visit(document)
        var problems = analyzer.problems
        
        let article = Article(from: document, source: nil, for: bundle, in: context, problems: &problems)
        
        let problemIDs = problems.map { problem -> String in
            let line = problem.diagnostic.range?.lowerBound.line.description ?? "unknown-line"
            
            return "\(line): \(problem.diagnostic.severity) – \(problem.diagnostic.identifier)"
        }.sorted()
        
        let metadata = try XCTUnwrap(article?.metadata, file: file, line: line)
        
        return (problemIDs, metadata)
    }
}
