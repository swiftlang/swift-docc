/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

public class DiffAvailabilityTests: XCTestCase {
    func testDecode() throws {
        let json = """
        {
          "minor": {
            "change": "modified",
            "platform": "Xcode",
            "versions": [
              "11.3",
              "11.4"
            ]
          },
          "beta": {
            "change": "modified",
            "platform": "Xcode",
            "versions": [
              "11.4 beta 3",
              "11.4"
            ]
          },
          "major": {
            "change": "modified",
            "platform": "Xcode",
            "versions": [
              "11.0",
              "11.4"
            ]
          },
          "sdk": {
            "change": "modified",
            "platform": "Xcode",
            "versions": [
              "12A123",
              "12A124"
            ]
          }
        }
        """.data(using: .utf8)!

        let diffAvailability = try JSONDecoder().decode(DiffAvailability.self, from: json)
        XCTAssertEqual(
            diffAvailability.minor,
            .init(change: "modified", platform: "Xcode", versions: ["11.3", "11.4"])
        )

        XCTAssertEqual(
            diffAvailability.beta,
            .init(change: "modified", platform: "Xcode", versions: ["11.4 beta 3", "11.4"])
        )

        XCTAssertEqual(
            diffAvailability.major,
            .init(change: "modified", platform: "Xcode", versions: ["11.0", "11.4"])
        )

        XCTAssertEqual(
            diffAvailability.sdk,
            .init(change: "modified", platform: "Xcode", versions: ["12A123", "12A124"])
        )
    }

    func testDecodeSomeInfoMissing() throws {
        let json = """
        {
          "minor": {
            "change": "modified",
            "platform": "Xcode",
            "versions": [
              "11.3",
              "11.4"
            ]
          }
        }
        """.data(using: .utf8)!

        let diffAvailability = try JSONDecoder().decode(DiffAvailability.self, from: json)
        XCTAssertEqual(
            diffAvailability.minor,
            .init(change: "modified", platform: "Xcode", versions: ["11.3", "11.4"])
        )
    }
}
