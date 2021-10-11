/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class Sequence_MapFirstTests: XCTestCase {
    struct Val {
        let id: Int
        let name: String
    }
    
    func testEmpty() {
        // Test that the closure is never called for an empty collection.
        XCTAssertNil([].mapFirst(where: { "" }))
    }
    
    func testNotFound() {
        XCTAssertNil([1, 2, 3].mapFirst(where: { _ in nil }))
        XCTAssertNil([1, 2, 3].mapFirst(where: { $0 == 100 ? $0 : nil}))
        
        // Should call the closure for each element when no match is found
        var values = [Int]()
        XCTAssertNil([1, 2, 3].mapFirst(where: { values.append($0); return nil }))
        XCTAssertEqual(values, [1, 2, 3])
    }
    
    func testFound() {
        // Should return a string for the first element
        XCTAssertEqual([1, 2, 3].mapFirst(where: { _ in "TEST" }), "TEST")
        
        // Should return a boolean for the first element
        XCTAssertEqual([1, 2, 3].mapFirst(where: { $0 == 3 }), false)
        
        // Should return the last element as string
        XCTAssertEqual([1, 2, 3].mapFirst(where: { $0 == 3 ? "\($0)" : nil }), "3")
        
        // Should return the name of value with id = 2
        let values = [
            Val(id: 1, name: "Anna"),
            Val(id: 2, name: "Hannah"),
            Val(id: 3, name: "Joanna"),
        ]
        XCTAssertEqual(values.mapFirst(where: { value -> String? in
            return value.id == 2 ? value.name : nil
        }), "Hannah")
        
        // Should call the closure for each element up until the matching one
        do {
            var values = [Int]()
            _ = [1, 2, 3, 4, 5].mapFirst(where: { value -> Bool? in
                values.append(value);
                return value == 3 ? true : nil
            })
            XCTAssertEqual(values, [1, 2, 3])
        }
    }
}
