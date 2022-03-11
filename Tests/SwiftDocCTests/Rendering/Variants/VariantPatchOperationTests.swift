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

class VariantPatchOperationTests: XCTestCase {
    func testApplyingPatch() {
        let original = [1, 2, 3]
        let addVariant = VariantCollection<[Int]>.Variant(traits: [], patch: [
            .add(value: [4, 5, 6])
        ])
        XCTAssertEqual(addVariant.applyingPatchTo(original), [1, 2, 3, 4, 5, 6])
        
        let removeVariant = VariantCollection<[Int]>.Variant<[Int]>(traits: [], patch: [
            .remove
        ])
        XCTAssertEqual(removeVariant.applyingPatchTo(original), [])
        
        let replaceVariant = VariantCollection<[Int]>.Variant(traits: [], patch: [
            .replace(value: [4, 5, 6])
        ])
        XCTAssertEqual(replaceVariant.applyingPatchTo(original), [4, 5, 6])
        
        let mixVariant = VariantCollection<[Int]>.Variant(traits: [], patch: [
            .replace(value: [4, 5, 6]),
            .remove,
            .add(value: [6, 7]),
            .add(value: [8, 9]),
        ])
        XCTAssertEqual(mixVariant.applyingPatchTo(original), [6, 7, 8, 9])
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
            let stringVariant = VariantCollection<String>.Variant<String>(traits: [], patch: Array(stringPatches.prefix(index)))
            XCTAssertEqual(stringVariant.applyingPatchTo("A"), expectedValue)
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
}
