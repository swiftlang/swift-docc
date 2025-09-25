/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2025 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class DocumentationInputsIdentifierTests: XCTestCase {
    private typealias Identifier = DocumentationContext.Inputs.Identifier
    
    func testInitialization() {
        let id = Identifier(rawValue: "com.example.test")
        XCTAssertEqual(id.rawValue, "com.example.test")
        
        let idWithSpace = Identifier(rawValue: "Package  Name")
        XCTAssertEqual(idWithSpace.rawValue, "Package-Name", "The initializer transforms the value to a valid identifier")
    }
    
    func testExpressibleByStringLiteral() {
        let id: Identifier = "com.example.test"
        XCTAssertEqual(id.rawValue, "com.example.test")
        
        let idWithSpace: Identifier = "Package  Name"
        XCTAssertEqual(idWithSpace.rawValue, "Package-Name", "The initializer transforms the value to a valid identifier")
    }
    
    func testEquatable() {
        XCTAssertEqual(Identifier(rawValue: "A"), "A")
        XCTAssertNotEqual(Identifier(rawValue: "A"), "B")
    }
    
    func testComparable() {
        XCTAssertLessThan(Identifier(rawValue: "B"), "C")
        XCTAssertGreaterThan(Identifier(rawValue: "B"), "A")
    }
    
    func testCustomStringConvertible() {
        XCTAssertEqual(Identifier(rawValue: "com.example.test").description, "com.example.test")
        XCTAssertEqual(Identifier(rawValue: "Package  Name").description, "Package-Name")
        
    }
    
    func testEncodesAsPlainString() throws {
        let id = Identifier(rawValue: "com.example.test")
        let encoded = try String(data: JSONEncoder().encode(id), encoding: .utf8)
        XCTAssertEqual(encoded, "\"com.example.test\"")
    }
    
    func testDecodingFromPlainString() throws {
        let decoded = try JSONDecoder().decode(Identifier.self, from: Data("\"com.example.test\"".utf8))
        XCTAssertEqual(decoded, "com.example.test")
    }
}
