/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class PlatformAvailabilityTests: XCTestCase {
    func testDecodePlatformAvailability() throws {
        let platformAvailabilityURL = Bundle.module.url(
            forResource: "platform-availability", withExtension: "json", subdirectory: "Rendering Fixtures")!
        
        let data = try Data(contentsOf: platformAvailabilityURL)
        let symbol = try RenderNode.decode(fromJSON: data)
        
        guard let platforms = symbol.metadata.platforms else {
            XCTFail("No platform data found in fixture")
            return
        }
        
        // The "macOS" platform in the fixture is unconditionally deprecated
        XCTAssertEqual(true, platforms.first { $0.name == "macOS" }?.unconditionallyDeprecated)

        // The "iOS" platform in the fixture is unconditionally unavailable
        XCTAssertEqual(true, platforms.first { $0.name == "iOS" }?.unconditionallyUnavailable)
    }
}
