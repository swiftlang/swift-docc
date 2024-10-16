/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
 */

import XCTest
@testable import SwiftDocC

final class DiagnosticBundleIdentifierTests: XCTestCase {

    func testValidBundleIdentifier() throws {
        // GIVEN
        let outputURL = try createTemporaryDirectory().appendingPathComponent("valid-bundle")
        let builder = NavigatorIndex.Builder(
            outputURL: outputURL,
            bundleIdentifier: "com.example.valid-bundle_identifier"
        )

        // WHEN
        builder.setup()

        // THEN
        XCTAssertTrue(builder.problems.isEmpty, "No problems should be reported for a valid bundle identifier")
    }

    func testInvalidBundleIdentifierWithSpace() throws {
        // GIVEN
        let outputURL = try createTemporaryDirectory().appendingPathComponent("invalid-bundle-space")
        let builder = NavigatorIndex.Builder(
            outputURL: outputURL,
            bundleIdentifier: "com.example.invalid bundle"
        )

        // WHEN
        builder.setup()

        // THEN
        XCTAssertFalse(builder.problems.isEmpty, "A problem should be reported for a bundle identifier with spaces")
        let problem = try XCTUnwrap(builder.problems.first)
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.InvalidBundleIdentifier")
        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(problem.diagnostic.summary, "Invalid characters in bundle identifier")

        let explanation = try XCTUnwrap(problem.diagnostic.explanation)
        XCTAssertTrue(explanation.contains("Bundle identifier 'com.example.invalid bundle' contains characters that are not valid in URL hosts"))
    }

    func testInvalidBundleIdentifierWithSpecialCharacters() throws {
        // GIVEN
        let outputURL = try createTemporaryDirectory().appendingPathComponent("invalid-bundle-special-chars")
        let builder = NavigatorIndex.Builder(
            outputURL: outputURL,
            bundleIdentifier: "com.example.invalid$bundle"
        )

        // WHEN
        builder.setup()

        // THEN
        XCTAssertFalse(builder.problems.isEmpty, "A problem should be reported for a bundle identifier with invalid special characters")
        let problem = try XCTUnwrap(builder.problems.first)
        XCTAssertEqual(problem.diagnostic.identifier, "org.swift.docc.InvalidBundleIdentifier")
        XCTAssertEqual(problem.diagnostic.severity, .warning)
        XCTAssertEqual(problem.diagnostic.summary, "Invalid characters in bundle identifier")

        let explanation = try XCTUnwrap(problem.diagnostic.explanation)
        XCTAssertTrue(explanation.contains("Bundle identifier 'com.example.invalid$bundle' contains characters that are not valid in URL hosts"))
    }

    func testBundleIdentifierWithValidSpecialCharacters() throws {
        // GIVEN
        let outputURL = try createTemporaryDirectory().appendingPathComponent("valid-bundle-special-chars")
        let builder = NavigatorIndex.Builder(
            outputURL: outputURL,
            bundleIdentifier: "com.example.valid-bundle_identifier.with~tilde"
        )

        // WHEN
        builder.setup()

        // THEN
        XCTAssertTrue(builder.problems.isEmpty, "No problems should be reported for a bundle identifier with valid special characters")
    }
}
