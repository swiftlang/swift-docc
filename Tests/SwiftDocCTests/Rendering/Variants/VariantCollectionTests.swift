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

class VariantCollectionTests: XCTestCase {
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
    
    func testCreatesObjectiveCVariant() {
        XCTAssertEqual(testCollection.defaultValue, "default value")
        guard case .replace(let value) = testCollection.variants[0].patch[0] else {
            XCTFail("Unexpected patch value")
            return
        }
        XCTAssertEqual(value, "Objective-C value")
    }
    
    func testEncodesDefaultValueAndAddsVariantsInEncoder() throws {
        let encoder = RenderJSONEncoder.makeEncoder()
        let encodedAndDecodedValue = try JSONDecoder()
            .decode(VariantCollection<String>.self, from: encoder.encode(testCollectionWithMultipleVariants))
        
        XCTAssertEqual(encodedAndDecodedValue.defaultValue, "default value")
        XCTAssert(encodedAndDecodedValue.variants.isEmpty)
        
        let variants = try XCTUnwrap((encoder.userInfo[.variantOverrides] as? VariantOverrides)?.values)
        XCTAssertEqual(variants.count, 2)
        
        for (index, variant) in variants.enumerated() {
            let expectedLanguage: String
            let expectedValue: String
            
            switch index {
            case 0:
                expectedLanguage = "language A"
                expectedValue = "language A value"
            case 1:
                expectedLanguage = "language B"
                expectedValue = "language B value"
            default: continue
            }
            
            XCTAssertEqual(variant.traits, [.interfaceLanguage(expectedLanguage)])
            
            
            guard case .replace(_, let value) = variant.patch[0] else {
                XCTFail("Unexpected patch operation")
                return
            }
                
            XCTAssertEqual(value.value as! String, expectedValue)
        }
    }
    
    func testMapValues() {
        let testCollection = testCollection.mapValues { value -> String? in
            if value == "default value" {
               return "default value transformed"
            }
            
            return nil
        }
        
        XCTAssertEqual(testCollection.defaultValue, "default value transformed")
        
        guard case .replace(let value)? = testCollection.variants.first?.patch.first else {
            XCTFail()
            return
        }
        
        XCTAssertNil(value)
    }
}
