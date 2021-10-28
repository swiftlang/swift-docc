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

class VariantOverridesTests: XCTestCase {
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
    
    func testRegistersNewOverrideIfNoOverridesOfTheSameTraitHaveBeenRegistered() {
        let variantOverrides = VariantOverrides(values: [overrideA])
        
        variantOverrides.add(overrideB)
        
        XCTAssertEqual(variantOverrides.values.count, 2)
        XCTAssertEqual(variantOverrides.values[1].traits, [.interfaceLanguage("language B")])
    }
    
    func testRegistersPatchInExistingOverrideIfAnOverrideWithTheSameTraitHasBeenRegistered() throws {
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
        
        XCTAssertEqual(variantOverrides.values.count, 1)
        let variantOverride = try XCTUnwrap(variantOverrides.values.first)
        XCTAssertEqual(variantOverride.traits, [.interfaceLanguage("language A")])
        
        XCTAssertEqual(variantOverride.patch.count, 2)
        
        for (index, patchOperation) in variantOverride.patch.enumerated() {
            let expectedPointerComponents: [String]
            let expectedValue: String
            
            switch index {
            case 0:
                expectedPointerComponents = ["a"]
                expectedValue = "value1"
            case 1:
                expectedPointerComponents = ["b", "c"]
                expectedValue = "value2"
            default:
                continue
            }
            
            XCTAssertEqual(patchOperation.pointer.pathComponents, expectedPointerComponents)
            
            guard case .replace(_, let value) = patchOperation else {
                XCTFail("Unexpected patch operation")
                return
            }
            
            XCTAssertEqual(value.value as! String, expectedValue)
        }
    }
    
    func testRegistersMultipleOverrides() {
        let variantOverrides = VariantOverrides()
        variantOverrides.add(contentsOf: [overrideA, overrideB])
        XCTAssertEqual(variantOverrides.values.count, 2)
    }
    
    func testEncodesAsASingleValue() throws {
        let encodedVariantOverrides = try JSONEncoder().encode(VariantOverrides(values: [overrideA]))
        
        let variantOverrides = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encodedVariantOverrides) as? NSArray
        )
        
        XCTAssertEqual(
            variantOverrides,
            [
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
    
    func testDecodesAsASingleValue() throws {
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
        
        XCTAssertEqual(overrides.values.count, 1)
        
        let variantOverride = try XCTUnwrap(overrides.values.first)
        XCTAssertEqual(variantOverride.traits, [.interfaceLanguage("objc")])
        
        XCTAssertEqual(variantOverride.patch.count, 1)
        let patchOperation = try XCTUnwrap(variantOverride.patch.first)
        
        XCTAssertEqual(patchOperation.operation, .replace)
        
        guard case .replace(_, let value) = patchOperation, case .string(let stringValue) = value.value as? JSON else {
            XCTFail()
            return
        }
        
        XCTAssertEqual(stringValue, "value")
        XCTAssertEqual(patchOperation.pointer.pathComponents, ["a", "b"])
    }
}
