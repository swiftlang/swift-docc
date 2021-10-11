/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
import SymbolKit
@testable import SwiftDocC

class SemanticVersion_ComparableTests: XCTestCase {
    private typealias Version = SymbolGraph.SemanticVersion
    
    func test() {
        // Patch difference
        XCTAssertLessThan(
            Version(major: 1, minor: 1, patch: 1),
            Version(major: 1, minor: 1, patch: 2)
        )
        
        // Minor difference
        XCTAssertLessThan(
            Version(major: 1, minor: 1, patch: 3),
            Version(major: 1, minor: 2, patch: 1)
        )
        
        // Major difference
        XCTAssertLessThan(
            Version(major: 1, minor: 3, patch: 1),
            Version(major: 2, minor: 1, patch: 2)
        )
    }
}
