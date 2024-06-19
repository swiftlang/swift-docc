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

class SemanticVersionStringRepresentationTests: XCTestCase {
    func testConversionToVersionTriplet() {
        let symbolOne = SymbolGraph.SemanticVersion(major: 1, minor: 0, patch: 0)
        XCTAssertEqual(VersionTriplet(semanticVersion: symbolOne), VersionTriplet(1, 0, 0))
        
        let symbolTwo = SymbolGraph.SemanticVersion(major: 1, minor: 2, patch: 0)
        XCTAssertEqual(VersionTriplet(semanticVersion: symbolTwo), VersionTriplet(1, 2, 0))
        
        let symbolThree = SymbolGraph.SemanticVersion(major: 1, minor: 2, patch: 3)
        XCTAssertEqual(VersionTriplet(semanticVersion: symbolThree), VersionTriplet(1, 2, 3))
        
        let symbolFour = SymbolGraph.SemanticVersion(major: 0, minor: 0, patch: 0)
        XCTAssertEqual(VersionTriplet(semanticVersion: symbolFour), VersionTriplet(0, 0, 0))
        
        let symbolFive = SymbolGraph.SemanticVersion(major: 1, minor: 0, patch: 1)
        XCTAssertEqual(VersionTriplet(semanticVersion: symbolFive), VersionTriplet(1, 0, 1))
    }
}
