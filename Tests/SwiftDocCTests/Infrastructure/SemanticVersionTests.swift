/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC
@testable import SymbolKit

/// Tests extensions on SymbolGraph.SemanticVersion
class SemanticVersionTests: XCTestCase {
    typealias Version = SymbolGraph.SemanticVersion
    func testParseString() {
        XCTAssertNil(Version(string: ""))
        XCTAssertNil(Version(string: "1.2.3.4"))
        XCTAssertNil(Version(string: "a"))
        XCTAssertNil(Version(string: "1.a"))
        XCTAssertNil(Version(string: "1.2.a"))
        XCTAssertNil(Version(string: "1.2.3.a"))
        XCTAssertNil(Version(string: "1a"))
        XCTAssertNil(Version(string: "1.2a"))
        XCTAssertNil(Version(string: "1.2.3a"))
        XCTAssertNil(Version(string: "1.2.3-a"))
        XCTAssertNil(Version(string: "1.2.3~a"))

        XCTAssertEqual(Version(major: 1, minor: 0, patch: 0),
                       Version(string: "1"))
        XCTAssertEqual(Version(major: 1, minor: 2, patch: 0),
                       Version(string: "1.2"))
        XCTAssertEqual(Version(major: 1, minor: 2, patch: 3),
                       Version(string: "1.2.3"))
    }
}
