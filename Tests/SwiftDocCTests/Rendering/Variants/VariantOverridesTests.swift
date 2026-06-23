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

struct VariantOverridesTests {
    var overrideA = VariantOverride(
        traits: [.interfaceLanguage("language A")],
        patch: [
            .replace(
                pointer: JSONPointer(pathComponents: ["a"]),
                value: AnyCodable("value1")
            ),
        ]
    )
    
    var overrideB = VariantOverride(traits: [.interfaceLanguage("language B")], patch: [])
    
    @Test
    func registersNewOverrideIfNoOverridesOfTheSameTraitHaveBeenRegistered() {
        let variantOverrides = VariantOverrides(values: [overrideA])
        
        variantOverrides.add(overrideB)
        
        #expect(variantOverrides.values.count == 2)
        #expect(variantOverrides.values[1].traits == [.interfaceLanguage("language B")])
    }
    
    @Test
    func registersPatchInExistingOverrideIfAnOverrideWithTheSameTraitHasBeenRegistered() throws {
        let variantOverrides = VariantOverrides(values: [overrideA])
        
        variantOverrides.add(
            VariantOverride(
                traits: [.interfaceLanguage("language A")],
                patch: [
                    .replace(
                        pointer: JSONPointer(pathComponents: ["b", "c"]),
                        value: AnyCodable("value2")
                    ),
                ]
            )
        )
        
        #expect(variantOverrides.values.count == 1)
        let variantOverride = try #require(variantOverrides.values.first)
        #expect(variantOverride.traits == [.interfaceLanguage("language A")])
        
        #expect(variantOverride.patch.count == 2)
        
        let expectedPatches = [
            (pointerComponents: ["a"], value: "value1"),
            (pointerComponents: ["b", "c"], value: "value2"),
        ]
        for (patchOperation, expected) in zip(variantOverride.patch, expectedPatches) {
            #expect(patchOperation.pointer.pathComponents == expected.pointerComponents)
            
            guard case .replace(_, let value) = patchOperation else {
                Issue.record("Unexpected patch operation")
                return
            }
            
            let stringValue = try #require(value.value as? String)
            #expect(stringValue == expected.value)
        }
    }
    
    @Test
    func registersMultipleOverrides() {
        let variantOverrides = VariantOverrides()
        variantOverrides.add(contentsOf: [overrideA, overrideB])
        #expect(variantOverrides.values.count == 2)
    }
    
    @Test
    func encodesAsASingleValue() throws {
        let encodedVariantOverrides = try JSONEncoder().encode(VariantOverrides(values: [overrideA]))
        
        let variantOverrides = try #require(
            JSONSerialization.jsonObject(with: encodedVariantOverrides) as? NSArray
        )
        
        #expect(
            variantOverrides
                == [
                    [
                        "traits": [
                            [ "interfaceLanguage" : "language A" ],
                        ],
                        "patch": [
                            [
                                "path": "/a",
                                "value": "value1",
                                "op": "replace",
                            ]
                        ],
                    ],
                ]
        )
    }
    
    @Test
    func decodesAsASingleValue() throws {
        let encoded = """
        [
            {
                "traits": [ { "interfaceLanguage": "objc" } ],
                "patch": [
                    {
                        "path": "/a/b",
                        "value": "value",
                        "op": "replace"
                    }
                ]
            }
        ]
        """.data(using: .utf8)!
        
        let overrides = try JSONDecoder().decode(VariantOverrides.self, from: encoded)
        
        #expect(overrides.values.count == 1)
        
        let variantOverride = try #require(overrides.values.first)
        #expect(variantOverride.traits == [.interfaceLanguage("objc")])
        
        #expect(variantOverride.patch.count == 1)
        let patchOperation = try #require(variantOverride.patch.first)
        
        #expect(patchOperation.operation == .replace)
        
        guard case .replace(_, let value) = patchOperation, case .string(let stringValue) = value.value as? JSON else {
            Issue.record("Unexpected patch operation or JSON value")
            return
        }
        
        #expect(stringValue == "value")
        #expect(patchOperation.pointer.pathComponents == ["a", "b"])
    }
}
