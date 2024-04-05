/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2024 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class String_CapitalizationTests: XCTestCase {
    
    func testAllLowerCase() {
        let testString = "hello world"
        XCTAssertEqual("Hello world", testString.capitalizeFirstWord())
    }
    
    func testAllLowerCaseWithPunctuation() {
        let testString1 = "hello, world"
        let testString2 = "hello-world"
        let testString3 = "hello! world"
        let testString4 = "hello: world"
        let testString5 = "l'ocean world"
        XCTAssertEqual("Hello, world", testString1.capitalizeFirstWord())
        XCTAssertEqual("Hello-world", testString2.capitalizeFirstWord())
        XCTAssertEqual("Hello! world", testString3.capitalizeFirstWord())
        XCTAssertEqual("Hello: world", testString4.capitalizeFirstWord())
        XCTAssertEqual("L'ocean world", testString5.capitalizeFirstWord())
    }
    
    func testInvalidPunctuation() {
        let testString = "h`ello world"
        XCTAssertEqual(testString, testString.capitalizeFirstWord())
    }
    
    func testHasUppercase() {
        let testString = "iPad iOS visionOS"
        XCTAssertEqual(testString, testString.capitalizeFirstWord())
    }
    
    func testDifferentAlphabets() {
        let testString1 = "l'amérique du nord"
        let testString2 = "ça va?"
        let testString3 = "à"
        let testString4 = "チーズ"
        let testString5 = "牛奶"
        let testString6 = "i don't like 牛奶"
        let testString7 = "牛奶 is tasty"
        XCTAssertEqual("L'amérique du nord", testString1.capitalizeFirstWord())
        XCTAssertEqual("Ça va?", testString2.capitalizeFirstWord())
        XCTAssertEqual("À", testString3.capitalizeFirstWord())
        XCTAssertEqual("チーズ", testString4.capitalizeFirstWord())
        XCTAssertEqual("牛奶", testString5.capitalizeFirstWord())
        XCTAssertEqual("I don't like 牛奶", testString6.capitalizeFirstWord())
        XCTAssertEqual("牛奶 is tasty", testString7.capitalizeFirstWord())
    }
    
}
