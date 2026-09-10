/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
import SymbolKit
@testable import SwiftDocC
import Testing

class DocumentationDataVariantsTests: XCTestCase {
    func testAccessesVariantWithTrait() throws {
        var variants = DocumentationDataVariants<String>(values: [.swift : "Swift"])
        
        XCTAssertEqual(variants[.swift], "Swift")
        
        let objectiveCTrait = DocumentationDataVariantsTrait(interfaceLanguage: "objc")
        
        XCTAssertNil(variants[objectiveCTrait])
        variants[objectiveCTrait] = "Objective-C"
        XCTAssertEqual(variants[objectiveCTrait], "Objective-C")
    }
    
    func testReturnsDefaultValueInAllValues() throws {
        let variants = DocumentationDataVariants<String>(defaultVariantValue: "Default value")
        XCTAssertEqual(variants.allValues.count, 1)
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testSetsDefaultValueWhenTraitIsFallback() throws {
        var variants = DocumentationDataVariants<String>()
        variants[.fallback] = "Default value"
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testHasAnyVariants() throws {
        XCTAssertFalse(DocumentationDataVariants<String>().hasAnyVariants)
        XCTAssert(DocumentationDataVariants<String>(values: [.swift : "Swift"]).hasAnyVariants)

        // 'hasAnyVariants' does not check the default value
        XCTAssertFalse(DocumentationDataVariants<String>(defaultVariantValue: "Default value").hasAnyVariants)
    }
    
    func testHasVariant() throws {
        XCTAssert(DocumentationDataVariants<String>(values: [.swift : "Swift"]).hasVariant(for: .swift))
        XCTAssertFalse(DocumentationDataVariants<String>().hasVariant(for: .swift))
    }
    
    func testSwiftVariantInitializer() throws {
        XCTAssertEqual(DocumentationDataVariants<String>(swiftVariant: "Swift")[.swift], "Swift")
        XCTAssertNil(DocumentationDataVariants<String>(swiftVariant: nil)[.swift])
    }
    
    func testFirstValue() throws {
        // This is testing that the first value has a stable and deterministic behavior (rdar://86580516)
        let objectiveCTrait = DocumentationDataVariantsTrait(interfaceLanguage: "objc")
        
        XCTAssertEqual(DocumentationDataVariants<String>(values: [:]).firstValue, nil)

        XCTAssertEqual(DocumentationDataVariants<String>(values: [.swift : "Swift"]).firstValue, "Swift")
        XCTAssertEqual(DocumentationDataVariants<String>(values: [objectiveCTrait : "Objective-C"]).firstValue, "Objective-C")

        // Swift is treated as the first value when there are multiple values
        XCTAssertEqual(DocumentationDataVariants<String>(values: [
            objectiveCTrait : "Objective-C",
            .swift: "Swift"
        ]).firstValue, "Swift")
        
        XCTAssertEqual(DocumentationDataVariants<String>(values: [
            objectiveCTrait : "Objective-C",
            .swift: "Swift",
            .fallback: "Fallback"
        ]).firstValue, "Swift")
        
        var variants = DocumentationDataVariants<String>(defaultVariantValue: "Default value")
        XCTAssertEqual(variants.firstValue, "Default value")
        variants[.swift] = "Swift"
        XCTAssertEqual(variants.firstValue, "Swift")
        variants[objectiveCTrait] = "Objective-C"
        XCTAssertEqual(variants.firstValue, "Swift") // Swift is still treated as the default value.
    }

    func testInitializesUsingSelectorLanguage() {
        XCTAssertEqual(
            DocumentationDataVariantsTrait(
                for: UnifiedSymbolGraph.Selector(
                    interfaceLanguage: "MyLanguage",
                    platform: nil
                )
            ).interfaceLanguage,
            "MyLanguage"
        )
    }
}

class DocumentationDataVariantsTests_new {
    @Test("Desired behavior for hasAnyValue property")
    func testHasAnyValue() {
        // hasAnyValue returns true only if a value is set in either the default or in a variant
        #expect(!DocumentationDataVariants<String>().hasAnyValue)
        #expect(DocumentationDataVariants<String>(defaultVariantValue: "Default value").hasAnyValue)
        #expect(DocumentationDataVariants<String>(values: [.swift: "Swift"]).hasAnyValue)

        // When the variant type is a collection, hasAnyValue will return false if the only available
        // collections are empty
        #expect(!DocumentationDataVariants<[String]>(defaultVariantValue: []).hasAnyValue)
        #expect(!DocumentationDataVariants<[String]>(values: [.swift: []]).hasAnyValue)
        #expect(DocumentationDataVariants<[String]>(defaultVariantValue: ["DefaultValue"]).hasAnyValue)
        #expect(DocumentationDataVariants<[String]>(values: [.swift: ["Swift"]]).hasAnyValue)
    }
}
