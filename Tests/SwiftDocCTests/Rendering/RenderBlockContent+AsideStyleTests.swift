/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class RenderBlockContent_AsideStyleTests: XCTestCase {
    private typealias AsideStyle = RenderBlockContent.AsideStyle
    
    func testDisplayNameForSpecialRawValue() {
        XCTAssertEqual(
            AsideStyle(rawValue: "nonmutatingvariant").displayName,
            "Non-Mutating Variant"
        )
        
        XCTAssertEqual(
            AsideStyle(rawValue: "NonMutatingVariant").displayName,
            "Non-Mutating Variant"
        )
        
        XCTAssertEqual(
            AsideStyle(rawValue: "mutatingvariant").displayName,
            "Mutating Variant"
        )
        
        XCTAssertEqual(
            AsideStyle(rawValue: "todo").displayName,
            "To Do"
        )
    }
    
    func testDisplayNameForAsideWithExistingUppercasedContent() {
        XCTAssertEqual(
            AsideStyle(rawValue: "Random title").displayName,
            "Random title"
        )
    }
    
    func testDisplayNameForAsideWithLowercasedContent() {
        XCTAssertEqual(
            AsideStyle(rawValue: "random title").displayName,
            "Random Title"
        )
    }
}
