/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021-2026 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest

class DocumentationBundleTests: XCTestCase {
    func testBundleInitWithRootURL() throws {
        XCTAssertNoThrow(try testBundleFromRootURL(named: "LegacyBundle_DoNotUseInNewTests"))
    }
}
