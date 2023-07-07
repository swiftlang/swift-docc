/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown

@testable import SwiftDocC

class CallToActionTests: XCTestCase {
    func testInvalidWithNoArguments() throws {
        let source = "@CallToAction"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(callToAction)
            XCTAssertEqual(2, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLink"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLabel"))
        }
    }

    func testInvalidWithoutLink() throws {
        func assertMissingLink(source: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems)
                XCTAssertNil(callToAction)
                XCTAssertEqual(1, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLink"))
            }
        }
        try assertMissingLink(source: "@CallToAction(label: \"Button\")")
        try assertMissingLink(source: "@CallToAction(purpose: download)")
    }

    func testInvalidWithoutLabel() throws {
        func assertMissingLabel(source: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems)
                XCTAssertNil(callToAction)
                XCTAssertEqual(1, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLabel"))
            }
        }
        try assertMissingLabel(source: "@CallToAction(url: \"https://example.com/sample.zip\"")
        try assertMissingLabel(source: "@CallToAction(file: \"Downloads/plus.svg\"")
    }

    func testInvalidTooManyLinks() throws {
        let source = "@CallToAction(url: \"https://example.com/sample.zip\", file: \"Downloads/plus.svg\", purpose: download)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(callToAction)
            XCTAssertEqual(1, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).tooManyLinks"))
        }
    }

    func testValidDirective() throws {
        func assertValidDirective(source: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems)
                XCTAssertNotNil(callToAction)
                XCTAssert(problems.isEmpty)
            }
        }

        let validLinks: [String] = [
            "url: \"https://example.com/sample.zip\"",
            "file: \"Downloads/plus.svg\""
        ]

        var validLabels: [String] = [
            "label: \"Button\""
        ]
        for buttonKind in CallToAction.Purpose.allCases {
            validLabels.append("purpose: \(buttonKind)")
            // Having both a kind and a label is valid
            validLabels.append("purpose: \(buttonKind), label: \"Button\"")
        }

        for link in validLinks {
            for label in validLabels {
                try assertValidDirective(source: "@CallToAction(\(link), \(label))")
            }
        }
    }

    func testDefaultLabel() throws {
        func assertExpectedLabel(source: String, expectedDefaultLabel: String, expectedSampleCodeLabel: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = try XCTUnwrap(document.child(at: 0) as? BlockDirective)

            let (bundle, context) = try testBundleAndContext(named: "SampleBundle")

            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = try XCTUnwrap(CallToAction(from: directive, source: nil, for: bundle, in: context, problems: &problems))
            XCTAssert(problems.isEmpty)
            
            XCTAssertEqual(callToAction.buttonLabel(for: nil), expectedDefaultLabel)
            XCTAssertEqual(callToAction.buttonLabel(for: .article), expectedDefaultLabel)
            XCTAssertEqual(callToAction.buttonLabel(for: .sampleCode), expectedSampleCodeLabel)
        }

        var validLabels: [(arg: String, defaultLabel: String, sampleCodeLabel: String)] = []
        for buttonKind in CallToAction.Purpose.allCases {
            let expectedDefaultLabel: String
            let expectedSampleCodeLabel: String
            switch buttonKind {
            case .download:
                expectedDefaultLabel = "Download"
                expectedSampleCodeLabel = "Download"
            case .link:
                expectedDefaultLabel = "Visit"
                expectedSampleCodeLabel = "View Source"
            }
            
            validLabels.append(("purpose: \(buttonKind)", expectedDefaultLabel, expectedSampleCodeLabel))
            // Ensure that adding a label argument overrides the kind's default label
            validLabels.append(("purpose: \(buttonKind), label: \"Button\"", "Button", "Button"))
        }

        for (arg, defaultLabel, sampleCodeLabel) in validLabels {
            let directive = "@CallToAction(file: \"Downloads/plus.svg\", \(arg))"
            try assertExpectedLabel(
                source: directive,
                expectedDefaultLabel: defaultLabel,
                expectedSampleCodeLabel: sampleCodeLabel
            )
        }
    }
}
