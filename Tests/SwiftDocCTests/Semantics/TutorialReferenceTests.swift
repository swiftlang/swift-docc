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

class TutorialReferenceTests: XCTestCase {
    func testEmpty() async throws {
        let source = """
@TutorialReference
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(tutorialReference)
        XCTAssertEqual(1, diagnostics.count)
        diagnostics.first.map { problem in
            XCTAssertEqual("org.swift.docc.HasArgument.tutorial", problem.identifier)
            XCTAssertEqual(.warning, problem.severity)
        }
    }
    
    func testValid() async throws {
        let tutorialLink = "doc:MyTutorial"
        let source = """
@TutorialReference(tutorial: "\(tutorialLink)")
"""
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNotNil(tutorialReference)
        tutorialReference.map { tutorialReference in
            guard case let .unresolved(unresolved) = tutorialReference.topic else {
                fatalError()
            }
            XCTAssertEqual(ValidatedURL(parsingExact: tutorialLink), unresolved.topicURL)
        }
        XCTAssertTrue(diagnostics.isEmpty)
    }
    
    func testMissingPath() async throws {
        let tutorialLink = "doc:"
        let source = """
        @TutorialReference(tutorial: "\(tutorialLink)")
        """
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0)! as! BlockDirective
        let (_, context) = try await testBundleAndContext(named: "LegacyBundle_DoNotUseInNewTests")
        var diagnostics = [Diagnostic]()
        let tutorialReference = TutorialReference(from: directive, source: nil, for: context.inputs, featureFlags: context.configuration.featureFlags, diagnostics: &diagnostics)
        XCTAssertNil(tutorialReference)
        XCTAssertEqual(diagnostics.count, 1)
        let diagnostic = try XCTUnwrap(diagnostics.first)
        XCTAssertEqual("org.swift.docc.HasArgument.tutorial.ConversionFailed", diagnostic.identifier)
    }
}
