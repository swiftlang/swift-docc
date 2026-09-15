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

struct VariantPatchOperationTests {
    @Test(arguments: [
        (patch: [VariantPatchOperation<[Int]>.add(value: [4, 5, 6])], expected: [1, 2, 3, 4, 5, 6]),
        (patch: [.remove], expected: []),
        (patch: [.replace(value: [4, 5, 6])], expected: [4, 5, 6]),
        (
            patch: [
                .replace(value: [4, 5, 6]),
                .remove,
                .add(value: [6, 7]),
                .add(value: [8, 9]),
            ],
            expected: [6, 7, 8, 9]
        ),
    ])
    func appliesPatchOperations(patch: [VariantPatchOperation<[Int]>], expected: [Int]) {
        let variant = makeVariantCollection([1, 2, 3], patch: patch)
        #expect(variant.value(for: testTraits) == expected)
    }
    
    @Test(arguments: zip(
        0...8,
        [
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
    ))
    func appliesPrefixOfPatchOperationsCumulatively(prefixLength: Int, expected: String) {
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
        let variant = makeVariantCollection("A", patch: Array(stringPatches.prefix(prefixLength)))
        #expect(variant.value(for: testTraits) == expected)
    }
    
    @Test
    func mapsValueOfReplaceAndAddOperationsAndPreservesRemove() {
        let transform: (String) -> String = { "\($0) transformed" }
        
        let replace = VariantPatchOperation<String>.replace(value: "replace")
        guard case .replace(let value) = replace.map(transform) else {
            Issue.record("Expected replace operation")
            return
        }
        #expect(value == "replace transformed")
        
        let add = VariantPatchOperation<String>.add(value: "add")
        guard case .add(let value) = add.map(transform) else {
            Issue.record("Expected add operation")
            return
        }
        #expect(value == "add transformed")
        
        let remove = VariantPatchOperation<String>.remove.map(transform)
        guard case .remove = remove else {
            Issue.record("Expected remove operation")
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
