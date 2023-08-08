/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest

import Markdown

@testable import SwiftDocC

final class DirectiveArgumentWrappedTests: XCTestCase {
    
    // MARK: - Declarations
    
    // A custom type that
    enum Something: String, CaseIterable, DirectiveArgumentValueConvertible {
        case something
    }
    
    // These are all declared directly on the test case so that the property wrappers can be easily accessed in the test.
    
    // MARK: Values
    
    // Without default values
    
    @DirectiveArgumentWrapped
    var boolean: Bool
    
    @DirectiveArgumentWrapped
    var number: Int
    
    @DirectiveArgumentWrapped
    var customValue: Something
    
    // With default values
    
    @DirectiveArgumentWrapped
    var booleanWithDefault: Bool = false
    
    @DirectiveArgumentWrapped
    var numberWithDefault: Int = 0
    
    @DirectiveArgumentWrapped
    var customValueWithDefault: Something = .something
    
    // MARK: Optional values
    
    // Without default values
    
    @DirectiveArgumentWrapped
    var optionalBoolean: Bool?

    @DirectiveArgumentWrapped
    var optionalNumber: Int?

    @DirectiveArgumentWrapped
    var optionalCustomValue: Something?
    
    // With default values
    
    @DirectiveArgumentWrapped
    var optionalBooleanWithDefault: Bool? = true

    @DirectiveArgumentWrapped
    var optionalNumberWithDefault: Int? = 0

    @DirectiveArgumentWrapped
    var optionalCustomValueWithDefault: Something? = .something
    
    @DirectiveArgumentWrapped
    var optionalBooleanWithNilDefault: Bool? = nil

    @DirectiveArgumentWrapped
    var optionalNumberWithNilDefault: Int? = nil

    @DirectiveArgumentWrapped
    var optionalCustomValueWithNilDefault: Something? = nil
    
    // MARK: Explicit allowed values
    
    // Non-optional
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var booleanWithAllowedValues: Bool
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var numberWithAllowedValues: Int
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var customValueWithAllowedValues: Something
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var booleanWithAllowedValuesAndDefaultValue: Bool = false
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var numberWithAllowedValuesAndDefaultValue: Int = 0
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var customValueWithAllowedValuesAndDefaultValue: Something = .something
    
    // Optional
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalBooleanWithAllowedValues: Bool?
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalNumberWithAllowedValues: Int?
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalCustomValueWithAllowedValues: Something?
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalBooleanWithAllowedValuesAndDefaultValue: Bool? = false
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalNumberWithAllowedValuesAndDefaultValue: Int? = 0
    
    @DirectiveArgumentWrapped(
        parseArgument: { _, _ in nil },
        allowedValues: ["one", "two", "three"])
    var optionalCustomValueWithAllowedValuesAndDefaultValue: Something? = .something
    
    // MARK: - Test assertions
    
