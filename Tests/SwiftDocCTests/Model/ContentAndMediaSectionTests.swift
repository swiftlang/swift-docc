/*
 This source file is part of the Swift.org open source project

 Copyright (c) 2021 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See https://swift.org/LICENSE.txt for license information
 See https://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import Foundation
import XCTest
@testable import SwiftDocC

class ContentAndMediaSectionTests: XCTestCase {
    func testDecoderWithAllKeysPresent() {
        let json = """
        {
            "kind": "contentAndMedia",
            "layout": "vertical",
            "title": "myTitle",
            "eyebrow": "myEyebrow",
            "content": [],
            "media": "myMedia",
            "mediaPosition": "trailing"
        }
        """.data(using: .utf8)!
        
        XCTAssertNoThrow(try JSONDecoder().decode(ContentAndMediaSection.self, from: json))
    }

    // Test for backwards-compatibility.
    func testDecoderAcceptsMissingKindKey() {
        let json = """
        {
            "layout": "vertical"
        }
        """.data(using: .utf8)!
        
        XCTAssertNoThrow(try JSONDecoder().decode(ContentAndMediaSection.self, from: json))
    }
}
