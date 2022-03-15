/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class GroupedSequenceTests: XCTestCase {
    /// A grouped sequence of strings, with their number of characters as the key.
    var groupedSequence = GroupedSequence<Int, String>(deriveKey: \.count)
    
    func testAppends() {
        groupedSequence.append("a")
        groupedSequence.append("aa")
        
        XCTAssertEqual(groupedSequence[1], "a")
        XCTAssertEqual(groupedSequence[2], "aa")
        
        groupedSequence.append("b")
        XCTAssertEqual(groupedSequence[1], "b")
    }
    
    func testAppendContentsOf() {
        groupedSequence.append(contentsOf: ["a", "aa"])
        
        XCTAssertEqual(groupedSequence[1], "a")
        XCTAssertEqual(groupedSequence[2], "aa")
    }
    
    func testIterator() {
        groupedSequence.append(contentsOf: ["a", "aa"])
        
        for (index, item) in groupedSequence.sorted().enumerated() {
            switch index {
            case 0:
                XCTAssertEqual(item, "a")
            case 1:
                XCTAssertEqual(item, "aa")
            default:
                XCTFail("Unexpected number of items in the grouped sequence")
            }
        }
    }
}