    func testTypeDisplayName() throws {
        
        // MARK: Values
        
        // Without default values
        
        XCTAssertEqual(_boolean.typeDisplayName, "Bool")
        XCTAssertEqual(_boolean.allowedValues, ["true", "false"])
        XCTAssertEqual(_boolean.required, true, "Argument without default value is required")

        XCTAssertEqual(_number.typeDisplayName, "Int")
        XCTAssertEqual(_number.allowedValues, nil)
        XCTAssertEqual(_number.required, true, "Argument without default value is required")

        XCTAssertEqual(_customValue.typeDisplayName, "Something")
        XCTAssertEqual(_customValue.allowedValues, ["something"])
        XCTAssertEqual(_customValue.required, true, "Argument without default value is required")

        // With default values

        XCTAssertEqual(_booleanWithDefault.typeDisplayName, "Bool = false")
        XCTAssertEqual(_booleanWithDefault.allowedValues, ["true", "false"])
        XCTAssertEqual(_booleanWithDefault.required, false, "Argument has default value to fallback to")

        XCTAssertEqual(_numberWithDefault.typeDisplayName, "Int = 0")
        XCTAssertEqual(_numberWithDefault.allowedValues, nil)
        XCTAssertEqual(_numberWithDefault.required, false, "Argument has default value to fallback to")

        XCTAssertEqual(_customValueWithDefault.typeDisplayName, "Something = something")
        XCTAssertEqual(_customValueWithDefault.allowedValues, ["something"])
        XCTAssertEqual(_customValueWithDefault.required, false, "Argument has default value to fallback to")

        // MARK: Optional values

        XCTAssertEqual(_optionalBoolean.typeDisplayName, "Bool?")
        XCTAssertEqual(_optionalBoolean.allowedValues, ["true", "false"])
        XCTAssertEqual(_optionalBoolean.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalNumber.typeDisplayName, "Int?")
        XCTAssertEqual(_optionalNumber.allowedValues, nil)
        XCTAssertEqual(_optionalNumber.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalCustomValue.typeDisplayName, "Something?")
        XCTAssertEqual(_optionalCustomValue.allowedValues, ["something"])
        XCTAssertEqual(_optionalCustomValue.required, false, "Argument with optional type is not required")

        // With nil default values
        
        XCTAssertEqual(_optionalBooleanWithNilDefault.typeDisplayName, "Bool?")
        XCTAssertEqual(_optionalBooleanWithNilDefault.allowedValues, ["true", "false"])
        XCTAssertEqual(_optionalBooleanWithNilDefault.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalNumberWithNilDefault.typeDisplayName, "Int?")
        XCTAssertEqual(_optionalNumberWithNilDefault.allowedValues, nil)
        XCTAssertEqual(_optionalNumberWithNilDefault.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalCustomValueWithNilDefault.typeDisplayName, "Something?")
        XCTAssertEqual(_optionalCustomValueWithNilDefault.allowedValues, ["something"])
        XCTAssertEqual(_optionalCustomValueWithNilDefault.required, false, "Argument with optional type is not required")
        
        // With default values

        XCTAssertEqual(_optionalBooleanWithDefault.typeDisplayName, "Bool = true")
        XCTAssertEqual(_optionalBooleanWithDefault.allowedValues, ["true", "false"])
        XCTAssertEqual(_optionalBooleanWithDefault.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalNumberWithDefault.typeDisplayName, "Int = 0")
        XCTAssertEqual(_optionalNumberWithDefault.allowedValues, nil)
        XCTAssertEqual(_optionalNumberWithDefault.required, false, "Argument with optional type is not required")

        XCTAssertEqual(_optionalCustomValueWithDefault.typeDisplayName, "Something = something")
        XCTAssertEqual(_optionalCustomValueWithDefault.allowedValues, ["something"])
        XCTAssertEqual(_optionalCustomValueWithDefault.required, false, "Argument with optional type is not required")

        // MARK: Explicit allowed values

        // Non-optional

        XCTAssertEqual(_booleanWithAllowedValues.typeDisplayName, "Bool")
        XCTAssertEqual(_booleanWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_booleanWithAllowedValues.required, true, "Argument without default value is required")

        XCTAssertEqual(_numberWithAllowedValues.typeDisplayName, "Int")
        XCTAssertEqual(_numberWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_numberWithAllowedValues.required, true, "Argument without default value is required")

        XCTAssertEqual(_customValueWithAllowedValues.typeDisplayName, "Something")
        XCTAssertEqual(_customValueWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_customValueWithAllowedValues.required, true, "Argument without default value is required")

        XCTAssertEqual(_booleanWithAllowedValuesAndDefaultValue.typeDisplayName, "Bool = false")
        XCTAssertEqual(_booleanWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_booleanWithAllowedValuesAndDefaultValue.required, false, "Argument has default value to fallback to")

        XCTAssertEqual(_numberWithAllowedValuesAndDefaultValue.typeDisplayName, "Int = 0")
        XCTAssertEqual(_numberWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_numberWithAllowedValuesAndDefaultValue.required, false, "Argument has default value to fallback to")

        XCTAssertEqual(_customValueWithAllowedValuesAndDefaultValue.typeDisplayName, "Something = something")
        XCTAssertEqual(_customValueWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_customValueWithAllowedValuesAndDefaultValue.required, false, "Argument has default value to fallback to")
        
       // Optional
        
        XCTAssertEqual(_optionalBooleanWithAllowedValues.typeDisplayName, "Bool?")
        XCTAssertEqual(_optionalBooleanWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalBooleanWithAllowedValues.required, false, "Argument with optional type is not required")
        
        XCTAssertEqual(_optionalNumberWithAllowedValues.typeDisplayName, "Int?")
        XCTAssertEqual(_optionalNumberWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalNumberWithAllowedValues.required, false, "Argument with optional type is not required")
        
        XCTAssertEqual(_optionalCustomValueWithAllowedValues.typeDisplayName, "Something?")
        XCTAssertEqual(_optionalCustomValueWithAllowedValues.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalCustomValueWithAllowedValues.required, false, "Argument with optional type is not required")
        
        
        XCTAssertEqual(_optionalBooleanWithAllowedValuesAndDefaultValue.typeDisplayName, "Bool = false")
        XCTAssertEqual(_optionalBooleanWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalBooleanWithAllowedValuesAndDefaultValue.required, false, "Argument with optional type is not required")
        
        XCTAssertEqual(_optionalNumberWithAllowedValuesAndDefaultValue.typeDisplayName, "Int = 0")
        XCTAssertEqual(_optionalNumberWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalNumberWithAllowedValuesAndDefaultValue.required, false, "Argument with optional type is not required")
        
        XCTAssertEqual(_optionalCustomValueWithAllowedValuesAndDefaultValue.typeDisplayName, "Something = something")
        XCTAssertEqual(_optionalCustomValueWithAllowedValuesAndDefaultValue.allowedValues, ["one", "two", "three"], "Argument has explicitly specified allowed values")
        XCTAssertEqual(_optionalCustomValueWithAllowedValuesAndDefaultValue.required, false, "Argument with optional type is not required")
    }
}
