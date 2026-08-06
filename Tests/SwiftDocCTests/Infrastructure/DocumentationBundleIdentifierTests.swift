/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Testing
import Foundation
@testable import SwiftDocC

struct DocumentationBundleIdentifierTests {
    private typealias Identifier = DocumentationBundle.Identifier
    
    @Test(arguments: [
        "com.example.test": "com.example.test",
        "Package  Name": "Package-Name", // The initializer transforms the value to a valid identifier
        "Before: After": "Before-After", // The initializer transforms the value to a valid identifier
    ])
    func replacedDisallowedCharactersWhenInitialized(_ input: String, expectedParsedValue: String) {
        #expect(Identifier(rawValue: input).rawValue == expectedParsedValue)
    }
    
    @Test
    func replacedDisallowedCharactersWhenExpressibleByStringLiteral() {
        let id: Identifier = "com.example.test"
        #expect(id.rawValue == "com.example.test")
        
        let idWithSpace: Identifier = "Package  Name"
        #expect(idWithSpace.rawValue == "Package-Name", "The initializer transforms the value to a valid identifier")
        
        let idWithColon: Identifier = "Before: After"
        #expect(idWithColon.rawValue == "Before-After", "The initializer transforms the value to a valid identifier")
    }
    
    @Test
    func isEquatableWithStringLiteral() {
        #expect(Identifier(rawValue: "A") == "A")
        #expect(Identifier(rawValue: "A") != "B")
    }
    
    @Test
    func isComparableToStringLiteral() {
        #expect(Identifier(rawValue: "B") < "C")
        #expect(Identifier(rawValue: "B") > "A")
    }
    
    @Test
    func describesItsRawValue() {
        #expect(Identifier(rawValue: "com.example.test").description == "com.example.test")
        #expect(Identifier(rawValue: "Package  Name").description == "Package-Name")
    }
    
    @Test
    func encodesAsSinglePlainStringValue() throws {
        let id = Identifier(rawValue: "com.example.test")
        let encoded = try String(data: JSONEncoder().encode(id), encoding: .utf8)
        #expect(encoded == "\"com.example.test\"")
    }
    
    @Test
    func canDecodeFromFromPlainString() throws {
        let decoded = try JSONDecoder().decode(Identifier.self, from: Data("\"com.example.test\"".utf8))
        #expect(decoded == "com.example.test")
    }
}
