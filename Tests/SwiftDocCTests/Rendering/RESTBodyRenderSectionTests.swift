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

class RESTBodyRenderSectionTests: XCTestCase {
    func value() throws -> RESTBodyRenderSection {
        let jsonData = """
        {
            "kind": "restBody",
            "title": "title",
            "mimeType": "mimeType",
            "bodyContentType": []
        }
        """.data(using: .utf8)!

        return try JSONDecoder().decode(RESTBodyRenderSection.self, from: jsonData)
    }

    func testDecoding() throws {
        XCTAssertEqual(
            try value(),
            RESTBodyRenderSection(
                title: "title",
                mimeType: "mimeType",
                bodyContentType: [],
                content: nil,
                parameters: nil
            )
        )
    }

    func testRoundTrip() throws {
        try assertRoundTripCoding(try value())
    }
}
