/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import SwiftDocC
import XCTest

final class NoOpSignposterShimTests: XCTestCase {
    func testRunsIntervalVoidWork() {
        let signposter = NoOpSignposterShim()
        
        let didPerformWork = expectation(description: "Did perform work")
        signposter.withIntervalSignpost("Something") {
            didPerformWork.fulfill()
        }
        
        wait(for: [didPerformWork], timeout: 10.0)
    }
    
    func testReturnsIntervalWorkResult() {
        let signposter = NoOpSignposterShim()
        
        let didPerformWork = expectation(description: "Did perform work")
        let number = signposter.withIntervalSignpost("Something") {
            didPerformWork.fulfill()
            return 7
        }
        XCTAssertEqual(number, 7)
        
        wait(for: [didPerformWork], timeout: 10.0)
    }
    
    func testCanAcceptMessageInputs() {
        // Note: this test has no assertions.
        // It simply verifies that the message interpolations compile
        let signposter = NoOpSignposterShim()
        
        let handle = signposter.beginInterval("Some interval", "Some message")
        signposter.endInterval("Some interval", handle, "Another message")
        
        signposter.emitEvent("Some event", id: signposter.makeSignpostID(), "Some static string")
        signposter.emitEvent("Some event", "Some formatted bool \(true, format: .answer)")
        signposter.emitEvent("Some event", "Some formatted integer \(12, format: .decimal)")
        signposter.emitEvent("Some event", "Some formatted float \(7.0, format: .exponential)")
        signposter.emitEvent("Some event", "Some sensitive string \("my secret", privacy: .sensitive(mask: .hash))")
        signposter.emitEvent("Some event", "Some non-secret string \("my secret", privacy: .public)")
        
        signposter.emitEvent("Some event", "Some aligned values \(12, align: .right(columns: 5)) \("some text", align: .left(columns: 10))")
        
        let logger = NoOpLoggerShim()
        
        logger.log("Some static string")
        logger.info("Some formatted bool \(true, format: .answer)")
        logger.debug("Some formatted integer \(12, format: .decimal)")
        logger.error("Some formatted float \(7.0, format: .exponential)")
        logger.fault("Some sensitive string \("my secret", privacy: .sensitive(mask: .hash))")
        logger.log(level: .fault, "Some non-secret string \("my secret", privacy: .public)")
        
        logger.log(level: .default, "Some aligned values \(12, align: .right(columns: 5)) \("some text", align: .left(columns: 10))")
        
    }
}
