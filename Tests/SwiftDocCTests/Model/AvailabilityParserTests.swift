/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SymbolKit
@testable import SwiftDocC

typealias Availability = SymbolGraph.Symbol.Availability

class AvailabilityParserTests: XCTestCase {
    func testNoAvailability() throws {
        let json = """
        []
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        let compiler = AvailabilityParser(availability)
        XCTAssertFalse(compiler.isDeprecated())
        XCTAssertNil(compiler.deprecationMessage())
    }
    
    func testAvailable() throws {
        let json = """
        [
          {
            "domain": "macOS",
            "introduced" : { "major": 10, "minor": 17 }
          }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        let compiler = AvailabilityParser(availability)
        XCTAssertFalse(compiler.isDeprecated())
        XCTAssertNil(compiler.deprecationMessage())
    }

    func testAvailableAndDeprecatedOnPlatform() throws {
        let json = """
        [
            {
                "domain": "macOS",
                "introduced" : { "major": 10, "minor": 17 }
            },
            {
                "domain": "watchOS",
                "message": "deprecated",
                "isUnconditionallyDeprecated" : true
            }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        /// Test all platforms
        let compiler = AvailabilityParser(availability)
        XCTAssertFalse(compiler.isDeprecated())
        XCTAssertNil(compiler.deprecationMessage())
        
        /// Test watchOS
        XCTAssertTrue(compiler.isDeprecated(platform: "watchOS"))
        XCTAssertEqual(compiler.deprecationMessage(platform: "watchOS"), "deprecated")

        /// Test macOS
        XCTAssertFalse(compiler.isDeprecated(platform: "macOS"))
        XCTAssertNil(compiler.deprecationMessage(platform: "macOS"))
    }

    func testDeprecated() throws {
        let json = """
        [
            {
                "domain": "macOS",
                "isUnconditionallyUnavailable" : true
            },
            {
                "domain": "watchOS",
                "message": "deprecated",
                "isUnconditionallyDeprecated" : true
            }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        /// Test all platforms
        let compiler = AvailabilityParser(availability)
        XCTAssertTrue(compiler.isDeprecated())
        XCTAssertEqual(compiler.deprecationMessage(), "deprecated")
    }

    func testDeprecatedNoPlatform() throws {
        let json = """
        [
            {
                "message": "deprecated",
                "isUnconditionallyDeprecated" : true
            }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        /// Test all platforms
        let compiler = AvailabilityParser(availability)
        XCTAssertTrue(compiler.isDeprecated())
        XCTAssertEqual(compiler.deprecationMessage(), "deprecated")
    }

    func testDeprecatedVersionNoMessage() throws {
        let json = """
        [
            {
                "domain": "macOS",
                "isUnconditionallyUnavailable" : true
            },
            {
                "domain": "watchOS",
                "deprecated": { "major": 10, "minor": 17 }
            }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        /// Test all platforms
        let compiler = AvailabilityParser(availability)
        XCTAssertTrue(compiler.isDeprecated())
        XCTAssertNil(compiler.deprecationMessage())
    }

    func testDeprecatedVersionWithMessage() throws {
        let json = """
        [
            {
                "domain": "macOS",
                "isUnconditionallyUnavailable" : true
            },
            {
                "domain": "watchOS",
                "message" : "deprecated",
                "deprecated": { "major": 10, "minor": 17 }
            }
        ]
        """
        let availability = try JSONDecoder().decode(Availability.self, from: json.data(using: .utf8)!)
        
        /// Test all platforms
        let compiler = AvailabilityParser(availability)
        XCTAssertTrue(compiler.isDeprecated())
        XCTAssertEqual(compiler.deprecationMessage(), "deprecated")
    }
}
