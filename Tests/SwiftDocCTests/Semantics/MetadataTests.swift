/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
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
}
