/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import Testing
@testable import SwiftDocC

struct JSONPointerTests {
    @Test
    func encodesCodingPathByEscapingCharactersUsingCodingPathInitializer() throws {
        let codingPath = try createCodingPathWithSpecialCharacters()
        
        let pointer = JSONPointer(from: codingPath)
        let encodedPointer = try JSONDecoder().decode(String.self, from: JSONEncoder().encode(pointer))
        
        #expect(encodedPointer == "/property/0/property~1with~0special~1~0characters")
    }
    
    @Test
    func encodesCodingPathByEscapingCharactersUsingPathComponentsInitializer() throws {
        let pointer = JSONPointer(pathComponents: ["a~", "foo/bar"])
        let encodedPointer = try JSONDecoder().decode(String.self, from: JSONEncoder().encode(pointer))
        
        #expect(encodedPointer == "/a~0/foo~1bar")
    }
    
    @Test
    func decodesEscapedComponents() throws {
        let pointerData = #""/a~0/foo~1bar""#.data(using: .utf8)!
        let encodedPointer = try JSONDecoder().decode(JSONPointer.self, from: pointerData)
        
        #expect(encodedPointer.description == "/a~0/foo~1bar")
        #expect(encodedPointer.pathComponents == ["a~", "foo/bar"])
    }
    
    @Test
    func describesPointerWithLeadingSlashSeparator() {
        #expect(JSONPointer(pathComponents: ["a", "b"]).description == "/a/b")
    }
    
    @Test
    func removesFirstPathComponent() {
        #expect(
            JSONPointer(pathComponents: ["a", "b"]).removingFirstPathComponent().pathComponents
                == ["b"]
        )
    }
    
    @Test
    func prependsPathComponents() {
        #expect(
            JSONPointer(pathComponents: ["c", "d", "e"])
                .prependingPathComponents(["a", "b"])
                .pathComponents
                == ["a", "b", "c", "d", "e"]
        )
    }
    
    /// Returns a coding path for testing.
    ///
    /// The coding path is composed of the following components:
    /// - "property"
    /// - Index 0
    /// - "property/with~special/~characters"
    private func createCodingPathWithSpecialCharacters() throws -> [any CodingKey] {
        let encoder = JSONEncoder()
        let codingPathContainer = CodingPathContainer()
        encoder.userInfo[.codingPath] = codingPathContainer
        _ = try encoder.encode(TestEncodable())
        return try #require(codingPathContainer.codingPath)
    }
    
    private struct TestEncodable: Encodable {
        enum CodingKeys: CodingKey {
            case property
        }
        
        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent([NestedValue()], forKey: .property)
        }
        
        struct NestedValue: Encodable {
            enum CodingKeys: String, CodingKey {
                case propertyWithSpecialCharacters = "property/with~special/~characters"
            }
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encodeIfPresent(NestedValue(), forKey: .propertyWithSpecialCharacters)
            }
            
            struct NestedValue: Encodable {
                func encode(to encoder: any Encoder) throws {
                    (encoder.userInfo[.codingPath] as? CodingPathContainer)?.codingPath = encoder.codingPath
                }
            }
        }
    }
    
    class CodingPathContainer {
        var codingPath: [any CodingKey]? = nil
    }
}

fileprivate extension CodingUserInfoKey {
    static let codingPath = CodingUserInfoKey(rawValue: "codingPath")!
}
