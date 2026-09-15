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

struct VariantContainerTests {
    var testValue = VariantContainerTest()
    
    @Test
    mutating func setsVariantDefaultValueForOptionalProperty() {
        testValue.setVariantDefaultValue("new value", keyPath: \.optionalPropertyVariants)
        #expect(testValue.optionalPropertyVariants?.defaultValue == "new value")
    }
    
    @Test
    mutating func setsVariantDefaultValueForOptionalPropertyWithExistingValue() throws {
        testValue.optionalPropertyVariants = VariantCollection<String>(
            defaultValue: "default value",
            objectiveCValue: "Objective-C value"
        )
        testValue.setVariantDefaultValue("new value", keyPath: \.optionalPropertyVariants)
        #expect(testValue.optionalPropertyVariants?.defaultValue == "new value")
        
        guard case .replace(let value) = testValue.optionalPropertyVariants?.variants[0].patch[0] else {
            Issue.record("Unexpected patch value")
            return
        }
        
        #expect(value == "Objective-C value")
    }
    
    @Test
    mutating func getsVariantDefaultValueForOptionalProperty() {
        testValue.optionalPropertyVariants = VariantCollection<String>(defaultValue: "default value")
        #expect(testValue.getVariantDefaultValue(keyPath: \.optionalPropertyVariants) == "default value")
    }
    
    @Test
    mutating func setsVariantDefaultValueForNonOptionalProperty() {
        testValue.setVariantDefaultValue("new value", keyPath: \.nonOptionalPropertyVariants)
        #expect(testValue.nonOptionalPropertyVariants.defaultValue == "new value")
    }
    
    @Test
    mutating func getsVariantDefaultValueForNonOptionalProperty() {
        testValue.nonOptionalPropertyVariants = VariantCollection<String>(defaultValue: "default value")
        #expect(testValue.getVariantDefaultValue(keyPath: \.nonOptionalPropertyVariants) == "default value")
    }
    
    struct VariantContainerTest: VariantContainer {
        var nonOptionalProperty = ""
        
        var nonOptionalPropertyVariants = VariantCollection<String>(defaultValue: "")
        
        var optionalProperty: String?
        
        var optionalPropertyVariants: VariantCollection<String>?
    }
}
