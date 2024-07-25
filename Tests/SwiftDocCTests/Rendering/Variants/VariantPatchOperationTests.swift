/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class VariantPatchOperationTests: XCTestCase {
    func testApplyingPatch() {
        let original = [1, 2, 3]
        let addVariant = makeVariantCollection(original, patch: [
            .add(value: [4, 5, 6])
        ])
        XCTAssertEqual(addVariant.value(for: testTraits), [1, 2, 3, 4, 5, 6])
        
        let removeVariant = makeVariantCollection(original, patch: [
            .remove
        ])
        XCTAssertEqual(removeVariant.value(for: testTraits), [])
        
        let replaceVariant = makeVariantCollection(original, patch: [
            .replace(value: [4, 5, 6])
        ])
        XCTAssertEqual(replaceVariant.value(for: testTraits), [4, 5, 6])
        
        let mixVariant = makeVariantCollection(original, patch: [
            .replace(value: [4, 5, 6]),
            .remove,
            .add(value: [6, 7]),
            .add(value: [8, 9]),
        ])
        XCTAssertEqual(mixVariant.value(for: testTraits), [6, 7, 8, 9])
    }
    
    func testApplyingSeriesOfPatchOperations() {
        let stringPatches: [VariantPatchOperation<String>] = [
            .replace(value: "ABC"),
            .remove,
            .replace(value: "DEF"),
            .add(value: "GHI"),
            .replace(value: "JKL"),
            .remove,
            .add(value: "MNO"),
            .add(value: "PQR"),
        ]
        let expectedValues = [
            "A",
            "ABC",
            "",
            "DEF",
            "DEFGHI",
            "JKL",
            "",
            "MNO",
            "MNOPQR",
        ]
        for (index, expectedValue) in expectedValues.enumerated() {
            let stringVariant = makeVariantCollection("A", patch: Array(stringPatches.prefix(index)))
            XCTAssertEqual(stringVariant.value(for: testTraits), expectedValue)
        }
    }
    
    func testMap() throws {
        let transform: (String) -> String = { "\($0) transformed" }
        let replace = VariantPatchOperation<String>.replace(value: "replace")
        guard case .replace(let value) = replace.map(transform) else {
            XCTFail("Expected replace operation")
            return
        }
        
        XCTAssertEqual(value, "replace transformed")
        
        let add = VariantPatchOperation<String>.add(value: "add")
        guard case .add(let value) = add.map(transform) else {
            XCTFail("Expected add operation")
            return
        }
        
        XCTAssertEqual(value, "add transformed")
        
        let remove = VariantPatchOperation<String>.remove.map(transform)
        guard case .remove = remove else {
            XCTFail("Expected remove operation")
            return
        }
    }
    
    private let testTraits = [RenderNode.Variant.Trait.interfaceLanguage("unit-test")]
    
    private func makeVariantCollection<Value>(_ original: Value, patch: [VariantPatchOperation<Value>]) -> VariantCollection<Value> {
        VariantCollection(defaultValue: original, variants: [
            .init(traits: testTraits, patch: patch)
        ])
    }
}
