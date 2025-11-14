/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocCUtilities

class ThrottleTests: XCTestCase {
    func testThrottlingSingleCall() throws {
        let completes = expectation(description: "Fullfills throttling test")
        let throttle = Throttle(interval: .milliseconds(250))

        throttle.schedule {
            completes.fulfill()
        }
        
        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error)
        }
    }
    
    func testThrottlingMultipleCalls() throws {
        let completes = expectation(description: "Fullfills throttling test")
        let throttle = Throttle(interval: .milliseconds(250))

        for counter in 0...5 {
            throttle.schedule {
                XCTAssertEqual(5, counter)
                completes.fulfill()
            }
        }
        
        waitForExpectations(timeout: 1) { error in
            XCTAssertNil(error)
        }
    }
}
