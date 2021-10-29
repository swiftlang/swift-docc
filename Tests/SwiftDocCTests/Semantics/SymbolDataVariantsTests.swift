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

class SymbolDataVariantsTests: XCTestCase {
    func testAccessesVariantWithTrait() throws {
        var variants = SymbolDataVariants<String>(values: [.swift : "Swift"])
        
        XCTAssertEqual(variants[.swift], "Swift")
        
        let objectiveCTrait = SymbolDataVariantsTrait(interfaceLanguage: "objc")
        
        XCTAssertNil(variants[objectiveCTrait])
        variants[objectiveCTrait] = "Objective-C"
        XCTAssertEqual(variants[objectiveCTrait], "Objective-C")
    }
    
    func testReturnsDefaultValueInAllValues() throws {
        let variants = SymbolDataVariants<String>(defaultVariantValue: "Default value")
        XCTAssertEqual(variants.allValues.count, 1)
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testSetsDefaultValueWhenTraitIsFallback() throws {
        var variants = SymbolDataVariants<String>()
        variants[.fallback] = "Default value"
        let first = try XCTUnwrap(variants.allValues.first)
        XCTAssertEqual(first.trait, .fallback)
        XCTAssertEqual(first.variant, "Default value")
    }
    
    func testIsEmpty() throws {
        XCTAssert(SymbolDataVariants<String>().isEmpty)
        XCTAssertFalse(SymbolDataVariants<String>(values: [.swift : "Swift"]).isEmpty)
    }
    
    func testHasVariant() throws {
        XCTAssert(SymbolDataVariants<String>(values: [.swift : "Swift"]).hasVariant(for: .swift))
        XCTAssertFalse(SymbolDataVariants<String>().hasVariant(for: .swift))
    }
    
    func testSwiftVariantInitializer() throws {
        XCTAssertEqual(SymbolDataVariants<String>(swiftVariant: "Swift")[.swift], "Swift")
        XCTAssertNil(SymbolDataVariants<String>(swiftVariant: nil)[.swift])
    }
}
