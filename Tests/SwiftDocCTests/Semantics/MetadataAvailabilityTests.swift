/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import Markdown

@testable import SwiftDocC

class MetadataAvailabilityTests: XCTestCase {
    func testInvalidWithNoArguments() throws {
        let source = "@Available"
        
        try assertDirective(Metadata.Availability.self, source: source) { directive, problems in
            XCTAssertNil(directive)
            
            XCTAssertEqual(2, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            let diagnosticExplanations = Set(problems.map { $0.diagnostic.explanation })
            XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.HasArgument.unlabeled", "org.swift.docc.HasArgument.introduced"])
            XCTAssertEqual(diagnosticExplanations, [
                "Available expects an argument for the \'introduced\' parameter that\'s convertible to a semantic version number (\'[0-9]+(.[0-9]+)?(.[0-9]+)?\')",
                "Available expects an argument for an unnamed parameter that\'s convertible to \'Platform\'"
            ])
        }
    }

    func testInvalidDuplicateIntroduced() throws {
        for platform in Metadata.Availability.Platform.defaultCases {
            let source = """
            @Metadata {
                @Available(\(platform.rawValue), introduced: \"1.0\")
                @Available(\(platform.rawValue), introduced: \"2.0\")
            }
            """
            try assertDirective(Metadata.self, source: source) { directive, problems in
                XCTAssertEqual(2, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.\(Metadata.Availability.self).DuplicateIntroduced"])
            }
        }
    }
    
    func testInvalidIntroducedFormat() throws {
        let source = """
        @Metadata {
            @TechnologyRoot
            @Available(Package, introduced: \"\")
            @Available(Package, introduced: \".\")
            @Available(Package, introduced: \"1.\")
            @Available(Package, introduced: \".1\")
            @Available(Package, introduced: \"test\")
            @Available(Package, introduced: \"test.1.2\")
            @Available(Package, introduced: \"2.1.test\")
            @Available(Package, introduced: \"test.test.test\")
        }
        """

        try assertDirective(Metadata.self, source: source) { directive, problems in
            XCTAssertEqual(8, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            let diagnosticExplanations = Set(problems.map { $0.diagnostic.explanation })
            XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.HasArgument.introduced.ConversionFailed"])
            XCTAssertEqual(diagnosticExplanations, [
                "Available expects an argument for the \'introduced\' parameter that\'s convertible to a semantic version number (\'[0-9]+(.[0-9]+)?(.[0-9]+)?\')",
            ])
        }
    }
    
    func testValidSemanticVersionFormat() throws {
        let source = """
        @Metadata {
            @Available(iOS, introduced: \"3.5.2\", deprecated: \"5.6.7\")
            @Available(macOS, introduced: \"3.5\", deprecated: \"5.6\")
            @Available(Package, introduced: \"3\", deprecated: \"5\")
        }
        """

        try assertDirective(Metadata.self, source: source) { directive, problems in
            XCTAssertEqual(0, problems.count)

            let directive = try XCTUnwrap(directive)
            XCTAssertEqual(3, directive.availability.count)

            let platforms = directive.availability.map { $0.platform }
            XCTAssertEqual(platforms, [
                .iOS,
                .macOS,
                .other("Package")
            ])
            
            let introducedVersions = directive.availability.map { $0.introduced }
            XCTAssertEqual(introducedVersions, [
                SemanticVersion(major: 3, minor: 5, patch: 2),
                SemanticVersion(major: 3, minor: 5, patch: 0),
                SemanticVersion(major: 3, minor: 0, patch: 0)
            ])
                        
            let deprecatedVersions = directive.availability.map { $0.deprecated }
            XCTAssertEqual(deprecatedVersions, [
                SemanticVersion(major: 5, minor: 6, patch: 7),
                SemanticVersion(major: 5, minor: 6, patch: 0),
                SemanticVersion(major: 5, minor: 0, patch: 0)
            ])

        }
    }

    func testValidIntroducedDirective() throws {
        // Assemble all the combinations of arguments you could give
        let validArguments: [String] = [
          "deprecated: \"1.0\"",
        ]
        // separate those that give a version so we can test the `*` platform separately
        var validArgumentsWithVersion = ["introduced: \"1.0\""]
        for arg in validArguments {
            validArgumentsWithVersion.append("introduced: \"1.0\", \(arg)")
            validArgumentsWithVersion.append("\(arg), introduced: \"1.0\"")
        }

        var checkPlatforms = Metadata.Availability.Platform.defaultCases.map({ $0.rawValue })
        checkPlatforms += [
            "Package",
            "\"My Package\"", // Also check a platform with spaces in the name
            // FIXME: Test validArguments with the `*` platform once that's introduced (https://github.com/apple/swift-docc/issues/969)
//            "*",
        ]
        
        for platform in checkPlatforms {
            for args in validArgumentsWithVersion {
                try assertValidAvailability(source: "@Available(\(platform), \(args))")
            }
        }
    }
        
    /// Basic validity test for giving several directives.
    func testMultipleAvailabilityDirectives() throws {
        let source = """
        @Metadata {
            @Available(macOS, introduced: "11.0")
            @Available(iOS, introduced: "15.0")
            @Available(watchOS, introduced: "7.0", deprecated: "9.0")
            @Available("My Package", introduced: "0.1", deprecated: "1.0")
        }
        """
        try assertValidMetadata(source: source)
    }
    
    func assertDirective<Directive: AutomaticDirectiveConvertible>(_ type: Directive.Type, source: String, assertion assert: (Directive?, [Problem]) throws -> Void) throws {
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")

        try directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Directive.directiveName, directive.name)
            let converted = Directive(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            try assert(converted, problems)
        }
    }

    func assertValidDirective<Directive: AutomaticDirectiveConvertible>(_ type: Directive.Type, source: String) throws {
        try assertDirective(type, source: source) { directive, problems in
            XCTAssertNotNil(directive)
            XCTAssert(problems.isEmpty)
        }
    }

    func assertValidAvailability(source: String) throws {
        try assertValidDirective(Metadata.Availability.self, source: source)
    }

    func assertValidMetadata(source: String) throws {
        try assertValidDirective(Metadata.self, source: source)
    }
}
