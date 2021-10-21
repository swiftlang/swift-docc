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

class JSONPointerTests: XCTestCase {
    func testEncodesCodingPathByEscapingCharacters() throws {
        let codingPath = try createCodingPathWithSpecialCharacters()
        
        let pointer = JSONPointer(from: codingPath)
        let encodedPointer = try JSONDecoder().decode(String.self, from: JSONEncoder().encode(pointer))

        XCTAssertEqual(encodedPointer, "/property/0/property~1with~0special~1~0characters")
    }
    
    func testEncodesRawComponentsWithoutEscaping() throws {
        let pointer = JSONPointer(components: ["a~0", "foo~1bar"])
        let encodedPointer = try JSONDecoder().decode(String.self, from: JSONEncoder().encode(pointer))

        XCTAssertEqual(encodedPointer, "/a~0/foo~1bar")
    }
    
    /// Returns a coding path for testing.
    ///
    /// The coding path is composed of the following components:
    /// - "property"
    /// - Index 0
    /// - "property/with~special/~characters"
    private func createCodingPathWithSpecialCharacters() throws -> [CodingKey] {
        let encoder = JSONEncoder()
        let codingPathContainer = CodingPathContainer()
        encoder.userInfo[.codingPath] = codingPathContainer
        _ = try encoder.encode(TestEncodable())
        return try XCTUnwrap(codingPathContainer.codingPath)
    }
    
    private struct TestEncodable: Encodable {
        enum CodingKeys: CodingKey {
            case property
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent([NestedValue()], forKey: .property)
        }
        
        struct NestedValue: Encodable {
            enum CodingKeys: String, CodingKey {
                case propertyWithSpecialCharacters = "property/with~special/~characters"
            }
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(NestedValue(), forKey: .propertyWithSpecialCharacters)
            }
            
            struct NestedValue: Encodable {
                func encode(to encoder: Encoder) throws {
                    (encoder.userInfo[.codingPath] as? CodingPathContainer)?.codingPath = encoder.codingPath
                }
            }
        }
    }
    
    class CodingPathContainer {
        var codingPath: [CodingKey]? = nil
    }
}

fileprivate extension CodingUserInfoKey {
    static let codingPath = CodingUserInfoKey(rawValue: "codingPath")!
}
