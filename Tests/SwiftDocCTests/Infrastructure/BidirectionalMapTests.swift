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

class BidirectionalMapTests: XCTestCase {
    func testEmpty() throws {
        let map = BidirectionalMap<String, Int>()

        XCTAssertNil(map[0])
        XCTAssertNil(map[-100])
        
        XCTAssertNil(map[""])
        XCTAssertNil(map["test"])
    }

    func testStoresValues() throws {
        var map = BidirectionalMap<String, Int>()

        // Test 1:1 relationships
        map[0] = "Test Value"
        map[100] = "Another Value"
        
        XCTAssertEqual(map[0], "Test Value")
        XCTAssertEqual(map["Test Value"], 0)
        XCTAssertEqual(map[100], "Another Value")
        XCTAssertEqual(map["Another Value"], 100)

        // Update existing relationship
        map[0] = "Updated Value"
        
        XCTAssertEqual(map[0], "Updated Value")
        XCTAssertEqual(map["Updated Value"], 0)
        XCTAssertNil(map["Test Value"])
        
        // Update the updated relationship
        map["Updated Value"] = 3
        XCTAssertEqual(map["Updated Value"], 3)
        XCTAssertEqual(map[3], "Updated Value")
        XCTAssertNil(map[0])
    }
}
