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

class VariantContainerTests: XCTestCase {
    var testValue = VariantContainerTest()
    
    func testSetVariantDefaultValueOptional() throws {
        testValue.setVariantDefaultValue("new value", keyPath: \.optionalPropertyVariants)
        XCTAssertEqual(testValue.optionalPropertyVariants?.defaultValue, "new value")
    }
    
    func testSetVariantDefaultValueOptionalExistingValue() throws {
        testValue.optionalPropertyVariants = VariantCollection<String>(
            defaultValue: "default value",
            objectiveCValue: "Objective-C value"
        )
        testValue.setVariantDefaultValue("new value", keyPath: \.optionalPropertyVariants)
        XCTAssertEqual(testValue.optionalPropertyVariants?.defaultValue, "new value")
        
        guard case .replace(let value) = testValue.optionalPropertyVariants?.variants[0].patch[0] else {
            XCTFail("Unexpected patch value")
            return
        }
        
        XCTAssertEqual(value, "Objective-C value")
    }
    
    func testGetVariantDefaultValueOptional() throws {
        testValue.optionalPropertyVariants = VariantCollection<String>(defaultValue: "default value")
        XCTAssertEqual(testValue.getVariantDefaultValue(keyPath: \.optionalPropertyVariants), "default value")
    }
    
    func testSetVariantDefaultValueNonOptional() throws {
        testValue.setVariantDefaultValue("new value", keyPath: \.nonOptionalPropertyVariants)
        XCTAssertEqual(testValue.nonOptionalPropertyVariants.defaultValue, "new value")
    }
    
    func testGetVariantDefaultValue() throws {
        testValue.nonOptionalPropertyVariants = VariantCollection<String>(defaultValue: "default value")
        XCTAssertEqual(testValue.getVariantDefaultValue(keyPath: \.nonOptionalPropertyVariants), "default value")
    }
    
    struct VariantContainerTest: VariantContainer {
        var nonOptionalProperty = ""
        
        var nonOptionalPropertyVariants = VariantCollection<String>(defaultValue: "")
        
        var optionalProperty: String?
        
        var optionalPropertyVariants: VariantCollection<String>?
    }
}
