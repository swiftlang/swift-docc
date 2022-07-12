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

class IntroRenderSectionTests: XCTestCase {
    func value() throws -> IntroRenderSection {
        let jsonData = Data("""
        {
            "action": {
                "identifier": "doc://testbundle/tutorials/TechnologyX/Tutorial",
                "isActive": true,
                "overridingTitle": "Get started",
                "overridingTitleInlineContent": [
                    {
                        "text": "Get started",
                        "type": "text"
                    }
                ],
                "type": "reference"
            },
            "backgroundImage": "intro.png",
            "content": [
                {
                    "inlineContent": [
                        {
                            "text": "This is the intro.",
                            "type": "text"
                        }
                    ],
                    "type": "paragraph"
                }
            ],
            "image": "intro.png",
            "kind": "hero",
            "title": "Introducing TechnologyX"
        }
        """.utf8)

        return try JSONDecoder().decode(IntroRenderSection.self, from: jsonData)
    }

    func testDecoding() throws {
        var intro = IntroRenderSection(title: "Introducing TechnologyX")
        intro.backgroundImage = .init("intro.png")
        intro.action = .reference(
            identifier: .init("doc://testbundle/tutorials/TechnologyX/Tutorial"),
            isActive: true,
            overridingTitle: "Get started",
            overridingTitleInlineContent: [.text("Get started")]
        )
        intro.content = [.paragraph(.init(inlineContent: [.text("This is the intro.")]))]
        intro.image = .init("intro.png")
        
        XCTAssertEqual(
            try value(),
            intro
        )
    }

    func testRoundTrip() throws {
        try assertRoundTripCoding(try value())
    }
}
