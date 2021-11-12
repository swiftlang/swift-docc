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

class RESTResponseRenderSectionTests: XCTestCase {
    func value() throws -> RESTResponseRenderSection {
        let jsonData = """
        {
            "kind": "restResponses",
            "title": "",
            "items": [
                {
                    "status": 200,
                    "reason": "reason",
                    "type": []
                }
            ]
        }
        """.data(using: .utf8)!

        return try JSONDecoder().decode(RESTResponseRenderSection.self, from: jsonData)
    }

    func testDecodingWithoutRESTResponseContent() throws {
        XCTAssertEqual(
            try value(),
            RESTResponseRenderSection(
                title: "",
                items: [
                    RESTResponse(
                        status: 200,
                        reason: "reason",
                        mimeType: nil,
                        type: [],
                        content: nil
                    ),
                ]
            )
        )
    }

    func valueWithoutReason() throws -> RESTResponseRenderSection {
        let jsonData = """
        {
            "kind": "restResponses",
            "title": "",
            "items": [
                {
                    "status": 200,
                    "type": []
                }
            ]
        }
        """.data(using: .utf8)!

        return try JSONDecoder().decode(RESTResponseRenderSection.self, from: jsonData)
    }

    func testDecodingWithoutRESTResponseReason() throws {
        XCTAssertEqual(
            try valueWithoutReason(),
            RESTResponseRenderSection(
                title: "",
                items: [
                    RESTResponse(
                        status: 200,
                        reason: nil,
                        mimeType: nil,
                        type: [],
                        content: nil
                    ),
                ]
            )
        )
    }

    func testRoundTrip() throws {
        try assertRoundTripCoding(try value())
    }
}
