/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

/// Asynchronous expectation that works on Linux.
class AsynchronousExpectation {
    enum Result {
        case success
        case timedOut
        
        static func fromDispatchResult(_ result: DispatchTimeoutResult) -> Result {
            switch result {
                case .success: return .success
                case .timedOut: return .timedOut
            }
        }
    }

    let description: String
    private(set) var waitGroup: DispatchGroup? = DispatchGroup()
    private let groupLock = NSLock()
    
    init(description: String) {
        self.description = description
    }
    
    func fulfill() {
        groupLock.lock()
        defer { groupLock.unlock() }
        
        waitGroup?.leave()
        waitGroup = nil
    }
    
    func wait(timeout: TimeInterval) -> Result {
        groupLock.lock()
        
        precondition(waitGroup != nil)
        waitGroup!.enter()

        return DispatchQueue.global().sync { [group = self.waitGroup!] in
            groupLock.unlock()
            
            let waitResult = group.wait(timeout: .now() + timeout)
            return Result.fromDispatchResult(waitResult)
        }
    }
}

class AsynchronousExpectationTests: XCTestCase {
    func testExpectationTimesOut() throws {
        let expectation1 = AsynchronousExpectation(description: "expectation")
        let result = expectation1.wait(timeout: 2)
        XCTAssertEqual(result, .timedOut)
    }

    func testExpectationFulfills() throws {
        let expectation1 = AsynchronousExpectation(description: "expectation")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { 
            expectation1.fulfill()
        }
        let result = expectation1.wait(timeout: 2)
        XCTAssertEqual(result, .success)
    }
}
