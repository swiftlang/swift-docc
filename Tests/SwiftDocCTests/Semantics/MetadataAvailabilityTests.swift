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

class MetadataAvailabilityTests: XCTestCase {
    func testInvalidWithNoArguments() throws {
        let source = "@Available"
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(MetadataAvailability.directiveName, directive.name)
            let availability = MetadataAvailability(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNil(availability)
            XCTAssertEqual(1, problems.count)
            let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
            XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MetadataAvailability.self).emptyAttribute"))
        }
    }

    func testInvalidIntroducedForAllPlatforms() throws {
        func assertInvalidDirective(source: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(MetadataAvailability.directiveName, directive.name)
                let availability = MetadataAvailability(from: directive, source: nil, for: bundle, in: context, problems: &problems)
                XCTAssertNil(availability)
                XCTAssertEqual(1, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertTrue(diagnosticIdentifiers.contains("org.swift.docc.\(MetadataAvailability.self).introducedVersionForAllPlatforms"))
            }
        }

        try assertInvalidDirective(source: "@Available(introduced: \"1.0\")")
        try assertInvalidDirective(source: "@Available(*, introduced: \"1.0\")")
    }

    func testInvalidDuplicateIntroduced() throws {
        func assertInvalidDirective(source: String) throws {
            let document = Document(parsing: source, options: .parseBlockDirectives)
            let directive = document.child(at: 0) as? BlockDirective
            XCTAssertNotNil(directive)

            let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")

            directive.map { directive in
                var problems = [Problem]()
                XCTAssertEqual(Metadata.directiveName, directive.name)
                let _ = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
                XCTAssertEqual(2, problems.count)
                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
                XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.\(MetadataAvailability.self).DuplicateIntroduced"])
            }
        }

        for platform in MetadataAvailability.Platform.allCases {
            guard platform != .any else { continue }

            let source = """
            @Metadata {
                @Available(\(platform.rawValue), introduced: \"1.0\")
                @Available(\(platform.rawValue), introduced: \"2.0\")
            }
            """
            try assertInvalidDirective(source: source)
        }
    }

    func testInvalidDuplicateBeta() throws {
        throw XCTSkip("FIXME: isBeta is unused (https://github.com/apple/swift-docc/issues/441)")

//        func assertInvalidDirective(source: String) throws {
//            let document = Document(parsing: source, options: .parseBlockDirectives)
//            let directive = document.child(at: 0) as? BlockDirective
//            XCTAssertNotNil(directive)
//
//            let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
//
//            directive.map { directive in
//                var problems = [Problem]()
//                XCTAssertEqual(Metadata.directiveName, directive.name)
//                let _ = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
//                XCTAssertEqual(2, problems.count)
//                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
//                XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.\(MetadataAvailability.self).DuplicateBeta"])
//            }
//        }
//
//        for platform in MetadataAvailability.Platform.allCases {
//            let source = """
//            @Metadata {
//                @Available(\(platform.rawValue), isBeta: true)
//                @Available(\(platform.rawValue), isBeta: true)
//            }
//            """
//            try assertInvalidDirective(source: source)
//        }
//
//        // also test for giving no platform
//        let source = """
//        @Metadata {
//            @Available(isBeta: true)
//            @Available(isBeta: true)
//        }
//        """
//        try assertInvalidDirective(source: source)
    }

    func testInvalidDuplicateDeprecated() throws {
        throw XCTSkip("FIXME: isDeprecated is unused (https://github.com/apple/swift-docc/issues/441)")

//        func assertInvalidDirective(source: String) throws {
//            let document = Document(parsing: source, options: .parseBlockDirectives)
//            let directive = document.child(at: 0) as? BlockDirective
//            XCTAssertNotNil(directive)
//
//            let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")
//
//            directive.map { directive in
//                var problems = [Problem]()
//                XCTAssertEqual(Metadata.directiveName, directive.name)
//                let _ = Metadata(from: directive, source: nil, for: bundle, in: context, problems: &problems)
//                XCTAssertEqual(2, problems.count)
//                let diagnosticIdentifiers = Set(problems.map { $0.diagnostic.identifier })
//                XCTAssertEqual(diagnosticIdentifiers, ["org.swift.docc.\(MetadataAvailability.self).DuplicateDeprecated"])
//            }
//        }
//
//        for platform in MetadataAvailability.Platform.allCases {
//            let source = """
//            @Metadata {
//                @Available(\(platform.rawValue), isDeprecated: true)
//                @Available(\(platform.rawValue), isDeprecated: true)
//            }
//            """
//            try assertInvalidDirective(source: source)
//        }
//
//        // also test for giving no platform
//        let source = """
//        @Metadata {
//            @Available(isDeprecated: true)
//            @Available(isDeprecated: true)
//        }
//        """
//        try assertInvalidDirective(source: source)
    }

    func testValidDirective() throws {
        // assemble all the combinations of arguments you could give
        let validArguments: [String] = [
            // FIXME: isBeta and isDeprecated are unused (https://github.com/apple/swift-docc/issues/441)
//            "isBeta: true",
//            "isDeprecated: true",
//            "isBeta: true, isDeprecated: true",
        ]
        // separate those that give a version so we can test the `*` platform separately
        var validArgumentsWithVersion = ["introduced: \"1.0\""]
        for arg in validArguments {
            validArgumentsWithVersion.append("introduced: \"1.0\", \(arg)")
        }

        for platform in MetadataAvailability.Platform.allCases {
            if platform != .any {
                for args in validArgumentsWithVersion {
                    try assertValidAvailability(source: "@Available(\(platform.rawValue), \(args))")
                }
            } else {
                for args in validArguments {
                    try assertValidAvailability(source: "@Available(\(platform.rawValue), \(args))")
                }
            }
        }

        // also test for giving no platform
        for args in validArguments {
            try assertValidAvailability(source: "@Available(\(args))")
        }

        // basic validity test for giving several directives
        // FIXME: re-add isBeta after that is implemented (https://github.com/apple/swift-docc/issues/441)
        let source = """
        @Metadata {
            @Available(macOS, introduced: "11.0")
            @Available(iOS, introduced: "15.0")
        }
        """
        try assertValidMetadata(source: source)
    }

    func assertValidDirective<Directive: AutomaticDirectiveConvertible>(_ type: Directive.Type, source: String) throws {
        let document = Document(parsing: source, options: .parseBlockDirectives)
        let directive = document.child(at: 0) as? BlockDirective
        XCTAssertNotNil(directive)

        let (bundle, context) = try testBundleAndContext(named: "AvailabilityBundle")

        directive.map { directive in
            var problems = [Problem]()
            XCTAssertEqual(Directive.directiveName, directive.name)
            let converted = Directive(from: directive, source: nil, for: bundle, in: context, problems: &problems)
            XCTAssertNotNil(converted)
            XCTAssert(problems.isEmpty)
        }
    }

    func assertValidAvailability(source: String) throws {
        try assertValidDirective(MetadataAvailability.self, source: source)
    }

    func assertValidMetadata(source: String) throws {
        try assertValidDirective(Metadata.self, source: source)
    }
}
