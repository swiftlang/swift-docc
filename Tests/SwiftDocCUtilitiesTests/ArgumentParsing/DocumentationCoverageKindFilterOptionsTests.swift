/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import Foundation
@testable import SwiftDocC

class KindFilterOptionsTests: XCTestCase {
    fileprivate typealias FilterOptions = DocumentationCoverageOptions.KindFilterOptions
    fileprivate typealias BitFlag = FilterOptions.BitFlagRepresentation


    func testEmptySet() {
        XCTAssertEqual(([] as FilterOptions).rawValue, 0)
    }
    func testFromArrayWithSingleString() {

        XCTAssertEqual(BitFlag(string: "chicken"), nil  )

        XCTAssertEqual(BitFlag(string: "module"), BitFlag.module) // 1
        XCTAssertEqual(BitFlag(string: "class"), BitFlag.class) // 2
        XCTAssertEqual(BitFlag(string: "structure"), BitFlag.structure) // 3
        XCTAssertEqual(BitFlag(string: "enumeration"), BitFlag.enumeration) // 4
        XCTAssertEqual(BitFlag(string: "protocol"), BitFlag.protocol) // 5
        XCTAssertEqual(BitFlag(string: "type-alias"), BitFlag.typeAlias) // 6
        XCTAssertEqual(BitFlag(string: "typedef"), BitFlag.typeDef) // 7
        XCTAssertEqual(BitFlag(string: "associated-type"), BitFlag.associatedType) // 8
        XCTAssertEqual(BitFlag(string: "function"), BitFlag.function) // 9
        XCTAssertEqual(BitFlag(string: "operator"), BitFlag.operator) // 10
        XCTAssertEqual(BitFlag(string: "enumeration-case"), BitFlag.enumerationCase) // 11
        XCTAssertEqual(BitFlag(string: "initializer"), BitFlag.initializer) // 12
        XCTAssertEqual(BitFlag(string: "instance-method"), BitFlag.instanceMethod) // 13
        XCTAssertEqual(BitFlag(string: "instance-property"), BitFlag.instanceProperty) // 14
        XCTAssertEqual(BitFlag(string: "instance-subcript"), BitFlag.instanceSubscript) // 15
        XCTAssertEqual(BitFlag(string: "instance-variable"), BitFlag.instanceVariable) // 16
        XCTAssertEqual(BitFlag(string: "type-method"), BitFlag.typeMethod) // 17
        XCTAssertEqual(BitFlag(string: "type-property"), BitFlag.typeProperty) // 18
        XCTAssertEqual(BitFlag(string: "type-subscript"), BitFlag.typeSubscript) // 19
        XCTAssertEqual(BitFlag(string: "global-variable"), BitFlag.globalVariable) // 20
    }
}
