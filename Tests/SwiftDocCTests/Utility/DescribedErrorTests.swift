/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

fileprivate struct TestError: DescribedError {
    var errorDescription: String {
        return "TestError"
    }
}

class DescribedErrorTests: XCTestCase {
    func testLocalizedDescription() {
        // This tests for an infinite recursion and that the right overload
        // is called.
        let error = TestError()
        XCTAssertEqual("TestError", error.errorDescription)
        
        let foundationError = error as Foundation.LocalizedError
        XCTAssertEqual("TestError", foundationError.errorDescription)
    }
}
