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

class HasOnlySequentialHeadingsTests: XCTestCase {
    private let containerDirective = BlockDirective(name: "TestContainer")
    
    func testNoHeadings() throws {
        let source = """
asdf

another para

@ADirective

some more *stuff*
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)

        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(containerDirective, children: document.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testValidHeadings() throws {
        let source = """
## H2
### H3
#### H4
## H2
### H3
## H2
### H3
#### H4
### H3
## H2
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)

        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(containerDirective, children: document.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testHeadingLevelTooLow() throws {
        let source = """
# H1
# H1
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)

        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(containerDirective, children: document.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.map { $0.diagnostic.localizedSummary },
                       [
                        "This heading doesn't meet or exceed the minimum allowed heading level (2)",
                        "This heading doesn't meet or exceed the minimum allowed heading level (2)",
                       ])
    }
    
    func testHeadingSkipsLevel() throws {
            let source = """
## H2
#### H4
###### H6
##### H5
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)

        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        
        var problems: [Problem] = []
        Semantic.Analyses.HasOnlySequentialHeadings<TutorialArticle>(severityIfFound: .warning, startingFromLevel: 2).analyze(containerDirective, children: document.children, source: nil, for: bundle, in: context, problems: &problems)
        
        XCTAssertEqual(problems.map { $0.diagnostic.localizedSummary },
                       [
                        "This heading doesn't sequentially follow the previous heading",
                        "This heading doesn't sequentially follow the previous heading",
                        "This heading doesn't sequentially follow the previous heading",
        				])
    }
}
