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

struct VariantCollectionTests {
    let testCollection = VariantCollection(defaultValue: "default value", objectiveCValue: "Objective-C value")
    
    let testCollectionWithMultipleVariants = VariantCollection(
        defaultValue: "default value",
        variants: [
            .init(
                traits: [.interfaceLanguage("language A")],
                patch: [.replace(value: "language A value")]
            ),
            .init(
                traits: [.interfaceLanguage("language B")],
                patch: [.replace(value: "language B value")]
            ),
        ]
    )
    
    @Test
    func createsObjectiveCVariant() {
        #expect(testCollection.defaultValue == "default value")
        guard case .replace(let value) = testCollection.variants[0].patch[0] else {
            Issue.record("Unexpected patch value")
            return
        }
        #expect(value == "Objective-C value")
    }
    
    @Test
    func encodesDefaultValueAndAddsVariantsInEncoder() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        let encodedAndDecodedValue = try JSONDecoder()
            .decode(VariantCollection<String>.self, from: encoder.encode(testCollectionWithMultipleVariants))
        
        #expect(encodedAndDecodedValue.defaultValue == "default value")
        #expect(encodedAndDecodedValue.variants.isEmpty)
        
        let variants = try #require((encoder.userInfo[.variantOverrides] as? VariantOverrides)?.values)
        #expect(variants.count == 2)
        
        let expectedVariants = [
            (language: "language A", value: "language A value"),
            (language: "language B", value: "language B value"),
        ]
        for (variant, expected) in zip(variants, expectedVariants) {
            #expect(variant.traits == [.interfaceLanguage(expected.language)])
            
            guard case .replace(_, let value) = variant.patch[0] else {
                Issue.record("Unexpected patch operation")
                return
            }
            let stringValue = try #require(value.value as? String)
            #expect(stringValue == expected.value)
        }
    }
    
    @Test
    func mapsValues() {
        let testCollection = testCollection.mapValues { value -> String? in
            if value == "default value" {
               return "default value transformed"
            }
            
            return nil
        }
        
        #expect(testCollection.defaultValue == "default value transformed")
        
        guard case .replace(let value)? = testCollection.variants.first?.patch.first else {
            Issue.record("Unexpected patch value")
            return
        }
        
        #expect(value == nil)
    }
}
