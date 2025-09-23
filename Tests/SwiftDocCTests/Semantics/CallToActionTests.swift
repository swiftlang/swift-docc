/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown

@testable import SwiftDocC

class CallToActionTests: XCTestCase {
    func testInvalidWithNoArguments() async throws {
        let source = "@CallToAction"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = CallToAction(from: directive, source: nil, for: inputs, problems: &problems)
            XCTAssertNil(callToAction)
            XCTAssertEqual(2, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLink"))
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLabel"))
        }
    }

    func testInvalidWithoutLink() async throws {
        func assertMissingLink(source: String) async throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: inputs, problems: &problems)
                XCTAssertNil(callToAction)
                XCTAssertEqual(1, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLink"))
            }
        }
        try await assertMissingLink(source: "@CallToAction(label: \"Button\")")
        try await assertMissingLink(source: "@CallToAction(purpose: download)")
    }

    func testInvalidWithoutLabel() async throws {
        func assertMissingLabel(source: String) async throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: inputs, problems: &problems)
                XCTAssertNil(callToAction)
                XCTAssertEqual(1, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).missingLabel"))
            }
        }
        try await assertMissingLabel(source: "@CallToAction(url: \"https://example.com/sample.zip\"")
        try await assertMissingLabel(source: "@CallToAction(file: \"Downloads/plus.svg\"")
    }

    func testInvalidTooManyLinks() async throws {
        let source = "@CallToAction(url: \"https://example.com/sample.zip\", file: \"Downloads/plus.svg\", purpose: download)"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = CallToAction(from: directive, source: nil, for: inputs, problems: &problems)
            XCTAssertNil(callToAction)
            XCTAssertEqual(1, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(CallToAction.self).tooManyLinks"))
        }
    }

    func testValidDirective() async throws {
        func assertValidDirective(source: String) async throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(CallToAction.directiveName, directive.name)
                let callToAction = CallToAction(from: directive, source: nil, for: inputs, problems: &problems)
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
                try await assertValidDirective(source: "@CallToAction(\(link), \(label))")
            }
        }
    }

    func testDefaultLabel() async throws {
        func assertExpectedLabel(source: String, expectedDefaultLabel: String, expectedSampleCodeLabel: String) async throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = try XCTUnwrap(document.child(at: 0) as? BlockDirective)

            let inputs = try await loadFromDisk(catalogName: "SampleBundle").inputs

            var problems = [Problem]()
            XCTAssertEqual(CallToAction.directiveName, directive.name)
            let callToAction = try XCTUnwrap(CallToAction(from: directive, source: nil, for: inputs, problems: &problems))
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
            try await assertExpectedLabel(
                source: directive,
                expectedDefaultLabel: defaultLabel,
                expectedSampleCodeLabel: sampleCodeLabel
            )
        }
    }
}
