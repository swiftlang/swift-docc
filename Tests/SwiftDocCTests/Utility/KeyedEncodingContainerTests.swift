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

class KeyedEncodingContainerTests: XCTestCase {
    struct EncodingStruct: Codable {
        var age: Int
        var names: [String]
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(age, forKey: .age)
            try container.encodeIfNotEmpty(names, forKey: .names)
        }
    }
    
    func testEncodeIfNotEmpty() throws {
        do {
            // Test when the array is not empty
            let test = EncodingStruct(age: 10, names: ["Winston", "Smith"])
            let data = try JSONEncoder().encode(test)
            guard let dictionary = (try JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                XCTFail("Failed to decode test structure")
                return
            }
            
            XCTAssertEqual(dictionary["age"] as? Int, 10)
            XCTAssertEqual(dictionary["names"] as? [String], ["Winston", "Smith"])
        }

        do {
            // Test when the array is empty
            let test = EncodingStruct(age: 10, names: [])
            let data = try JSONEncoder().encode(test)
            guard let dictionary = (try JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any] else {
                XCTFail("Failed to decode test structure")
                return
            }
            
            XCTAssertEqual(dictionary["age"] as? Int, 10)
            XCTAssertNil(dictionary["names"])
        }
    }
}
