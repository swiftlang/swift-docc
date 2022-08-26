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

class TutorialReferenceTests: XCTestCase {
    func testEmpty() throws {
        let source = """
@TutorialReference
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(tutorialReference)
        XCTAssertEqual(1, problems.count)
        problems.first.map { problem in
            XCTAssertEqual("org.swift.docc.HasArgument.tutorial", problem.diagnostic.identifier)
            XCTAssertEqual(.warning, problem.diagnostic.severity)
        }
    }
    
    func testValid() throws {
        let tutorialLink = "doc:MyTutorial"
        let source = """
@TutorialReference(tutorial: "\(tutorialLink)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNotNil(tutorialReference)
        tutorialReference.map { tutorialReference in
            guard case let .unresolved(unresolved) = tutorialReference.topic else {
                fatalError()
            }
            XCTAssertEqual(ValidatedURL(parsingExact: tutorialLink), unresolved.topicURL)
        }
        XCTAssertTrue(problems.isEmpty)
    }
    
    func testMissingPath() throws {
        let tutorialLink = "doc:"
        let source = """
        @TutorialReference(tutorial: "\(tutorialLink)")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (bundle, context) = try testBundleAndContext(named: "TestBundle")
        var problems = [Problem]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: bundle, in: context, problems: &problems)
        XCTAssertNil(tutorialReference)
        XCTAssertEqual(problems.count, 1)
        let problem = try XCTUnwrap(problems.first)
        XCTAssertEqual("org.swift.docc.HasArgument.tutorial.ConversionFailed", problem.diagnostic.identifier)
    }
}
