/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2022 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

@testable import SwiftDocC
import XCTest

class URL_IsAbsoluteWebURLTests: XCTestCase {
    func testisAbsoluteWebURL() throws {
        let localURL = URL(fileURLWithPath: "/Users/username/Documents/Some Folder/Some Document.txt")
        let topReferenceURL = try XCTUnwrap(URL(string: "doc://swift-doc"))
        let webURL = try XCTUnwrap(URL(string: "swift.org"))
        let absoluteWebURL = try XCTUnwrap(URL(string: "https://swift.org"))

        XCTAssertEqual(localURL.isAbsoluteWebURL, false)
        XCTAssertEqual(topReferenceURL.isAbsoluteWebURL, false)
        XCTAssertEqual(webURL.isAbsoluteWebURL, false)
        XCTAssertEqual(absoluteWebURL.isAbsoluteWebURL, true)
    }
}
