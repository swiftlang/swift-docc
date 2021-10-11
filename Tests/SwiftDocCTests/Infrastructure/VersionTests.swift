/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import SwiftDocC

class VersionTests: XCTestCase {
    func testEmptyVersionString() {
        XCTAssertNil(Version(versionString: ""))
    }

    func testInvalidCharacters() {
        XCTAssertNil(Version(versionString: "a.b"))
        XCTAssertNil(Version(versionString: "1."))
        XCTAssertNil(Version(versionString: "1.0.2a"))
        XCTAssertNil(Version(versionString: "1.0.2-2"))
        XCTAssertNil(Version(versionString: "1.0.2.."))
        XCTAssertNil(Version(versionString: "."))
        XCTAssertNil(Version(versionString: ".."))
        XCTAssertNil(Version(versionString: "..."))
    }

    func testValid() {
        do {
            let version = Version(versionString: "1")!
            XCTAssertEqual(Array(version), [1])
        }
        do {
            let version = Version(versionString: "1.0")!
            XCTAssertEqual(Array(version), [1, 0])
        }
        do {
            let version = Version(versionString: "0.1")!
            XCTAssertEqual(Array(version), [0, 1])
        }
        do {
            let version = Version(versionString: "1.2.3")!
            XCTAssertEqual(Array(version), [1, 2, 3])
        }
    }
}
